//
//  WebSocketManager.swift
//  AgentLinker macOS
//

import Foundation
import Starscream

class WebSocketManager: ObservableObject, WebSocketDelegate {
    @Published var isConnected = false
    @Published var lastError: String?

    private var socket: WebSocket?
    private let serverUrl: String
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let heartbeatInterval: TimeInterval = 30
    private var currentDeviceId: String = ""
    private var currentDeviceName: String = ""
    private var currentToken: String = ""

    init(serverUrl: String = "ws://43.98.243.80:8080/ws/client") {
        self.serverUrl = serverUrl
    }

    func connect(deviceId: String, deviceName: String, token: String) {
        self.currentDeviceId = deviceId
        self.currentDeviceName = deviceName
        self.currentToken = token

        guard let url = URL(string: serverUrl) else {
            lastError = "Invalid server URL"
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected:
            print("✅ WebSocket connected")
            isConnected = true
            reconnectAttempts = 0
            lastError = nil
            registerDevice(deviceId: currentDeviceId, deviceName: currentDeviceName, token: currentToken)

        case .disconnected(let reason, _):
            let errorMsg = reason
            print("❌ WebSocket disconnected: \(errorMsg)")
            isConnected = false
            stopHeartbeat()
            scheduleReconnect()

        case .text(let string):
            handleMessage(string)

        case .binary(let data):
            print("Received binary data: \(data.count) bytes")

        case .ping(let data):
            print("Ping received: \(data?.count ?? 0) bytes")

        case .pong(let data):
            print("Pong received: \(data?.count ?? 0) bytes")

        case .viabilityChanged(let isViable):
            print("Viability changed: \(isViable)")

        case .reconnectSuggested(let shouldReconnect):
            print("Reconnect suggested: \(shouldReconnect)")
            if shouldReconnect {
                scheduleReconnect()
            }

        case .peerClosed:
            print("Peer closed connection")
            isConnected = false

        case .error(let error):
            let errorMsg = error?.localizedDescription ?? "unknown"
            print("WebSocket error: \(errorMsg)")
            lastError = errorMsg
            isConnected = false

        default:
            break
        }
    }
    
    func disconnect() {
        stopHeartbeat()
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        socket?.disconnect()
        socket = nil
        isConnected = false
    }
    
    func send(message: WebSocketMessage) {
        guard isConnected, let socket = socket else {
            lastError = "Not connected"
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(message)
            if let jsonString = String(data: data, encoding: .utf8) {
                socket.write(string: jsonString)
                print("📤 Sent: \(jsonString)")
            }
        } catch {
            lastError = "Failed to encode message: \(error.localizedDescription)"
        }
    }
    
    private func registerDevice(deviceId: String, deviceName: String, token: String) {
        let register = DeviceRegister(
            device_id: deviceId,
            device_name: deviceName,
            token: token
        )
        sendRegister(message: register)
    }

    private func sendRegister(message: DeviceRegister) {
        guard isConnected, let socket = socket else {
            lastError = "Not connected"
            return
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(message)
            if let jsonString = String(data: data, encoding: .utf8) {
                socket.write(string: jsonString)
                print("📤 Sent: \(jsonString)")
            }
        } catch {
            lastError = "Failed to encode message: \(error.localizedDescription)"
        }
    }
    
    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            lastError = "Max reconnect attempts reached"
            return
        }

        reconnectAttempts += 1
        let delay = Double(reconnectAttempts) * 2.0 // Exponential backoff

        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            print("🔄 Reconnecting (attempt \(self?.reconnectAttempts ?? 0)/\(self?.maxReconnectAttempts ?? 5))...")
            self?.connect(deviceId: self?.currentDeviceId ?? "", deviceName: self?.currentDeviceName ?? "", token: self?.currentToken ?? "")
        }
    }
    
    private func handleMessage(_ string: String) {
        print("📥 Received: \(string)")

        guard let data = string.data(using: .utf8) else { return }

        do {
            let response = try JSONDecoder().decode(ServerResponse.self, from: data)

            switch response.type {
            case "registered":
                print("✅ Device registered successfully")
                startHeartbeat()
            case "pong":
                print("🏓 Pong received from server")
            case "pairing_key":
                print("🔑 Pairing key received: \(response.pairing_key ?? "N/A")")
            case "error":
                print("❌ Server error: \(response.msg ?? "unknown")")
                lastError = response.msg
            case "command":
                print("📊 Command received")
            default:
                print("ℹ️ Unknown message type: \(response.type)")
            }
        } catch {
            print("Failed to parse message: \(error)")
        }
    }

    // MARK: - Heartbeat
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
        // 立即发送第一个 ping
        sendPing()
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func sendPing() {
        guard isConnected, let socket = socket else { return }

        let pingMessage: [String: Any] = [
            "type": "ping",
            "time": Date().timeIntervalSince1970
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: pingMessage)
            if let jsonString = String(data: data, encoding: .utf8) {
                socket.write(string: jsonString)
                print("💓 Heartbeat sent")
            }
        } catch {
            print("Failed to send heartbeat: \(error)")
        }
    }
}
