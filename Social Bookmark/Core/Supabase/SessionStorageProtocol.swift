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
import Auth
import Foundation

// MARK: - Keychain Session Storage

/// Supabase session'ını Keychain'de saklayan custom storage
/// AuthLocalStorage protokolünü implement eder
final class KeychainSessionStorage: AuthLocalStorage, @unchecked Sendable {
    
    private let service: String
    private let accessGroup: String?
    
    init() {
        // Bundle ID'yi service olarak kullan
        self.service = Bundle.main.bundleIdentifier ?? "com.unal.socialbookmark"
        
        // App Group kullan (Share Extension ile paylaşım için)
        self.accessGroup = "group.com.unal.socialbookmark"
        
        print("🔑 [KEYCHAIN] Initialized")
        print("   Service: \(service)")
        print("   Access Group: \(accessGroup ?? "none")")
    }
    
    func store(key: String, value: Data) throws {
        let fullKey = "supabase_\(key)"
        print("💾 [KEYCHAIN] Storing: \(fullKey) (\(value.count) bytes)")
        
        // Önce mevcut değeri sil
        try? remove(key: key)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fullKey,
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // App Group varsa ekle
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ [KEYCHAIN] Stored successfully: \(fullKey)")
        } else if status == errSecDuplicateItem {
            // Duplicate ise update dene
            print("⚠️ [KEYCHAIN] Duplicate, updating: \(fullKey)")
            
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: fullKey
            ]
            
            let updateQuery: [String: Any] = [
                kSecValueData as String: value
            ]
            
            let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateQuery as CFDictionary)
            if updateStatus != errSecSuccess {
                print("❌ [KEYCHAIN] Update failed: \(updateStatus)")
                throw KeychainError.storeFailed(updateStatus)
            }
            print("✅ [KEYCHAIN] Updated successfully: \(fullKey)")
        } else {
            print("❌ [KEYCHAIN] Store failed: \(status)")
            throw KeychainError.storeFailed(status)
        }
    }
    
    func retrieve(key: String) throws -> Data? {
        let fullKey = "supabase_\(key)"
        print("🔍 [KEYCHAIN] Retrieving: \(fullKey)")
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fullKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // App Group varsa ekle
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            print("✅ [KEYCHAIN] Retrieved: \(fullKey) (\(data.count) bytes)")
            return data
        } else if status == errSecItemNotFound {
            print("ℹ️ [KEYCHAIN] Not found: \(fullKey)")
            return nil
        } else {
            print("❌ [KEYCHAIN] Retrieve failed: \(status)")
            throw KeychainError.retrieveFailed(status)
        }
    }
    
    func remove(key: String) throws {
        let fullKey = "supabase_\(key)"
        print("🗑️ [KEYCHAIN] Removing: \(fullKey)")
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fullKey
        ]
        
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ [KEYCHAIN] Removed: \(fullKey)")
        } else {
            print("❌ [KEYCHAIN] Remove failed: \(status)")
            throw KeychainError.removeFailed(status)
        }
    }
    
    /// Debug: Keychain'deki tüm ilgili key'leri listele
    func debugPrintStoredKeys() {
        print("🔑 [KEYCHAIN DEBUG] Listing stored keys...")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            print("   Found \(items.count) items:")
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String {
                    print("   - \(account)")
                }
            }
        } else if status == errSecItemNotFound {
            print("   No items found for service: \(service)")
        } else {
            print("   Query failed with status: \(status)")
        }
    }
    
    enum KeychainError: LocalizedError {
        case storeFailed(OSStatus)
        case retrieveFailed(OSStatus)
        case removeFailed(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .storeFailed(let status): return "Keychain store failed: \(status)"
            case .retrieveFailed(let status): return "Keychain retrieve failed: \(status)"
            case .removeFailed(let status): return "Keychain remove failed: \(status)"
            }
        }
    }
}
