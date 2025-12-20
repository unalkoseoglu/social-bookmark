//
//  User+Extensions.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 19.12.2025.
//
//  Supabase User için extension'lar
//

import Foundation
import Supabase
import Auth

// MARK: - User Anonymous Check Extension

extension User {
    /// Kullanıcının anonim olup olmadığını kontrol eder
    /// Supabase'de anonim kullanıcıların özellikleri:
    /// 1. email nil olabilir
    /// 2. identities boş olabilir veya sadece "anonymous" provider içerebilir
    /// 3. is_anonymous metadata'sı true olabilir
    var isAnonymousUser: Bool {
        // Yöntem 1: Email ve identities kontrolü
        if email == nil {
            // identities boşsa veya sadece anonymous provider varsa
            if identities?.isEmpty ?? true {
                return true
            }
            
            // Sadece anonymous provider varsa
            if let identities = identities,
               identities.count == 1,
               identities.first?.provider == "anonymous" {
                return true
            }
        }
        
        // Yöntem 2: User metadata kontrolü
        if let isAnon = userMetadata["is_anonymous"] {
            switch isAnon {
            case .bool(let value):
                return value
            case .string(let value):
                return value.lowercased() == "true"
            default:
                break
            }
        }
        
        // Yöntem 3: App metadata kontrolü
        if let isAnon = appMetadata["provider"] {
            if case .string(let provider) = isAnon {
                return provider == "anonymous"
            }
        }
        
        return false
    }
}

// MARK: - Debug Extension

extension User {
    /// Debug bilgilerini yazdır
    func printDebugInfo() {
        print("═══════════════════════════════════════")
        print("👤 USER DEBUG INFO")
        print("═══════════════════════════════════════")
        print("ID: \(id)")
        print("Email: \(email ?? "nil")")
        print("Phone: \(phone ?? "nil")")
        print("Created At: \(createdAt)")
        print("Is Anonymous (computed): \(isAnonymousUser)")
        print("")
        print("Identities count: \(identities?.count ?? 0)")
        identities?.forEach { identity in
            print("  - Provider: \(identity.provider)")
            print("    ID: \(identity.id)")
        }
        print("")
        print("User Metadata:")
        userMetadata.forEach { key, value in
            print("  \(key): \(value)")
        }
        print("")
        print("App Metadata:")
        appMetadata.forEach { key, value in
            print("  \(key): \(value)")
        }
        print("═══════════════════════════════════════")
    }
}
