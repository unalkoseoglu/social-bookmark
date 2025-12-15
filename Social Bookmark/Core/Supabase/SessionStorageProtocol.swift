//
//  SessionStorageProtocol.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//


// Core/Supabase/KeychainSessionStore.swift

import Foundation
import OSLog
import Security

/// Protocol for session storage (enables testing)
protocol SessionStorageProtocol: Sendable {
    func store(_ data: Data, forKey key: String) throws
    func retrieve(forKey key: String) throws -> Data?
    func delete(forKey key: String) throws
}

/// Secure Keychain-based storage for Supabase session
final class KeychainSessionStorage: SessionStorageProtocol, @unchecked Sendable {
    
    private let serviceName: String
    private let accessGroup: String?
    
    init(serviceName: String = Bundle.main.bundleIdentifier ?? "com.app.supabase",
         accessGroup: String? = nil) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }
    
    func store(_ data: Data, forKey key: String) throws {
        // Delete existing item first
        try? delete(forKey: key)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            Logger.keychain.error("Failed to store item: \(status)")
            throw KeychainError.storeFailed(status)
        }
        
        Logger.keychain.debug("Stored session data for key: \(key)")
    }
    
    func retrieve(forKey key: String) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            Logger.keychain.debug("Retrieved session data for key: \(key)")
            return result as? Data
        case errSecItemNotFound:
            Logger.keychain.debug("No session data found for key: \(key)")
            return nil
        default:
            Logger.keychain.error("Failed to retrieve item: \(status)")
            throw KeychainError.retrieveFailed(status)
        }
    }
    
    func delete(forKey key: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Logger.keychain.error("Failed to delete item: \(status)")
            throw KeychainError.deleteFailed(status)
        }
        
        Logger.keychain.debug("Deleted session data for key: \(key)")
    }
}

enum KeychainError: Error, LocalizedError {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "Failed to store in Keychain (status: \(status))"
        case .retrieveFailed(let status):
            return "Failed to retrieve from Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        }
    }
}