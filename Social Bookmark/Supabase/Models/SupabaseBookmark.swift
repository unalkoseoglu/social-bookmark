//
//  SupabaseBookmark.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//


//
//  SupabaseBookmark.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//

import Foundation
import UIKit

/// Supabase'deki bookmarks tablosuna karşılık gelen model
/// SwiftData Bookmark'tan ayrı tutuyoruz çünkü:
/// 1. Farklı property isimleri (snake_case vs camelCase)
/// 2. Supabase'de image binary yerine URL saklanıyor
/// 3. Sync metadata alanları var
struct SupabaseBookmark: Codable, Identifiable, Equatable {
    // MARK: - Primary Fields
    
    let id: UUID
    let userId: UUID
    
    // MARK: - Core Data
    
    var title: String
    var url: String?
    var note: String
    var source: String  // BookmarkSource.rawValue
    
    // MARK: - Status
    
    var isRead: Bool
    var isFavorite: Bool
    
    // MARK: - Organization
    
    var categoryId: UUID?
    var tags: [String]
    
    // MARK: - Media (URLs)
    
    var imageUrls: [String]
    var thumbnailUrl: String?
    
    // MARK: - Content
    
    var extractedText: String?
    var platformMetadata: [String: AnyCodable]?
    
    // MARK: - Timestamps
    
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?  // Soft delete
    
    // MARK: - Sync Fields
    
    var localId: UUID?           // SwiftData'daki ID
    var syncVersion: Int
    var lastModifiedDevice: String?
    var syncStatus: String?      // 'pending', 'synced', etc.
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case url
        case note
        case source
        case isRead = "is_read"
        case isFavorite = "is_favorite"
        case categoryId = "category_id"
        case tags
        case imageUrls = "image_urls"
        case thumbnailUrl = "thumbnail_url"
        case extractedText = "extracted_text"
        case platformMetadata = "platform_metadata"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case localId = "local_id"
        case syncVersion = "sync_version"
        case lastModifiedDevice = "last_modified_device"
        case syncStatus = "sync_status"
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        title: String,
        url: String? = nil,
        note: String = "",
        source: String = "other",
        isRead: Bool = false,
        isFavorite: Bool = false,
        categoryId: UUID? = nil,
        tags: [String] = [],
        imageUrls: [String] = [],
        thumbnailUrl: String? = nil,
        extractedText: String? = nil,
        platformMetadata: [String: AnyCodable]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        localId: UUID? = nil,
        syncVersion: Int = 1,
        lastModifiedDevice: String? = nil,
        syncStatus: String? = "synced"
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.url = url
        self.note = note
        self.source = source
        self.isRead = isRead
        self.isFavorite = isFavorite
        self.categoryId = categoryId
        self.tags = tags
        self.imageUrls = imageUrls
        self.thumbnailUrl = thumbnailUrl
        self.extractedText = extractedText
        self.platformMetadata = platformMetadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.localId = localId
        self.syncVersion = syncVersion
        self.lastModifiedDevice = lastModifiedDevice
        self.syncStatus = syncStatus
    }
}

// MARK: - Conversion Extensions

extension SupabaseBookmark {
    
    /// SwiftData Bookmark'tan SupabaseBookmark oluştur
    /// - Parameters:
    ///   - bookmark: Lokal SwiftData bookmark
    ///   - userId: Supabase user ID
    ///   - imageUrls: Yüklenmiş görsellerin URL'leri
    static func from(
        _ bookmark: Bookmark,
        userId: UUID,
        imageUrls: [String] = [],
        cloudId: UUID? = nil
    ) -> SupabaseBookmark {
        SupabaseBookmark(
            id: cloudId ?? UUID(),  // Yeni kayıt için yeni ID, güncelleme için mevcut
            userId: userId,
            title: bookmark.title,
            url: bookmark.url,
            note: bookmark.note,
            source: bookmark.source.rawValue,
            isRead: bookmark.isRead,
            isFavorite: bookmark.isFavorite,
            categoryId: bookmark.categoryId,
            tags: bookmark.tags,
            imageUrls: imageUrls,
            thumbnailUrl: imageUrls.first,
            extractedText: bookmark.extractedText,
            platformMetadata: nil,
            createdAt: bookmark.createdAt,
            updatedAt: Date(),
            deletedAt: nil,
            localId: bookmark.id,  // SwiftData ID'sini sakla
            syncVersion: 1,
            lastModifiedDevice: deviceIdentifier,
            syncStatus: "synced"
        )
    }
    
