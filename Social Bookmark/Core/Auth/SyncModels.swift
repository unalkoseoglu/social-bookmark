import Foundation

/// Common response for list endpoints
struct CloudListResponse<T: Codable>: Codable {
    let data: [T]
}

/// Response from /sync/delta
struct DeltaSyncResponse: Codable {
    let updatedCategories: [CloudCategory]
    let updatedBookmarks: [CloudBookmark]
    let deletedIds: [String: [String]] // categories, bookmarks
    let currentServerTime: String
    
    enum CodingKeys: String, CodingKey {
        case updatedCategories = "updated_categories"
        case updatedBookmarks = "updated_bookmarks"
        case deletedIds = "deleted_ids"
        case currentServerTime = "current_server_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle updatedCategories: Try decoding as Array first, then fall back to Dictionary (PHP/Laravel behavior with sparse arrays)
        if let array = try? container.decode([CloudCategory].self, forKey: .updatedCategories) {
            updatedCategories = array
        } else if let dict = try? container.decode([String: CloudCategory].self, forKey: .updatedCategories) {
            updatedCategories = Array(dict.values)
        } else {
            // Default to empty if key is missing or null
            updatedCategories = []
        }
        
        // Handle updatedBookmarks: Try decoding as Array first, then fall back to Dictionary
        if let array = try? container.decode([CloudBookmark].self, forKey: .updatedBookmarks) {
            updatedBookmarks = array
        } else if let dict = try? container.decode([String: CloudBookmark].self, forKey: .updatedBookmarks) {
            updatedBookmarks = Array(dict.values)
        } else {
            // Default to empty if key is missing or null
            updatedBookmarks = []
        }
        
        deletedIds = try container.decode([String: [String]].self, forKey: .deletedIds)
        currentServerTime = try container.decode(String.self, forKey: .currentServerTime)
    }
}

struct DeltaSyncRequest: Codable {
    let lastSyncTimestamp: String?
    let bookmarks: [CloudBookmark]?
    let categories: [CloudCategory]?
    
    enum CodingKeys: String, CodingKey {
        case lastSyncTimestamp = "last_sync_timestamp"
        case bookmarks, categories
    }
}

struct CloudCategory: Codable, Identifiable {
    let id: UUID
    var localId: UUID?
    var name: String
    var icon: String
    var color: String
    var order: Int
    var isEncrypted: Bool?
    var bookmarksCount: Int?
    var createdAt: String?
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, color, order
        case localId = "local_id"
        case isEncrypted = "is_encrypted"
        case bookmarksCount = "bookmarks_count"
        case bookmarkCount = "bookmark_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        localId = try container.decodeIfPresent(UUID.self, forKey: .localId)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(String.self, forKey: .color)
        order = try container.decode(Int.self, forKey: .order)
        
        // Safe decoding for is_encrypted
        if let boolVal = try? container.decode(Bool.self, forKey: .isEncrypted) {
            isEncrypted = boolVal
        } else if let intVal = try? container.decode(Int.self, forKey: .isEncrypted) {
            isEncrypted = intVal == 1
        } else if let stringVal = try? container.decode(String.self, forKey: .isEncrypted) {
            isEncrypted = stringVal.lowercased() == "true" || stringVal == "1"
        } else {
            isEncrypted = false
        }
        
