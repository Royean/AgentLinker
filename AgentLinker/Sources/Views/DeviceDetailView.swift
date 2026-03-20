//
//  DeviceDetailView.swift
//  AgentLinker
//

import SwiftUI

struct DeviceDetailView: View {
    let device: Device
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var isConnecting = false
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Device Header
                VStack(spacing: 16) {
                    Image(systemName: device.type.icon)
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text(device.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(device.status.color))
                            .frame(width: 12, height: 12)
                        
                        Text(device.status.rawValue.capitalized)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .padding(.vertical, 20)
                
                Divider()
                
                // Device Info Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    InfoCard(
                        title: "Operating System",
                        value: device.os,
                        icon: "cpu"
                    )
                    
                    InfoCard(
                        title: "Device Type",
                        value: device.type.rawValue,
                        icon: "desktopcomputer"
                    )
                    
                    InfoCard(
                        title: "IP Address",
                        value: device.ipAddress ?? "N/A",
                        icon: "network"
                    )
                    
                    InfoCard(
                        title: "Last Seen",
                        value: formatLastSeen(device.lastSeen),
                        icon: "clock"
                    )
                }
                .padding(.horizontal)
                
                Divider()
                
                // Control Buttons
                VStack(spacing: 12) {
                    if device.status == .online {
                        Button(action: handleDisconnect) {
                            HStack {
                                if isConnecting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                }
                                Image(systemName: "wifi.slash")
                                Text("Disconnect")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.large)
                        .disabled(isConnecting)
                    } else {
                        Button(action: handleConnect) {
                            HStack {
                                if isConnecting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                }
                                Image(systemName: "wifi")
                                Text("Connect")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)
                        .disabled(isConnecting)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingEditSheet = true
                        }) {
                            Label("Edit", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            Task {
                                await deviceManager.refreshDeviceStatus(deviceId: device.id)
                            }
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { showingDeleteAlert = true }) {
                            Label("Delete", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditDeviceView(device: device)
                .environmentObject(deviceManager)
        }
        .alert("Delete Device", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deviceManager.deleteDevice(deviceId: device.id)
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(device.name)\"? This action cannot be undone.")
        }
    }
    
    private func handleConnect() {
        isConnecting = true
        Task {
            await deviceManager.connectToDevice(deviceId: device.id)
            isConnecting = false
        }
    }
    
    private func handleDisconnect() {
        isConnecting = true
        Task {
            await deviceManager.disconnectFromDevice(deviceId: device.id)
            isConnecting = false
        }
    }
    
    private func formatLastSeen(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.headline)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    DeviceDetailView(device: Device.mockDevices[0])
        .environmentObject(DeviceManager())
}
