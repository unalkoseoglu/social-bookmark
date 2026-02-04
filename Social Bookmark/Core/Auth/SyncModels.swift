import Foundation

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
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, color, order
        case localId = "local_id"
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
    
    enum CodingKeys: String, CodingKey {
        case id, title, url, note, source, tags
        case localId = "local_id"
        case categoryId = "category_id"
        case isRead = "is_read"
        case isFavorite = "is_favorite"
        case imageUrls = "image_urls"
        case fileUrl = "file_url"
        case syncVersion = "sync_version"
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
        // Handle null values by defaulting to false
        isAnonymous = try container.decodeIfPresent(Bool.self, forKey: .isAnonymous) ?? false
        isPro = try container.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
        
        // Gracefully handle date decoding - try Date first, then String fallback
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
}


extension UserProfile {
    var nameForDisplay: String {
        return displayName
    }
    
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
