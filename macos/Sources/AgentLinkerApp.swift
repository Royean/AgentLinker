//
//  AgentLinkerApp.swift
//  AgentLinker macOS
//

import SwiftUI

@main
struct AgentLinkerApp: App {
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var webSocketManager = WebSocketManager()
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                        .environmentObject(deviceManager)
                        .environmentObject(webSocketManager)
                        .environmentObject(authManager)
                        .onAppear {
                            // Auto-connect on launch if authenticated
                            webSocketManager.connect(
                                deviceId: deviceManager.deviceId,
                                deviceName: deviceManager.deviceName,
                                token: "ah_device_token_change_in_production"
                            )
                        }
                } else {
                    LoginView()
                        .environmentObject(deviceManager)
                        .environmentObject(webSocketManager)
                        .environmentObject(authManager)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        // Menu Bar Extra (optional)
        MenuBarExtra("AgentLinker", systemImage: "desktopcomputer") {
            MenuBarView()
                .environmentObject(deviceManager)
                .environmentObject(webSocketManager)
                .environmentObject(authManager)
        }
        .menuBarExtraStyle(.window)
    }
}
