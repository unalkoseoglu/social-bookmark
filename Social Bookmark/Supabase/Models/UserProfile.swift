//
//  UserProfile.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//

import Foundation


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

