//
//  UserProfile.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//

import Foundation
import UIKit

struct UserProfile: Codable {
    let id: UUID
    var email: String?
    var fullName: String?
    var displayName: String          // Her zaman görüntülenecek isim (örn: "user_7F3A9C")
    var isAnonymous: Bool
    let createdAt: Date
    var avatarUrl: String?
    var lastSyncAt: Date?
    var deviceId: String?            // Cihaz tanımlayıcı
    var appVersion: String?          // Uygulama versiyonu
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case displayName = "display_name"
        case isAnonymous = "is_anonymous"
        case createdAt = "created_at"
        case avatarUrl = "avatar_url"
        case lastSyncAt = "last_sync_at"
        case deviceId = "device_id"
        case appVersion = "app_version"
    }
    
    // MARK: - Default Init
    
    init(
        id: UUID,
        email: String? = nil,
        fullName: String? = nil,
        displayName: String,
        isAnonymous: Bool,
        createdAt: Date = Date(),
        avatarUrl: String? = nil,
        lastSyncAt: Date? = nil,
        deviceId: String? = nil,
        appVersion: String? = nil
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.displayName = displayName
        self.isAnonymous = isAnonymous
        self.createdAt = createdAt
        self.avatarUrl = avatarUrl
        self.lastSyncAt = lastSyncAt
        self.deviceId = deviceId
        self.appVersion = appVersion
    }
    
    // MARK: - Convenience Factory Methods
    
    /// Anonim kullanıcı için profil oluştur
    /// Display name UUID'den türetilir: "user_7F3A9C"
    static func createAnonymous(userId: UUID) -> UserProfile {
        UserProfile(
            id: userId,
            email: nil,
            fullName: nil,
            displayName: RandomNameGenerator.generate(from: userId),
            isAnonymous: true,
            createdAt: Date(),
            avatarUrl: nil,
            lastSyncAt: nil,
            deviceId: Self.currentDeviceId,
            appVersion: Self.currentAppVersion
        )
    }
    
    /// Normal kullanıcı için profil oluştur
    static func create(userId: UUID, email: String?, fullName: String?) -> UserProfile {
        // Display name önceliği: fullName > email prefix > random
        let displayName: String
        if let name = fullName, !name.isEmpty {
            displayName = name
        } else if let email = email, let prefix = email.components(separatedBy: "@").first, !prefix.isEmpty {
            displayName = prefix
        } else {
            displayName = RandomNameGenerator.generate(from: userId)
        }
        
        return UserProfile(
            id: userId,
            email: email,
            fullName: fullName,
            displayName: displayName,
            isAnonymous: false,
            createdAt: Date(),
            avatarUrl: nil,
            lastSyncAt: nil,
            deviceId: Self.currentDeviceId,
            appVersion: Self.currentAppVersion
        )
    }
    
    // MARK: - Device Info Helpers
    
    private static var currentDeviceId: String? {
        UIDevice.current.identifierForVendor?.uuidString
    }
    
    private static var currentAppVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// MARK: - Computed Properties

extension UserProfile {
    
    /// Gösterilecek isim (UI için)
    /// fullName varsa onu, yoksa displayName'i döndürür
    var nameForDisplay: String {
        if let fullName = fullName, !fullName.isEmpty {
            return fullName
        }
        return displayName
    }
    
    /// Kısa gösterim (avatar initials için)
    /// "user_7F3A9C" -> "U7"
    /// "John Doe" -> "JD"
    var initials: String {
        if let fullName = fullName, !fullName.isEmpty {
            let components = fullName.components(separatedBy: " ")
            let initials = components.compactMap { $0.first }.prefix(2)
            return String(initials).uppercased()
        }
        
        // user_XXXXXX formatı için
        if displayName.hasPrefix("user_") {
            let suffix = displayName.dropFirst(5)
            if let firstChar = suffix.first {
                return "U\(firstChar)"
            }
        }
        
        return "U"
    }
    
    
}