        // Try plural first, then singular
        bookmarksCount = try container.decodeIfPresent(Int.self, forKey: .bookmarksCount) ?? 
                         container.decodeIfPresent(Int.self, forKey: .bookmarkCount)
                         
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(localId, forKey: .localId)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(color, forKey: .color)
        try container.encode(order, forKey: .order)
        try container.encodeIfPresent(isEncrypted, forKey: .isEncrypted)
        try container.encodeIfPresent(bookmarksCount, forKey: .bookmarksCount)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct CloudBookmark: Codable, Identifiable {
    let id: UUID
    var localId: UUID?
    var categoryId: UUID?
    var title: String
    var url: String?
    var note: String?
    var source: String
    var isRead: Bool
    var isFavorite: Bool
    var tags: [String]?
    var imageUrls: [String]?
    var fileUrl: String?
    var syncVersion: Int
    var isEncrypted: Bool?
    var linkedBookmarkIds: [String]?
    var createdAt: String?
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, url, note, source, tags
        case localId = "local_id"
        case categoryId = "category_id"
        case isRead = "is_read"
        case isFavorite = "is_favorite"
        case imageUrls = "image_urls"
        case fileUrl = "file_url"
        case syncVersion = "sync_version"
        case isEncrypted = "is_encrypted"
        case linkedBookmarkIds = "linked_bookmarks"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        localId = try container.decodeIfPresent(UUID.self, forKey: .localId)
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        source = try container.decode(String.self, forKey: .source)
        
        // Safe decoding for isRead
        if let boolVal = try? container.decode(Bool.self, forKey: .isRead) {
            isRead = boolVal
        } else if let intVal = try? container.decode(Int.self, forKey: .isRead) {
            isRead = intVal == 1
        } else if let stringVal = try? container.decode(String.self, forKey: .isRead) {
            isRead = stringVal.lowercased() == "true" || stringVal == "1"
        } else {
            isRead = false
        }
        
        // Safe decoding for isFavorite
        if let boolVal = try? container.decode(Bool.self, forKey: .isFavorite) {
            isFavorite = boolVal
        } else if let intVal = try? container.decode(Int.self, forKey: .isFavorite) {
            isFavorite = intVal == 1
        } else if let stringVal = try? container.decode(String.self, forKey: .isFavorite) {
            isFavorite = stringVal.lowercased() == "true" || stringVal == "1"
        } else {
            isFavorite = false
        }
        
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls)
        fileUrl = try container.decodeIfPresent(String.self, forKey: .fileUrl)
        linkedBookmarkIds = try container.decodeIfPresent([String].self, forKey: .linkedBookmarkIds)
        syncVersion = try container.decode(Int.self, forKey: .syncVersion)
        
        // Safe decoding for isEncrypted
        if let boolVal = try? container.decode(Bool.self, forKey: .isEncrypted) {
            isEncrypted = boolVal
        } else if let intVal = try? container.decode(Int.self, forKey: .isEncrypted) {
            isEncrypted = intVal == 1
        } else if let stringVal = try? container.decode(String.self, forKey: .isEncrypted) {
            isEncrypted = stringVal.lowercased() == "true" || stringVal == "1"
        } else {
            isEncrypted = false
        }
        
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(localId, forKey: .localId)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(source, forKey: .source)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(imageUrls, forKey: .imageUrls)
        try container.encodeIfPresent(fileUrl, forKey: .fileUrl)
        try container.encodeIfPresent(linkedBookmarkIds, forKey: .linkedBookmarkIds)
        try container.encode(syncVersion, forKey: .syncVersion)
        try container.encodeIfPresent(isEncrypted, forKey: .isEncrypted)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct MediaUploadResponse: Codable {
    let url: String
    let diskPath: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case diskPath = "disk_path"
    }
}

struct EmptyResponse: Codable {}

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var email: String?
    var displayName: String
    var isAnonymous: Bool
    var isPro: Bool
    var lastSyncAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case isAnonymous = "is_anonymous"
        case isPro = "is_pro"
        case lastSyncAt = "last_sync_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        displayName = try container.decode(String.self, forKey: .displayName)
        isAnonymous = try container.decodeIfPresent(Bool.self, forKey: .isAnonymous) ?? false
        isPro = try container.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
        
        if let date = try? container.decodeIfPresent(Date.self, forKey: .lastSyncAt) {
            lastSyncAt = date
        } else if let dateString = try? container.decodeIfPresent(String.self, forKey: .lastSyncAt),
                  !dateString.isEmpty {
            let formatter = ISO8601DateFormatter()
            lastSyncAt = formatter.date(from: dateString)
        } else {
            lastSyncAt = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(isAnonymous, forKey: .isAnonymous)
        try container.encode(isPro, forKey: .isPro)
        try container.encodeIfPresent(lastSyncAt, forKey: .lastSyncAt)
    }
}

extension UserProfile {
    var nameForDisplay: String { displayName }
    var initials: String {
        if displayName.hasPrefix("user_") {
            let suffix = displayName.dropFirst(5)
            if let firstChar = suffix.first {
                return "U\(firstChar)"
            }
        }
        return String(displayName.prefix(1)).uppercased()
    }
}