    /// SupabaseBookmark'tan SwiftData Bookmark oluştur
    func toLocalBookmark() -> Bookmark {
        let bookmark = Bookmark(
            title: title,
            url: url,
            note: note,
            source: BookmarkSource(rawValue: source) ?? .other,
            isRead: isRead,
            isFavorite: isFavorite,
            categoryId: categoryId,
            tags: tags,
            imageData: nil,  // Görseller ayrı indirilmeli
            imagesData: nil,
            extractedText: extractedText
        )
        
        // ID'yi override et (sync için)
        // Not: SwiftData @Attribute(.unique) olduğu için dikkatli olmalı
        // Normalde yeni Bookmark oluşturulduğunda yeni ID atanır
        // Sync'te localId kullanılmalı
        
        return bookmark
    }
    
    /// Mevcut SwiftData Bookmark'ı güncelle
    func updateLocal(_ bookmark: Bookmark) {
        bookmark.title = title
        bookmark.url = url
        bookmark.note = note
        bookmark.source = BookmarkSource(rawValue: source) ?? .other
        bookmark.isRead = isRead
        bookmark.isFavorite = isFavorite
        bookmark.categoryId = categoryId
        bookmark.tags = tags
        bookmark.extractedText = extractedText
        // createdAt değişmez
        // imageData/imagesData ayrı handle edilmeli
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

extension SupabaseBookmark {
    
    /// İki bookmark arasında değişiklik var mı?
    func hasChanges(comparedTo other: SupabaseBookmark) -> Bool {
        title != other.title ||
        url != other.url ||
        note != other.note ||
        source != other.source ||
        isRead != other.isRead ||
        isFavorite != other.isFavorite ||
        categoryId != other.categoryId ||
        tags != other.tags ||
        extractedText != other.extractedText
    }
    
    /// Conflict resolution: hangisi daha yeni?
    func isNewerThan(_ other: SupabaseBookmark) -> Bool {
        updatedAt > other.updatedAt
    }
}

// MARK: - Insert/Update DTOs

extension SupabaseBookmark {
    
    /// Insert için kullanılacak dictionary
    /// id ve timestamps Supabase tarafından set edilir
    var insertPayload: [String: AnyEncodable] {
        var payload: [String: AnyEncodable] = [
            "user_id": AnyEncodable(userId),
            "title": AnyEncodable(title),
            "note": AnyEncodable(note),
            "source": AnyEncodable(source),
            "is_read": AnyEncodable(isRead),
            "is_favorite": AnyEncodable(isFavorite),
            "tags": AnyEncodable(tags),
            "image_urls": AnyEncodable(imageUrls),
            "sync_version": AnyEncodable(1),
            "local_id": AnyEncodable(localId)
        ]
        
        if let url { payload["url"] = AnyEncodable(url) }
        if let categoryId { payload["category_id"] = AnyEncodable(categoryId) }
        if let thumbnailUrl { payload["thumbnail_url"] = AnyEncodable(thumbnailUrl) }
        if let extractedText { payload["extracted_text"] = AnyEncodable(extractedText) }
        if let lastModifiedDevice { payload["last_modified_device"] = AnyEncodable(lastModifiedDevice) }
        
        return payload
    }
    
    /// Update için kullanılacak dictionary
    var updatePayload: [String: AnyEncodable] {
        var payload = insertPayload
        payload["sync_version"] = AnyEncodable(syncVersion + 1)
        payload["updated_at"] = AnyEncodable(ISO8601DateFormatter().string(from: Date()))
        return payload
    }
}

// MARK: - AnyCodable Helper

/// JSON'da any type değer saklamak için
struct AnyCodable: Codable, Equatable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
    
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}

/// Encode için type-erased wrapper
/// Type-erased Encodable wrapper
struct AnyEncodable: Encodable {
    private let value: any Encodable
    
    init<T: Encodable>(_ value: T) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
