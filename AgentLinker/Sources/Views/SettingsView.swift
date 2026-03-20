//
//  SettingsView.swift
//  AgentLinker
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    
    @State private var showingDeleteAccount = false
    @State private var showingAboutSheet = false
    
    enum AppearanceMode: String, CaseIterable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let user = authManager.currentUser {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Edit") {
                                // TODO: Navigate to edit profile
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button("Log Out") {
                        authManager.logout()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                Section("Appearance") {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode.rawValue)
                        }
                    }
                }
                
                Section("Device Management") {
                    Toggle("Auto-refresh Device Status", isOn: $autoRefreshEnabled)
                    
                    if autoRefreshEnabled {
                        HStack {
                            Text("Refresh Interval")
                            Spacer()
                            Picker("", selection: $refreshInterval) {
                                Text("15s").tag(15)
                                Text("30s").tag(30)
                                Text("1m").tag(60)
                                Text("5m").tag(300)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                    
                    Toggle("Show Connection Notifications", isOn: $notificationsEnabled)
                }
                
                Section("System") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                    
                    HStack {
                        Text("Data Usage")
                        Spacer()
                        Text("24.5 MB")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Clear Cache") {
                        // TODO: Implement cache clearing
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2026.03.20")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("View Release Notes") {
                        showingAboutSheet = true
                    }
                }
                
                Section {
                    Button("Delete Account", role: .destructive) {
                        showingDeleteAccount = true
                    }
                } footer: {
                    Text("This action cannot be undone. All your devices and data will be permanently removed.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAboutSheet) {
                AboutView()
            }
            .alert("Delete Account", isPresented: $showingDeleteAccount) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    // TODO: Call API to delete account
                    authManager.logout()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete your account? This will remove all your devices and cannot be undone.")
            }
        }
        .frame(width: 450, height: 550)
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("AgentLinker")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Connect and manage your OpenClaw Agent devices seamlessly across all your platforms.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("What's New")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    ReleaseNoteItem(icon: "checkmark.circle.fill", text: "Initial release of AgentLinker")
                    ReleaseNoteItem(icon: "checkmark.circle.fill", text: "Secure Keychain credential storage")
                    ReleaseNoteItem(icon: "checkmark.circle.fill", text: "Device management with real-time status")
                    ReleaseNoteItem(icon: "checkmark.circle.fill", text: "Search and filter devices")
                    ReleaseNoteItem(icon: "checkmark.circle.fill", text: "Dark mode support")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)
            
            Spacer()
            
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://agentlinker.example.com/privacy")!)
                    .buttonStyle(.link)
                
                Link("Terms of Service", destination: URL(string: "https://agentlinker.example.com/terms")!)
                    .buttonStyle(.link)
            }
            .font(.caption)
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(width: 450, height: 600)
    }
}

struct ReleaseNoteItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
}
