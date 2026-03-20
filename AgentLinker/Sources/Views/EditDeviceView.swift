//
//  EditDeviceView.swift
//  AgentLinker
//

import SwiftUI

struct EditDeviceView: View {
    let device: Device
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.dismiss) var dismiss
    
    @State private var deviceName: String
    @State private var deviceType: DeviceType
    @State private var deviceOS: String
    @State private var deviceIP: String
    @State private var isSaving = false
    
    init(device: Device) {
        self.device = device
        _deviceName = State(initialValue: device.name)
        _deviceType = State(initialValue: device.type)
        _deviceOS = State(initialValue: device.os)
        _deviceIP = State(initialValue: device.ipAddress ?? "")
    }
    
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
                    
                    TextField("Operating System", text: $deviceOS)
                    
                    TextField("IP Address", text: $deviceIP)
                        .keyboardType(.numbersAndPunctuation)
                }
                
                Section("Device Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(device.status.color))
                                .frame(width: 8, height: 8)
                            Text(device.status.rawValue.capitalized)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Last Seen")
                    Text(formatLastSeen(device.lastSeen))
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Device")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: handleSave) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || !hasChanges)
                }
            }
        }
        .frame(width: 450, height: 500)
    }
    
    private var hasChanges: Bool {
        deviceName != device.name ||
        deviceType != device.type ||
        deviceOS != device.os ||
        deviceIP != (device.ipAddress ?? "")
    }
    
    private func handleSave() {
        isSaving = true
        
        Task {
            let updatedDevice = Device(
                id: device.id,
                name: deviceName,
                type: deviceType,
                os: deviceOS,
                status: device.status,
                lastSeen: device.lastSeen,
                ipAddress: deviceIP.isEmpty ? nil : deviceIP
            )
            
            let success = await deviceManager.updateDevice(updatedDevice)
            
            await MainActor.run {
                if success {
                    dismiss()
                }
                isSaving = false
            }
        }
    }
    
    private func formatLastSeen(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    EditDeviceView(device: Device.mockDevices[0])
        .environmentObject(DeviceManager())
}
