struct UserProfile: Codable {
    let id: UUID
    let email: String?
    let fullName: String?
    let isAnonymous: Bool
    let createdAt: Date
    var avatarUrl: String?
    var lastSyncAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case isAnonymous = "is_anonymous"
        case createdAt = "created_at"
        case avatarUrl = "avatar_url"
        case lastSyncAt = "last_sync_at"
    }
}

// MARK: - User Extension

extension User {
    /// Kullanıcı anonim mi?
    var isAnonymous: Bool {
        // Anonim kullanıcıların email'i olmaz
        email == nil && identities?.isEmpty != false
    }
    
    /// Display name
    var displayName: String {
        if let fullName = userMetadata["full_name"]?.stringValue, !fullName.isEmpty {
            return fullName
        }
        if let email {
            return email.components(separatedBy: "@").first ?? email
        }
        return "Anonim Kullanıcı"
    }
}

// MARK: - AnyJSON Helper

extension AnyJSON {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
}