//
//  ContentView.swift
//  AgentLinker
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showingAddDevice = false
    @State private var showingSettings = false
    @State private var showingEditDevice = false
    @State private var selectedFilter: DeviceManager.DeviceStatusFilter = .all
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Device List
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AgentLinker")
                            .font(.headline)
                        if let user = authManager.currentUser {
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button("Settings") {
                            showingSettings = true
                        }
                        Button("Log Out", role: .destructive) {
                            authManager.logout()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .padding()
                
                Divider()
                
                // Search and Filter
                VStack(spacing: 8) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search devices...", text: $deviceManager.searchText)
                            .textFieldStyle(.plain)
                        if !deviceManager.searchText.isEmpty {
                            Button(action: { deviceManager.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                    
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DeviceManager.DeviceStatusFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    title: filter.rawValue,
                                    count: filter == .all ? deviceManager.totalCount : deviceManager.devices.filter { $0.status == filter }.count,
                                    isSelected: selectedFilter == filter
                                ) {
                                    withAnimation {
                                        selectedFilter = filter
                                        deviceManager.filterStatus = filter
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Device List
                if deviceManager.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading devices...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if deviceManager.filteredDevices.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: deviceManager.searchText.isEmpty ? "desktopcomputer.badge.questionmark" : "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text(deviceManager.searchText.isEmpty ? "No Devices" : "No Results")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(deviceManager.searchText.isEmpty 
                             ? "Add your first device to get started" 
                             : "Try adjusting your search or filter")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(deviceManager.filteredDevices, selection: $deviceManager.selectedDevice) { device in
                        DeviceRowView(device: device)
                            .tag(device)
                            .contextMenu {
                                Button("Refresh Status") {
                                    Task {
                                        await deviceManager.refreshDeviceStatus(deviceId: device.id)
                                    }
                                }
                                
                                Button("Edit") {
                                    deviceManager.selectedDevice = device
                                    showingEditDevice = true
                                }
                                
                                if device.status == .online {
                                    Button("Disconnect", role: .destructive) {
                                        Task {
                                            await deviceManager.disconnectFromDevice(deviceId: device.id)
                                        }
                                    }
                                } else {
                                    Button("Connect") {
                                        Task {
                                            await deviceManager.connectToDevice(deviceId: device.id)
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                Button("Delete", role: .destructive) {
                                    Task {
                                        await deviceManager.deleteDevice(deviceId: device.id)
                                    }
                                }
                            }
                    }
                    .listStyle(.sidebar)
                }
                
                Divider()
                
                // Add Device Button
                Button(action: { showingAddDevice = true }) {
                    Label("Add Device", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding()
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 350)
        } detail: {
            // Detail View
            if let device = deviceManager.selectedDevice {
                DeviceDetailView(device: device)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Select a Device")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Choose a device from the sidebar to view details and controls")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .sheet(isPresented: $showingAddDevice) {
            AddDeviceView()
                .environmentObject(deviceManager)
        }
        .sheet(isPresented: $showingEditDevice) {
            if let device = deviceManager.selectedDevice {
                EditDeviceView(device: device)
                    .environmentObject(deviceManager)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(authManager)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("(\(count))")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
