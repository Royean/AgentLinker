//
//  AgentLinkerApp.swift
//  AgentLinker macOS
//

import SwiftUI

@main
struct AgentLinkerApp: App {
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var webSocketManager = WebSocketManager()

    var body: some Scene {
        WindowGroup {
            ConnectionView()
                .environmentObject(deviceManager)
                .environmentObject(webSocketManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // Menu Bar Extra
        MenuBarExtra("AgentLinker", systemImage: "desktopcomputer") {
            MenuBarView()
                .environmentObject(deviceManager)
                .environmentObject(webSocketManager)
        }
        .menuBarExtraStyle(.window)
    }
}