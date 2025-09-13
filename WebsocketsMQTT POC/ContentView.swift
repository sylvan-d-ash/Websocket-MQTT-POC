//
//  ContentView.swift
//  WebsocketsMQTT POC
//
//  Created by Sylvan  on 12/09/2025.
//

import SwiftUI

private struct ConnectionButtons: View {
    @ObservedObject var manager: MQTTManager

    var body: some View {
        HStack {
            if manager.isConnected {
                Button("Disconnect", role: .destructive) { manager.disconnect() }
                    .disabled(!manager.isConnected)
            } else {
                Button("Connect") { manager.connect() }
                    .disabled(manager.isConnected)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var manager = MQTTManager()
    @State private var input = ""

    var body: some View {
        NavigationStack {
            VStack {
                List(manager.messages) { msg in
                    Text("\(sender(for: msg))\(msg.text ?? "")")
                        .padding(6)
                        .background(background(for: msg).opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(
                            maxWidth: .infinity,
                            alignment: msg.sender == manager.clientID
                            ? .trailing : .leading
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .padding()
                .listStyle(.plain)

                if !manager.typingUsers.isEmpty {
                    Text("\(manager.typingUsers.joined(separator: ", ")) is typing…")
                        .italic()
                        .padding(.bottom, 4)
                }

                HStack {
                    TextField("Type a message...", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: input) { _, newValue in
                            manager.userIsTyping(currentText: newValue)
                        }

                    Button("Send") {
                        manager.sendMessage(input)
                        input = ""
                        manager.userIsTyping(currentText: "")
                    }
                    .disabled(!manager.isConnected || input.isEmpty)
                }
                .padding()

                ConnectionButtons(manager: manager)
                    .padding(.bottom)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(manager.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundStyle(manager.isConnected ? .green : .red)
                }
            }
        }
    }

    private func background(for msg: ChatMessage) -> Color {
        if msg.sender == manager.clientID {
            return .blue
        }
        return .green
    }

    private func sender(for msg: ChatMessage) -> String {
        if msg.sender == manager.clientID {
            return ""
        }
        return "\(msg.sender): "
    }
}

#Preview {
    ContentView()
}
