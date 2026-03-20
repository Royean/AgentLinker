//
//  Messages.swift
//  AgentLinker macOS
//

import Foundation

// 设备注册消息 - 匹配 Python 客户端格式
struct DeviceRegister: Codable {
    let type: String
    let device_id: String
    let device_name: String
    let token: String

    init(device_id: String, device_name: String, token: String) {
        self.type = "register"
        self.device_id = device_id
        self.device_name = device_name
        self.token = token
    }
}

// WebSocket 消息协议
protocol WebSocketMessage: Codable {
    var action: String { get }
}

// 设备状态更新
struct DeviceStatusUpdate: WebSocketMessage {
    let action = "device.status"
    let device_id: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case action
        case device_id
        case status
    }
}

// 配对请求
struct PairingRequest: WebSocketMessage {
    let action = "device.pair"
    let device_id: String
    let pairing_key: String

    enum CodingKeys: String, CodingKey {
        case action
        case device_id
        case pairing_key
    }
}

// 命令执行请求
struct CommandRequest: WebSocketMessage {
    let action = "command.exec"
    let device_id: String
    let command: String
    let args: [String: String]?

    enum CodingKeys: String, CodingKey {
        case action
        case device_id
        case command
        case args
    }
}

// 服务器响应
struct ServerResponse: Codable {
    let type: String
    let device_id: String?
    let pairing_key: String?
    let msg: String?
}
