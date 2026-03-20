//
//  KeychainManager.swift
//  AgentLinker
//

import Foundation
import Security

/// Keychain error types
enum KeychainError: Error, LocalizedError {
    case duplicateItem
    case itemNotFound
    case invalidItemReference
    case userCanceled
    case unknown(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "Item already exists in keychain"
        case .itemNotFound:
            return "Item not found in keychain"
        case .invalidItemReference:
            return "Invalid item reference"
        case .userCanceled:
            return "User canceled the operation"
        case .unknown(let status):
            return "Unknown keychain error: \(status)"
        }
    }
}

/// Manages secure storage of credentials in the macOS Keychain
class KeychainManager {
    
    // MARK: - Shared Instance
    static let shared = KeychainManager()
    
    // MARK: - Constants
    private let serviceName = "com.agentlinker.app"
    private let accountKeyEmail = "com.agentlinker.email"
    private let accountKeyToken = "com.agentlinker.token"
    private let accountKeyRefreshToken = "com.agentlinker.refreshToken"
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Save email to keychain
    /// - Parameter email: User email to store
    /// - Throws: KeychainError if operation fails
    func saveEmail(_ email: String) throws {
        let data = Data(email.utf8)
        
        // First, try to update existing item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKeyEmail
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        // Try to add new item
        var status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Item exists, update it
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.from(status: status)
        }
    }
    
    /// Retrieve email from keychain
    /// - Returns: Stored email or nil if not found
    /// - Throws: KeychainError if operation fails
    func getEmail() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKeyEmail,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.from(status: status)
        }
        
        guard let data = result as? Data,
              let email = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return email
    }
    
    /// Save authentication token to keychain
    /// - Parameters:
    ///   - token: Access token
    ///   - refreshToken: Refresh token (optional)
    /// - Throws: KeychainError if operation fails
    func saveToken(_ token: String, refreshToken: String? = nil) throws {
        let tokenData = Data(token.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKeyToken
        ]
        
        var attributes: [String: Any] = [
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        if let refreshToken = refreshToken {
            attributes["refreshToken"] = refreshToken
        }
        
        // Try to add new item
        var status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Item exists, update it
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.from(status: status)
        }
    }
    
    /// Retrieve authentication token from keychain
    /// - Returns: Stored token or nil if not found
    /// - Throws: KeychainError if operation fails
    func getToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKeyToken,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.from(status: status)
        }
        
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    /// Delete all stored credentials from keychain
    /// - Throws: KeychainError if operation fails
    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.from(status: status)
        }
    }
    
    /// Check if user has stored credentials
    /// - Returns: true if credentials exist
    func hasCredentials() -> Bool {
        do {
            return try getEmail() != nil || try getToken() != nil
        } catch {
            return false
        }
    }
}

// MARK: - Helper Extensions

extension KeychainError {
    static func from(status: OSStatus) -> KeychainError {
        switch status {
        case errSecDuplicateItem:
            return .duplicateItem
        case errSecItemNotFound:
            return .itemNotFound
        case errSecInvalidItemReference:
            return .invalidItemReference
        case errSecUserCanceled:
            return .userCanceled
        default:
            return .unknown(status)
        }
    }
}
