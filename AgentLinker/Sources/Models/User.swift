//
//  User.swift
//  AgentLinker
//

import Foundation

struct User: Codable, Equatable {
    let id: String
    let email: String
    let name: String
    let avatar: String?
    
    static let mock = User(
        id: "user_123",
        email: "user@example.com",
        name: "User",
        avatar: nil
    )
}
