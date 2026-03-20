//
//  AgentLinkerApp.swift
//  AgentLinker
//
//  Created on 2026-03-20.
//

import SwiftUI

@main
struct AgentLinkerApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var deviceManager = DeviceManager()
    @AppStorage("appearanceMode") private var appearanceMode = "System"
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoggedIn {
                    ContentView()
                        .environmentObject(authManager)
                        .environmentObject(deviceManager)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
            .preferredColorScheme(colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(authManager)
        }
        #endif
    }
    
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light":
            return .light
        case "Dark":
            return .dark
        default:
            return nil
        }
    }
}
