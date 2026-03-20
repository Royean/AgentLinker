//
//  DeviceManager.swift
//  AgentLinker
//

import Foundation
import Combine

class DeviceManager: ObservableObject {
    @Published var devices: [Device] = []
    @Published var selectedDevice: Device?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var filterStatus: DeviceStatusFilter = .all
    
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    enum DeviceStatusFilter: String, CaseIterable {
        case all = "All"
        case online = "Online"
        case offline = "Offline"
        case away = "Away"
    }
    
    // MARK: - API Request/Response Models
    
    private struct DeviceRequest: Encodable {
        let name: String
        let type: String
        let os: String
        let ipAddress: String?
    }
    
    private struct DeviceResponse: Decodable {
        let id: String
        let name: String
        let type: String
        let os: String
        let status: String
        let lastSeen: String
        let ipAddress: String?
        
        func toDevice() -> Device {
            Device(
                id: id,
                name: name,
                type: DeviceType(rawValue: type) ?? .mac,
                os: os,
                status: DeviceStatus(rawValue: status) ?? .offline,
                lastSeen: ISO8601DateFormatter().date(from: lastSeen) ?? Date(),
                ipAddress: ipAddress
            )
        }
    }
    
    private struct DevicesResponse: Decodable {
        let devices: [DeviceResponse]
        let total: Int
    }
    
    init() {
        loadDevices()
        startAutoRefresh()
        setupSearchFilter()
    }
    
    /// Filtered devices based on search text and status filter
    var filteredDevices: [Device] {
        var filtered = devices
        
        // Apply status filter
        if filterStatus != .all {
            filtered = filtered.filter { $0.status == filterStatus }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.os.localizedCaseInsensitiveContains(searchText) ||
                ($0.ipAddress?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return filtered
    }
    
    /// Count of online devices
    var onlineCount: Int {
        devices.filter { $0.status == .online }.count
    }
    
    /// Count of total devices
    var totalCount: Int {
        devices.count
    }
    
    func loadDevices() {
        isLoading = true
        
        Task {
            do {
                // In production, uncomment to use real API:
                // let response: DevicesResponse = try await apiClient.get(endpoint: "/devices")
                // let devices = response.devices.map { $0.toDevice() }
                
                // Mock load (replace with API call above)
                try? await Task.sleep(nanoseconds: 500_000_000)
                let devices = Device.mockDevices
                
                await MainActor.run {
                    self.devices = devices
                    self.isLoading = false
                }
            } catch let error as APIError {
                await MainActor.run {
                    self.errorMessage = error.errorDescription
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load devices: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func refreshDeviceStatus(deviceId: String) async {
        do {
            // In production, uncomment to use real API:
            // let device: DeviceResponse = try await apiClient.get(endpoint: "/devices/\(deviceId)")
            // let updatedDevice = device.toDevice()
            
            // Mock refresh (replace with API call above)
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                if let index = devices.firstIndex(where: { $0.id == deviceId }) {
                    let statuses: [DeviceStatus] = [.online, .offline, .away]
                    devices[index].status = statuses.randomElement() ?? .online
                    devices[index].lastSeen = Date()
                }
            }
        } catch {
            print("Failed to refresh device status: \(error)")
        }
    }
    
    func connectToDevice(deviceId: String) async -> Bool {
        do {
            // In production, uncomment to use real API:
            // let device: DeviceResponse = try await apiClient.post(endpoint: "/devices/\(deviceId)/connect")
            // let updatedDevice = device.toDevice()
            
            // Mock connection (replace with API call above)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                if let index = devices.firstIndex(where: { $0.id == deviceId }) {
                    devices[index].status = .online
                    devices[index].lastSeen = Date()
                }
            }
            return true
        } catch {
            print("Failed to connect to device: \(error)")
            return false
        }
    }
    
    func disconnectFromDevice(deviceId: String) async -> Bool {
        do {
            // In production, uncomment to use real API:
            // let device: DeviceResponse = try await apiClient.post(endpoint: "/devices/\(deviceId)/disconnect")
            // let updatedDevice = device.toDevice()
            
            // Mock disconnection (replace with API call above)
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                if let index = devices.firstIndex(where: { $0.id == deviceId }) {
                    devices[index].status = .offline
                }
            }
            return true
        } catch {
            print("Failed to disconnect from device: \(error)")
            return false
        }
    }
    
    func deleteDevice(deviceId: String) async -> Bool {
        do {
            // In production, uncomment to use real API:
            // try await apiClient.delete(endpoint: "/devices/\(deviceId)")
            
            // Mock deletion (replace with API call above)
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                devices.removeAll { $0.id == deviceId }
                if selectedDevice?.id == deviceId {
                    selectedDevice = nil
                }
            }
            return true
        } catch {
            print("Failed to delete device: \(error)")
            return false
        }
    }
    
    func updateDevice(_ device: Device) async -> Bool {
        do {
            // In production, uncomment to use real API:
            // let request = DeviceRequest(
            //     name: device.name,
            //     type: device.type.rawValue,
            //     os: device.os,
            //     ipAddress: device.ipAddress
            // )
            // let response: DeviceResponse = try await apiClient.put(
            //     endpoint: "/devices/\(device.id)",
            //     body: request
            // )
            // let updatedDevice = response.toDevice()
            
            // Mock update (replace with API call above)
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                if let index = devices.firstIndex(where: { $0.id == device.id }) {
                    devices[index] = device
                    if selectedDevice?.id == device.id {
                        selectedDevice = device
                    }
                }
            }
            return true
        } catch {
            print("Failed to update device: \(error)")
            return false
        }
    }
    
    private func startAutoRefresh() {
        // Refresh device status every 30 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshAllDevices()
            }
        }
    }
    
    private func refreshAllDevices() async {
        for device in devices {
            await refreshDeviceStatus(deviceId: device.id)
        }
    }
    
    private func setupSearchFilter() {
        // Auto-clear search when filter changes
        $filterStatus
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.searchText = ""
            }
            .store(in: &cancellables)
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
}
