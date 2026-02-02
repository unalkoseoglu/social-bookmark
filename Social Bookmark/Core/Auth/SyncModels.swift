import Foundation

/// Response from /sync/delta
struct SyncDeltaResponse: Codable {
    let updatedCategories: [CloudCategory]
    let updatedBookmarks: [CloudBookmark]
    let deletedIds: DeletedIds
    let currentServerTime: String
    
    enum CodingKeys: String, CodingKey {
        case updatedCategories = "updated_categories"
        case updatedBookmarks = "updated_bookmarks"
        case deletedIds = "deleted_ids"
        case currentServerTime = "current_server_time"
    }
}

struct DeletedIds: Codable {
    let categories: [String]
    let bookmarks: [String]
}

struct CloudCategory: Codable {
    let id: String
    let localId: String?
    let name: String
    let icon: String
    let color: String
    let order: Int
    let isEncrypted: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case localId = "local_id"
        case name, icon, color, order
        case isEncrypted = "is_encrypted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CloudBookmark: Codable {
    let id: String
    let localId: String?
    let categoryId: String?
    let title: String
    let url: String?
    let note: String?
    let source: String
    let isRead: Bool
    let isFavorite: Bool
    let tags: [String]?
    let imageUrls: [String]?
    let fileURL: String?
    let fileName: String?
    let fileExtension: String?
    let fileSize: Int64?
    let isEncrypted: Bool?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case localId = "local_id"
        case categoryId = "category_id"
        case title, url, note, source
        case isRead = "is_read"
        case isFavorite = "is_favorite"
        case tags
        case imageUrls = "image_urls"
        case fileURL = "file_url"
        case fileName = "file_name"
        case fileExtension = "file_extension"
        case fileSize = "file_size"
        case isEncrypted = "is_encrypted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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

struct UserProfile: Codable {
    let id: UUID
    var email: String?
    var fullName: String?
    var displayName: String
    var isAnonymous: Bool
    var isPro: Bool                // Added for Laravel API
    let createdAt: Date
    var avatarUrl: String?
    var lastSyncAt: Date?
    var deviceId: String?
    var appVersion: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case displayName = "display_name"
        case isAnonymous = "is_anonymous"
        case isPro = "is_pro"
        case createdAt = "created_at"
        case avatarUrl = "avatar_url"
        case lastSyncAt = "last_sync_at"
        case deviceId = "device_id"
        case appVersion = "app_version"
    }
    
    init(
        id: UUID,
        email: String? = nil,
        fullName: String? = nil,
        displayName: String,
        isAnonymous: Bool,
        isPro: Bool = false,
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
        self.isPro = isPro
        self.createdAt = createdAt
        self.avatarUrl = avatarUrl
        self.lastSyncAt = lastSyncAt
        self.deviceId = deviceId
        self.appVersion = appVersion
    }
}

extension UserProfile {
    var nameForDisplay: String {
        if let fullName = fullName, !fullName.isEmpty {
            return fullName
        }
        return displayName
    }
    
    var initials: String {
        if let fullName = fullName, !fullName.isEmpty {
            let components = fullName.components(separatedBy: " ")
            let initials = components.compactMap { $0.first }.prefix(2)
            return String(initials).uppercased()
        }
        
        if displayName.hasPrefix("user_") {
            let suffix = displayName.dropFirst(5)
            if let firstChar = suffix.first {
                return "U\(firstChar)"
            }
        }
        
        return String(displayName.prefix(1)).uppercased()
    }
}
