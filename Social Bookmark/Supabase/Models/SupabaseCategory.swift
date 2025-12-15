//
//  SupabaseCategory.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//

import Foundation

/// Supabase'deki categories tablosuna karşılık gelen model
struct SupabaseCategory: Codable, Identifiable, Equatable {
    // MARK: - Primary Fields
    
    let id: UUID
    let userId: UUID
    
    // MARK: - Category Data
    
    var name: String
    var icon: String
    var colorHex: String
    var order: Int
    
    // MARK: - Timestamps
    
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?  // Soft delete
    
    // MARK: - Sync Fields
    
    var localId: UUID?
    var syncVersion: Int
    var lastModifiedDevice: String?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case icon
        case colorHex = "color_hex"
        case order
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case localId = "local_id"
        case syncVersion = "sync_version"
        case lastModifiedDevice = "last_modified_device"
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        icon: String = "folder.fill",
        colorHex: String = "#007AFF",
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        localId: UUID? = nil,
        syncVersion: Int = 1,
        lastModifiedDevice: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.localId = localId
        self.syncVersion = syncVersion
        self.lastModifiedDevice = lastModifiedDevice
    }
}

// MARK: - Conversion Extensions

extension SupabaseCategory {
    
    /// SwiftData Category'den SupabaseCategory oluştur
    static func from(
        _ category: Category,
        userId: UUID,
        cloudId: UUID? = nil
    ) -> SupabaseCategory {
        SupabaseCategory(
            id: cloudId ?? UUID(),
            userId: userId,
            name: category.name,
            icon: category.icon,
            colorHex: category.colorHex,
            order: category.order,
            createdAt: category.createdAt,
            updatedAt: Date(),
            deletedAt: nil,
            localId: category.id,
            syncVersion: 1,
            lastModifiedDevice: deviceIdentifier
        )
    }
    
    /// SupabaseCategory'den SwiftData Category oluştur
    func toLocalCategory() -> Category {
        Category(
            id: localId ?? id,  // Eğer localId varsa onu kullan
            name: name,
            icon: icon,
            colorHex: colorHex,
            order: order
        )
    }
    
    /// Mevcut SwiftData Category'yi güncelle
    func updateLocal(_ category: Category) {
        category.name = name
        category.icon = icon
        category.colorHex = colorHex
        category.order = order
        // createdAt değişmez
    }
    
    /// Cihaz tanımlayıcısı
    private static var deviceIdentifier: String {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios"
        #else
        return "unknown-device"
        #endif
    }
}

// MARK: - Comparison

extension SupabaseCategory {
    
    /// İki kategori arasında değişiklik var mı?
    func hasChanges(comparedTo other: SupabaseCategory) -> Bool {
        name != other.name ||
        icon != other.icon ||
        colorHex != other.colorHex ||
        order != other.order
    }
    
    /// Conflict resolution: hangisi daha yeni?
    func isNewerThan(_ other: SupabaseCategory) -> Bool {
        updatedAt > other.updatedAt
    }
}

// MARK: - Insert/Update DTOs

extension SupabaseCategory {
    
    /// Insert için payload
    var insertPayload: [String: AnyEncodable] {
        var payload: [String: AnyEncodable] = [
            "user_id": AnyEncodable(userId),
            "name": AnyEncodable(name),
            "icon": AnyEncodable(icon),
            "color_hex": AnyEncodable(colorHex),
            "order": AnyEncodable(order),
            "sync_version": AnyEncodable(1)
        ]
        
        if let localId {
            payload["local_id"] = AnyEncodable(localId)
        }
        if let lastModifiedDevice {
            payload["last_modified_device"] = AnyEncodable(lastModifiedDevice)
        }
        
        return payload
    }
    
    /// Update için payload
    var updatePayload: [String: AnyEncodable] {
        var payload = insertPayload
        payload["sync_version"] = AnyEncodable(syncVersion + 1)
        payload["updated_at"] = AnyEncodable(ISO8601DateFormatter().string(from: Date()))
        return payload
    }
}

// MARK: - Default Categories

extension SupabaseCategory {
    
    /// Varsayılan kategorileri oluştur
    static func createDefaults(for userId: UUID) -> [SupabaseCategory] {
        let defaults: [(name: String, icon: String, color: String)] = [
            ("İş", "briefcase.fill", "#007AFF"),
            ("Okuma Listesi", "book.fill", "#34C759"),
            ("Araştırma", "magnifyingglass", "#FF9500"),
            ("İlham", "lightbulb.fill", "#FFD60A"),
            ("Teknoloji", "laptopcomputer", "#5856D6"),
            ("Eğlence", "play.circle.fill", "#FF2D55")
        ]
        
        return defaults.enumerated().map { index, category in
            SupabaseCategory(
                userId: userId,
                name: category.name,
                icon: category.icon,
                colorHex: category.color,
                order: index
            )
        }
    }
}