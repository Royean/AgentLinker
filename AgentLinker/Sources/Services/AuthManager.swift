//
//  AuthManager.swift
//  AgentLinker
//

import Foundation
import Combine

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let keychainManager = KeychainManager.shared
    private let apiClient = APIClient.shared
    
    // MARK: - API Request/Response Models
    
    private struct LoginRequest: Encodable {
        let email: String
        let password: String
    }
    
    private struct RegisterRequest: Encodable {
        let email: String
        let password: String
        let name: String
    }
    
    private struct AuthResponse: Decodable {
        let user: UserData
        let token: String
        let refreshToken: String
        
        struct UserData: Decodable {
            let id: String
            let email: String
            let name: String
            let avatar: String?
        }
    }
    
    init() {
        checkExistingSession()
    }
    
    func checkExistingSession() {
        // Check keychain for stored credentials
        do {
            if let savedEmail = try keychainManager.getEmail() {
                if let savedToken = try keychainManager.getToken() {
                    // Set token for API client
                    apiClient.setAuthToken(savedToken)
                    // Valid session exists
                    currentUser = User(id: "user_123", email: savedEmail, name: "User", avatar: nil)
                    isLoggedIn = true
                }
            }
        } catch {
            // Keychain error, treat as no session
            isLoggedIn = false
            currentUser = nil
        }
    }
    
    func login(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        // Validate input
        if email.isEmpty || password.isEmpty {
            errorMessage = "Please enter valid credentials"
            isLoading = false
            return false
        }
        
        do {
            // In production, uncomment to use real API:
            // let response: AuthResponse = try await apiClient.post(
            //     endpoint: "/auth/login",
            //     body: LoginRequest(email: email, password: password)
            // )
            
            // Mock authentication (replace with API call above)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let response = AuthResponse(
                user: .init(id: "user_123", email: email, name: "User", avatar: nil),
                token: "mock_token_\(email)",
                refreshToken: "mock_refresh_\(email)"
            )
            
            // Save credentials
            currentUser = User(
                id: response.user.id,
                email: response.user.email,
                name: response.user.name,
                avatar: response.user.avatar
            )
            isLoggedIn = true
            
            try keychainManager.saveEmail(email)
            try keychainManager.saveToken(response.token, refreshToken: response.refreshToken)
            apiClient.setAuthToken(response.token)
            
            isLoading = false
            return true
            
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            return false
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func register(email: String, password: String, name: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        // Validate input
        if email.isEmpty || password.isEmpty || name.isEmpty {
            errorMessage = "Please fill in all fields"
            isLoading = false
            return false
        }
        
        do {
            // In production, uncomment to use real API:
            // let response: AuthResponse = try await apiClient.post(
            //     endpoint: "/auth/register",
            //     body: RegisterRequest(email: email, password: password, name: name)
            // )
            
            // Mock registration (replace with API call above)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let response = AuthResponse(
                user: .init(id: "user_123", email: email, name: name, avatar: nil),
                token: "mock_token_\(email)",
                refreshToken: "mock_refresh_\(email)"
            )
            
            // Save credentials
            currentUser = User(
                id: response.user.id,
                email: response.user.email,
                name: response.user.name,
                avatar: response.user.avatar
            )
            isLoggedIn = true
            
            try keychainManager.saveEmail(email)
            try keychainManager.saveToken(response.token, refreshToken: response.refreshToken)
            apiClient.setAuthToken(response.token)
            
            isLoading = false
            return true
            
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            return false
        } catch {
            errorMessage = "Registration failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func logout() {
        isLoggedIn = false
        currentUser = nil
        apiClient.setAuthToken(nil)
        
        do {
            try keychainManager.clearAll()
        } catch {
            // Log error but don't prevent logout
            print("Failed to clear keychain: \(error)")
        }
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // In production, uncomment to use real API:
            // try await apiClient.post(
            //     endpoint: "/auth/reset-password",
            //     body: ["email": email]
            // )
            
            // Mock password reset
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            isLoading = false
            return true
            
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            return false
        } catch {
            errorMessage = "Password reset failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
}
