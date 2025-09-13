//
//  MQTTManager.swift
//  WebsocketsMQTT POC
//
//  Created by Sylvan  on 13/09/2025.
//

import CocoaMQTT
import Combine
import Foundation
import CocoaMQTTWebSocket

enum TestSocket {
    case emqxWs
    case emqxWss
    case hiveMq
    case mosquittoTest

    var name: String {
        switch self {
        case .emqxWs: "emqWs"
        case .emqxWss: "emqWss"
        case .hiveMq: "hiveMq"
        case .mosquittoTest: "mosquittoTest"
        }
    }

    var urlString: String {
        switch self {
        case .emqxWs: "ws://broker.emqx.io:8083/mqtt"
        case .emqxWss: "wss://broker.emqx.io:8084/mqtt"
        case .hiveMq: "wss://broker.hivemq.com:8884/mqtt"
        case .mosquittoTest: "wss://test.mosquitto.org:8081/mqtt"
        }
    }

    var host: String {
        switch self {
        case .emqxWs, .emqxWss: "broker.emqx.io"
        case .hiveMq: "broker.hivemq.com"
        case .mosquittoTest: "test.mosquitto.org"
        }
    }

    var port: UInt16 {
        switch self {
        case .emqxWs: return 8083
        case .emqxWss: return 8084
        case .hiveMq: return 8884
        case .mosquittoTest: return 8081
        }
    }
}

final class MQTTManager: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var typingUsers: Set<String> = []
    @Published private(set) var isConnected = false

    private var mqtt: CocoaMQTT?
    private var typingTask: Task<Void, Never>?
    private let topic = "chat/demo"
    private let clientID = "iOS-Demo-Client-\(UUID().uuidString.prefix(6))"

    func connect() {
        let mqtt = CocoaMQTT(clientID: clientID, host: "broker.emqx.io", port: 8083/*, socket: .ws("/mqtt")*/)
        mqtt.username = nil
        mqtt.password = nil
        mqtt.keepAlive = 60
        mqtt.autoReconnect = true
        mqtt.allowUntrustCACertificate = true
        mqtt.delegate = self
        _ = mqtt.connect()
        self.mqtt = mqtt
    }

    func disconnect() {
        mqtt?.disconnect()
        mqtt = nil
    }

    func sendMessage(_ text: String) {
        guard isConnected else { return }
        let chat = ChatMessage(sender: clientID, text: text)
        publish(chat)
    }

    func userIsTyping(currentText: String) {
        guard isConnected else { return }
        typingTask?.cancel()

        if !currentText.isEmpty {
            publish(ChatMessage(sender: clientID, event: .typing))

            typingTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                publish(ChatMessage(sender: clientID, event: .stopTyping))
            }
        } else {
            publish(ChatMessage(sender: clientID, event: .stopTyping))
        }
    }

    private func publish(_ chat: ChatMessage) {
        guard let mqtt, isConnected else { return }

        do {
            let data = try JSONEncoder().encode(chat)
            mqtt.publish(topic, withString: String(data: data, encoding: .utf8) ?? "")
        } catch {
            print("Publish error: \(error.localizedDescription)")
        }
    }
}

extension MQTTManager: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        guard ack == .accept else { return }
        mqtt.subscribe(topic)
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }

    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: (any Error)?) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        guard let jsonString = message.string,
              let data = jsonString.data(using: .utf8),
              let chat = try? JSONDecoder().decode(ChatMessage.self, from: data) else {
            return
        }

        if let event = chat.event {
            if event == .typing, chat.sender != clientID {
                typingUsers.insert(chat.sender)
            } else if event == .stopTyping {
                typingUsers.remove(chat.sender)
            }
        } else {
            messages.append(chat)
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        print("[MQTT] Published message with id: \(id)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        print("[MQTT] Received publish ACK for id: \(id)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        print("[MQTT] Subscribed to topics: \(success.allKeys.description)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        print("[MQTT] Unsubscribed from topics: \(topics)")
    }

    func mqttDidPing(_ mqtt: CocoaMQTT) {
        print("[MQTT] Sent PING")
    }

    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        print("[MQTT] Recieved PONG")
    }
}
