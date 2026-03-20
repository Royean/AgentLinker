//
//  WebSocketManager.swift
//  AgentLinker macOS
//

import Foundation
import Starscream

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
}

class WebSocketManager: ObservableObject, WebSocketDelegate {
    @Published var isConnected = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?
    @Published var lastMessage: String?

    private var socket: WebSocket?
    private let serverUrl: String
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private let heartbeatInterval: TimeInterval = 30
    private var currentDeviceId: String = ""
    private var currentDeviceName: String = ""
    private var currentToken: String = ""
    private var messageHandler: ((String) -> Void)?

    init(serverUrl: String = "ws://43.98.243.80:8080/ws/client") {
        self.serverUrl = serverUrl
    }
    
    func setMessageHandler(_ handler: @escaping (String) -> Void) {
        self.messageHandler = handler
    }

    func connect(deviceId: String, deviceName: String, token: String) {
        self.currentDeviceId = deviceId
        self.currentDeviceName = deviceName
        self.currentToken = token
        
        DispatchQueue.main.async {
            self.connectionState = .connecting
        }

        guard let url = URL(string: serverUrl) else {
            DispatchQueue.main.async {
                self.lastError = "Invalid server URL"
                self.connectionState = .failed
            }
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected:
            print("✅ WebSocket connected")
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionState = .connected
                self.reconnectAttempts = 0
                self.lastError = nil
            }
            registerDevice(deviceId: currentDeviceId, deviceName: currentDeviceName, token: currentToken)

        case .disconnected(let reason, _):
            let errorMsg = reason
            print("❌ WebSocket disconnected: \(errorMsg)")
            DispatchQueue.main.async {
                self.isConnected = false
                self.connectionState = .disconnected
            }
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
            if !isViable {
                DispatchQueue.main.async {
                    self.connectionState = .reconnecting
                }
            }

        case .reconnectSuggested(let shouldReconnect):
            print("Reconnect suggested: \(shouldReconnect)")
            if shouldReconnect {
                scheduleReconnect()
            }

        case .peerClosed:
            print("Peer closed connection")
            DispatchQueue.main.async {
                self.isConnected = false
                self.connectionState = .disconnected
            }

        case .error(let error):
            let errorMsg = error?.localizedDescription ?? "unknown"
            print("WebSocket error: \(errorMsg)")
            DispatchQueue.main.async {
                self.lastError = errorMsg
                self.isConnected = false
                self.connectionState = .failed
            }

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
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionState = .disconnected
        }
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
            DispatchQueue.main.async {
                self.lastError = "Max reconnect attempts reached. Please check your connection."
                self.connectionState = .failed
            }
            return
        }

        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 2.0, 30.0) // Exponential backoff, max 30s

        DispatchQueue.main.async {
            self.connectionState = .reconnecting
        }

        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            print("🔄 Reconnecting (attempt \(self?.reconnectAttempts ?? 0)/\(self?.maxReconnectAttempts ?? 10))...")
            self?.connect(deviceId: self?.currentDeviceId ?? "", deviceName: self?.currentDeviceName ?? "", token: self?.currentToken ?? "")
        }
    }
    
    private func handleMessage(_ string: String) {
        print("📥 Received: \(string)")
        
        DispatchQueue.main.async {
            self.lastMessage = string
        }

        guard let data = string.data(using: .utf8) else { return }

        do {
            let response = try JSONDecoder().decode(ServerResponse.self, from: data)

            switch response.type {
            case "registered":
                print("✅ Device registered successfully")
                startHeartbeat()
            case "pong":
                print("🏓 Pong received from server")
                // Reset reconnect attempts on successful pong
                reconnectAttempts = 0
            case "pairing_key":
                print("🔑 Pairing key received: \(response.pairing_key ?? "N/A")")
            case "error":
                print("❌ Server error: \(response.msg ?? "unknown")")
                DispatchQueue.main.async {
                    self.lastError = response.msg
                }
            case "command":
                print("📊 Command received")
                // Forward to message handler if set
                messageHandler?(string)
            default:
                print("ℹ️ Unknown message type: \(response.type)")
                messageHandler?(string)
            }
        } catch {
            print("Failed to parse message: \(error)")
            // Try to handle as raw JSON
            messageHandler?(string)
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
