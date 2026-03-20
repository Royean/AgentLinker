//
//  DeviceRowView.swift
//  AgentLinker
//

import SwiftUI

struct DeviceRowView: View {
    let device: Device
    
    var body: some View {
        HStack(spacing: 12) {
            // Device Icon
            ZStack {
                Circle()
                    .fill(Color(device.status.color).opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: device.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(device.status.color))
            }
            
            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(device.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Status Indicator
                    Circle()
                        .fill(Color(device.status.color))
                        .frame(width: 8, height: 8)
                }
                
                Text(device.os)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let ip = device.ipAddress {
                    Text(ip)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DeviceRowView(device: Device.mockDevices[0])
}
