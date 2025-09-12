//
//  ChatMessage.swift
//  WebsocketsMQTT POC
//
//  Created by Sylvan  on 12/09/2025.
//

import Foundation

struct ChatMessage: Codable, Identifiable {
    enum Event: String, Codable {
        case typing = "typing"
        case stopTyping = "stop_typing"

    }

    var id = UUID()
    var sender: String
    var text: String?
    var event: Event?
}
