//
//  AddDeviceView.swift
//  AgentLinker
//

import SwiftUI

struct AddDeviceView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.dismiss) var dismiss
    
    @State private var deviceName = ""
    @State private var deviceType: DeviceType = .mac
    @State private var deviceOS = ""
    @State private var deviceIP = ""
    @State private var isAdding = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Device Information") {
                    TextField("Device Name", text: $deviceName)
                    
                    Picker("Device Type", selection: $deviceType) {
                        ForEach(DeviceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    TextField("Operating System (e.g., macOS 14.0)", text: $deviceOS)
                    
                    TextField("IP Address (optional)", text: $deviceIP)
                        .keyboardType(.numbersAndPunctuation)
                }
                
                Section("Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To add a new device:")
                            .font(.headline)
                        
                        Text("1. Install the AgentLinker app on the device you want to add")
                        Text("2. Open the app and sign in with your account")
                        Text("3. The device will automatically appear in your device list")
                        
                        Text("Alternatively, you can manually register a device by entering its details above.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Device")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: handleAddDevice) {
                        Text("Add")
                            .fontWeight(.semibold)
                    }
                    .disabled(deviceName.isEmpty || deviceOS.isEmpty || isAdding)
                }
            }
        }
        .frame(width: 450, height: 500)
    }
    
    private func handleAddDevice() {
        isAdding = true
        
        Task {
            // Simulate API call
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            let newDevice = Device(
                id: "device_\(UUID().uuidString)",
                name: deviceName,
                type: deviceType,
                os: deviceOS,
                status: .offline,
                lastSeen: Date(),
                ipAddress: deviceIP.isEmpty ? nil : deviceIP
            )
            
            deviceManager.devices.append(newDevice)
            deviceManager.selectedDevice = newDevice
            
            await MainActor.run {
                dismiss()
            }
        }
    }
}

extension DeviceType: CaseIterable {}

#Preview {
    AddDeviceView()
        .environmentObject(DeviceManager())
}
