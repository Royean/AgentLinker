//
//  APIClient.swift
//  AgentLinker
//

import Foundation

// MARK: - API Error Types

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case authenticationRequired
    case serverError(String)
    case timeout
    case noInternet
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .authenticationRequired:
            return "Authentication required. Please log in again."
        case .serverError(let message):
            return "Server error: \(message)"
        case .timeout:
            return "Request timed out"
        case .noInternet:
            return "No internet connection"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .noInternet, .serverError:
            return true
        case .httpError(let statusCode, _):
            // Retry on 5xx errors
            return statusCode >= 500 && statusCode < 600
        default:
            return false
        }
    }
}

// MARK: - Network Status Monitor

class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool = true
    
    static let shared = NetworkMonitor()
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        // In production, use NWPathMonitor from Network framework
        // This is a simplified mock implementation
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkConnectivity()
        }
    }
    
    private func checkConnectivity() {
        // Mock connectivity check
        // In production: let path = monitor.currentPath; isConnected = path.status == .satisfied
        isConnected = true
    }
    
    func waitForInternet(timeout: TimeInterval = 10) async -> Bool {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if isConnected {
                return true
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        return false
    }
}

// MARK: - API Configuration

struct APIConfiguration {
    static let shared = APIConfiguration()
    
    let baseURL: String
    let timeout: TimeInterval
    let maxRetries: Int
    let retryDelay: TimeInterval
    
    private init() {
        // In production, load from environment/config
        self.baseURL = "https://api.agentlinker.example.com"
        self.timeout = 30
        self.maxRetries = 3
        self.retryDelay = 1.0
    }
}

// MARK: - API Client

class APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let config: APIConfiguration
    private let networkMonitor = NetworkMonitor.shared
    private var authToken: String?
    
    private init() {
        self.config = APIConfiguration.shared
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.timeout
        configuration.timeoutIntervalForResource = config.timeout * 2
        configuration.waitsForConnectivity = true
        
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Authentication
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    // MARK: - Request Methods
    
    func get<T: Decodable>(endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        try await request(endpoint: endpoint, method: "GET", queryItems: queryItems)
    }
    
    func post<T: Decodable, B: Encodable>(endpoint: String, body: B) async throws -> T {
        try await request(endpoint: endpoint, method: "POST", body: body)
    }
    
    func post(endpoint: String) async throws {
        try await request(endpoint: endpoint, method: "POST")
    }
    
    func put<T: Decodable, B: Encodable>(endpoint: String, body: B) async throws -> T {
        try await request(endpoint: endpoint, method: "PUT", body: body)
    }
    
    func delete<T: Decodable>(endpoint: String) async throws -> T {
        try await request(endpoint: endpoint, method: "DELETE")
    }
    
    // MARK: - Core Request Implementation
    
    private func request<T: Decodable, B: Encodable>(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: B? = nil
    ) async throws -> T {
        let data: Data = try await request(
            endpoint: endpoint,
            method: method,
            queryItems: queryItems,
            body: body
        )
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    private func request<B: Encodable>(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: B? = nil
    ) async throws -> Data {
        // Check internet connectivity
        if !networkMonitor.isConnected {
            let hasInternet = await networkMonitor.waitForInternet()
            if !hasInternet {
                throw APIError.noInternet
            }
        }
        
        // Build URL
        guard var components = URLComponents(string: config.baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        if let queryItems = queryItems {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        // Execute with retry
        return try await executeWithRetry(request: request)
    }
    
    private func executeWithRetry(request: URLRequest, attempt: Int = 1) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            // Handle HTTP errors
            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8)
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
            }
            
            return data
            
        } catch let error as APIError {
            // Check if we should retry
            if error.isRetryable && attempt < config.maxRetries {
                try await Task.sleep(nanoseconds: UInt64(config.retryDelay * Double(attempt) * 1_000_000_000))
                return try await executeWithRetry(request: request, attempt: attempt + 1)
            }
            throw error
            
        } catch URLError.timedOut {
            if attempt < config.maxRetries {
                try await Task.sleep(nanoseconds: UInt64(config.retryDelay * Double(attempt) * 1_000_000_000))
                return try await executeWithRetry(request: request, attempt: attempt + 1)
            }
            throw APIError.timeout
            
        } catch {
            if let urlError = error as? URLError {
                throw APIError.networkError(urlError)
            }
            throw error
        }
    }
}

// MARK: - API Response Models

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let message: String?
    let errorCode: String?
}

struct PaginatedResponse<T: Decodable>: Decodable {
    let items: [T]
    let total: Int
    let page: Int
    let pageSize: Int
    let hasMore: Bool
}
