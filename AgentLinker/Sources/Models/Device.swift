//
//  Device.swift
//  AgentLinker
//

import Foundation

enum DeviceType: String, Codable {
    case mac = "macOS"
    case windows = "Windows"
    case linux = "Linux"
    case ios = "iOS"
    case android = "Android"
    
    var icon: String {
        switch self {
        case .mac: return "desktopcomputer"
        case .windows: return "laptopcomputer"
        case .linux: return "server.rack"
        case .ios: return "iphone"
        case .android: return "phone.android"
        }
    }
}

enum DeviceStatus: String, Codable {
    case online = "online"
    case offline = "offline"
    case away = "away"
    
    var color: String {
        switch self {
        case .online: return "green"
        case .offline: return "gray"
        case .away: return "yellow"
        }
    }
}

struct Device: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let type: DeviceType
    let os: String
    var status: DeviceStatus
    let lastSeen: Date
    let ipAddress: String?
    
    static let mockDevices: [Device] = [
        Device(
            id: "device_1",
            name: "MacBook Pro",
            type: .mac,
            os: "macOS 14.0",
            status: .online,
            lastSeen: Date(),
            ipAddress: "192.168.1.100"
        ),
        Device(
            id: "device_2",
            name: "iPhone 15",
            type: .ios,
            os: "iOS 17.0",
            status: .online,
            lastSeen: Date(),
            ipAddress: "192.168.1.101"
        ),
        Device(
            id: "device_3",
            name: "Home Server",
            type: .linux,
            os: "Ubuntu 22.04",
            status: .offline,
            lastSeen: Calendar.current.date(byAdding: .hour, to: -2, of: Date()) ?? Date(),
            ipAddress: "192.168.1.50"
        ),
        Device(
            id: "device_4",
            name: "Work Laptop",
            type: .windows,
            os: "Windows 11",
            status: .away,
            lastSeen: Calendar.current.date(byAdding: .minute, to: -30, of: Date()) ?? Date(),
            ipAddress: "10.0.0.25"
        )
    ]
}
