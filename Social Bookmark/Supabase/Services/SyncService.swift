//
//  SyncService.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//
//  Bookmark ve Category senkronizasyonu
//  - Upload (local → cloud)
//  - Download (cloud → local)
//  - Duplicate prevention
//

import Foundation
import SwiftData
import Supabase
internal import Combine
import UIKit

/// Senkronizasyon servisi
@MainActor
final class SyncService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SyncService()
    
    // MARK: - Published Properties
    
    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingChangesCount: Int = 0
    @Published private(set) var syncError: SyncError?
    
    // MARK: - Dependencies
    
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var modelContext: ModelContext?
    
    // MARK: - Private Properties
    
    private var autoSyncTimer: Timer?
    private let autoSyncInterval: TimeInterval = 300 // 5 dakika
    
    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
    
    // MARK: - Initialization
    
    private init() {
        print("🔄 [SYNC] SyncService initialized")
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("🔄 [SYNC] ModelContext configured")
    }
    
    // MARK: - Public Methods
    
    /// Tam senkronizasyon yap
    func performFullSync() async {
        guard canSync() else { return }
        
        syncState = .syncing
        syncError = nil
        
        print("🔄 ═══════════════════════════════════════")
        print("🔄 [SYNC] Starting full sync...")
        print("🔄 ═══════════════════════════════════════")
        
        do {
            // 1. Kategorileri sync et
            try await syncCategories()
            
            // 2. Bookmark'ları sync et
            try await syncBookmarks()
            
            // 3. Başarılı
            lastSyncDate = Date()
            syncState = .idle
            
            print("✅ [SYNC] Full sync completed!")
            NotificationCenter.default.post(name: .syncDidComplete, object: nil)
            
        } catch {
            print("❌ [SYNC] Error: \(error.localizedDescription)")
            syncError = SyncError.syncFailed(error.localizedDescription)
            syncState = .error
        }
    }
    
    /// Değişiklikleri sync et (incremental)
    func syncChanges() async {
        await performFullSync()
    }
    
    /// Tek bookmark sync et
    func syncBookmark(_ bookmark: Bookmark) async throws {
        guard let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }
        
        // Cloud'da var mı kontrol et
        let existing: [CloudBookmark] = try await client
            .from("bookmarks")
            .select("id, local_id")
            .eq("user_id", value: userId.uuidString)
            .eq("local_id", value: bookmark.id.uuidString)
            .execute()
            .value
        
        let payload = createBookmarkPayload(bookmark, userId: userId)
        
        if existing.isEmpty {
            // Yeni - INSERT
            try await client.from("bookmarks").insert(payload).execute()
            print("✅ [SYNC] Inserted bookmark: \(bookmark.title)")
        } else {
            // Mevcut - UPDATE
            try await client
                .from("bookmarks")
                .update(payload)
                .eq("user_id", value: userId.uuidString)
                .eq("local_id", value: bookmark.id.uuidString)
                .execute()
            print("✅ [SYNC] Updated bookmark: \(bookmark.title)")
        }
    }
    
    /// Tek kategori sync et
    func syncCategory(_ category: Category) async throws {
        guard let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }
        
        // Cloud'da var mı kontrol et
        let existing: [CloudCategory] = try await client
            .from("categories")
            .select("id, local_id")
            .eq("user_id", value: userId.uuidString)
            .eq("local_id", value: category.id.uuidString)
            .execute()
            .value
        
        let payload = createCategoryPayload(category, userId: userId)
        
        if existing.isEmpty {
            try await client.from("categories").insert(payload).execute()
            print("✅ [SYNC] Inserted category: \(category.name)")
        } else {
            try await client
                .from("categories")
                .update(payload)
                .eq("user_id", value: userId.uuidString)
                .eq("local_id", value: category.id.uuidString)
                .execute()
            print("✅ [SYNC] Updated category: \(category.name)")
        }
    }
    
    /// Bookmark sil
    func deleteBookmark(_ bookmark: Bookmark) async throws {
        guard let userId = SupabaseManager.shared.userId else { return }
        
        try await client
            .from("bookmarks")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("local_id", value: bookmark.id.uuidString)
            .execute()
        
        print("🗑️ [SYNC] Deleted bookmark from cloud")
    }
    
    /// Kategori sil
    func deleteCategory(_ category: Category) async throws {
        guard let userId = SupabaseManager.shared.userId else { return }
        
        try await client
            .from("categories")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("local_id", value: category.id.uuidString)
            .execute()
        
        print("🗑️ [SYNC] Deleted category from cloud")
    }
    
    /// Auto-sync başlat
    func startAutoSync() {
        stopAutoSync()
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performFullSync()
            }
        }
        print("🔄 [SYNC] Auto-sync started")
    }
    
    /// Auto-sync durdur
    func stopAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }
    
    // MARK: - Private Sync Methods
    
    private func syncCategories() async throws {
        guard let context = modelContext,
              let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }
        
        print("📁 [SYNC] Syncing categories...")
        
        // 1. Local kategorileri al
        let localCategories = try context.fetch(FetchDescriptor<Category>())
        
        // 2. Cloud'daki TÜM kayıtları al
        let cloudCategories: [CloudCategory] = try await client
            .from("categories")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        // 3. Cloud'da olan local_id'leri set olarak tut
        var cloudLocalIdSet = Set<String>()
        for cloud in cloudCategories {
            if let localId = cloud.localId, !localId.isEmpty {
                cloudLocalIdSet.insert(localId)
                print("   ☁️ Cloud has: \(localId)")
            }
        }
        
        print("   Local: \(localCategories.count), Cloud: \(cloudLocalIdSet.count)")
        
        // 4. SADECE cloud'da olmayan kategorileri yükle
        var uploadCount = 0
        for category in localCategories {
            let localIdString = category.id.uuidString
            print("   🔍 Checking local: \(localIdString) - \(category.name)")
            
            if cloudLocalIdSet.contains(localIdString) {
                print("      ⏭️ Already in cloud, skipping")
                continue
            }
            
            // Cloud'da yok, INSERT
            print("      📤 Not in cloud, uploading...")
            let payload = createCategoryPayload(category, userId: userId)
            try await client.from("categories").insert(payload).execute()
            uploadCount += 1
            print("      ✅ Uploaded: \(category.name)")
        }
        
        if uploadCount == 0 {
            print("   ✓ All categories already in cloud")
        } else {
            print("   📤 Uploaded \(uploadCount) new categories")
        }
    }
    
    private func syncBookmarks() async throws {
        guard let context = modelContext,
              let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }
        
        print("🔖 [SYNC] Syncing bookmarks...")
        
        // 1. Local bookmark'ları al
        let localBookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        
        // 2. Cloud'daki TÜM local_id'leri al
        let cloudBookmarks: [CloudBookmark] = try await client
            .from("bookmarks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        // 3. Cloud'da olan local_id'leri set olarak tut
        var cloudLocalIdSet = Set<String>()
        for cloud in cloudBookmarks {
            if let localId = cloud.localId, !localId.isEmpty {
                cloudLocalIdSet.insert(localId)
            }
        }
        
        print("   Local: \(localBookmarks.count), Cloud: \(cloudLocalIdSet.count)")
        
        // 4. SADECE cloud'da olmayan bookmark'ları yükle
        var uploadCount = 0
        for bookmark in localBookmarks {
            let localIdString = bookmark.id.uuidString
            
            if !cloudLocalIdSet.contains(localIdString) {
                // Cloud'da yok, INSERT
                let payload = createBookmarkPayload(bookmark, userId: userId)
                try await client.from("bookmarks").insert(payload).execute()
                uploadCount += 1
                print("   📤 Uploaded: \(bookmark.title)")
            }
        }
        
        if uploadCount == 0 {
            print("   ✓ All bookmarks already in cloud")
        } else {
            print("   📤 Uploaded \(uploadCount) new bookmarks")
        }
    }
    
    // MARK: - Helpers
    
    private func canSync() -> Bool {
        guard modelContext != nil else {
            print("⚠️ [SYNC] ModelContext not configured")
            return false
        }
        
        guard SupabaseManager.shared.isAuthenticated else {
            print("⚠️ [SYNC] Not authenticated")
            syncState = .offline
            return false
        }
        
        guard NetworkMonitor.shared.isConnected else {
            print("⚠️ [SYNC] No network connection")
            syncState = .offline
            return false
        }
        
        guard syncState != .syncing else {
            print("⚠️ [SYNC] Already syncing")
            return false
        }
        
        return true
    }
    
    // MARK: - Payload Creators
    
    private func createBookmarkPayload(_ bookmark: Bookmark, userId: UUID) -> [String: AnyEncodable] {
        var payload: [String: AnyEncodable] = [
            "user_id": AnyEncodable(userId.uuidString),
            "local_id": AnyEncodable(bookmark.id.uuidString),
            "source": AnyEncodable(bookmark.source.rawValue),
            "is_read": AnyEncodable(bookmark.isRead),
            "is_favorite": AnyEncodable(bookmark.isFavorite),
            "created_at": AnyEncodable(ISO8601DateFormatter().string(from: bookmark.createdAt)),
            "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: Date())),
            "sync_version": AnyEncodable(1),
            "is_encrypted": AnyEncodable(true)
        ]
        
        // 🔐 Hassas alanları şifrele
        do {
            let encryption = EncryptionService.shared
            
            payload["title"] = AnyEncodable(try encryption.encrypt(bookmark.title).ciphertext)
            
            if let url = bookmark.url, !url.isEmpty {
                payload["url"] = AnyEncodable(try encryption.encrypt(url).ciphertext)
            } else {
                payload["url"] = AnyEncodable("")
            }
            
            if !bookmark.note.isEmpty {
                payload["note"] = AnyEncodable(try encryption.encrypt(bookmark.note).ciphertext)
            } else {
                payload["note"] = AnyEncodable("")
            }
            
            if !bookmark.tags.isEmpty {
                let encryptedTags = try bookmark.tags.map { try encryption.encrypt($0).ciphertext }
                payload["tags"] = AnyEncodable(encryptedTags)
            } else {
                payload["tags"] = AnyEncodable([String]())
            }
            
            payload["image_urls"] = AnyEncodable([String]())
            
        } catch {
            print("❌ [SYNC] Encryption failed: \(error)")
            payload["title"] = AnyEncodable("[Encryption Error]")
            payload["url"] = AnyEncodable("")
            payload["note"] = AnyEncodable("")
            payload["tags"] = AnyEncodable([String]())
            payload["image_urls"] = AnyEncodable([String]())
            payload["is_encrypted"] = AnyEncodable(false)
        }
        
        if let categoryId = bookmark.categoryId {
            payload["category_id"] = AnyEncodable(categoryId.uuidString)
        }
        
        return payload
    }
    
    private func createCategoryPayload(_ category: Category, userId: UUID) -> [String: AnyEncodable] {
        var payload: [String: AnyEncodable] = [
            "user_id": AnyEncodable(userId.uuidString),
            "local_id": AnyEncodable(category.id.uuidString),
            "icon": AnyEncodable(category.icon),
            "color": AnyEncodable(category.colorHex),
            "order": AnyEncodable(category.order),
            "created_at": AnyEncodable(ISO8601DateFormatter().string(from: category.createdAt)),
            "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: Date())),
            "sync_version": AnyEncodable(1),
            "is_encrypted": AnyEncodable(true)
        ]
        
        do {
            payload["name"] = AnyEncodable(try EncryptionService.shared.encrypt(category.name).ciphertext)
        } catch {
            print("❌ [SYNC] Category encryption failed: \(error)")
            payload["name"] = AnyEncodable("[Encryption Error]")
            payload["is_encrypted"] = AnyEncodable(false)
        }
        
        return payload
    }
}

// MARK: - Types

enum SyncState: Equatable {
    case idle
    case syncing
    case uploading
    case downloading
    case offline
    case error
}

enum SyncError: LocalizedError {
    case notAuthenticated
    case networkError
    case syncFailed(String)
    case conflict
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Oturum açılmamış"
        case .networkError:
            return "Ağ bağlantısı yok"
        case .syncFailed(let message):
            return message
        case .conflict:
            return "Veri çakışması"
        }
    }
}

// MARK: - Cloud Models

struct CloudBookmark: Codable {
    let id: String
    let userId: String
    let localId: String?
    let title: String
    let url: String?
    let note: String?
    let source: String
    let isRead: Bool
    let isFavorite: Bool
    let categoryId: String?
    let tags: [String]?
    let imageUrls: [String]?
    let isEncrypted: Bool?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case localId = "local_id"
        case title, url, note, source
        case isRead = "is_read"
        case isFavorite = "is_favorite"
        case categoryId = "category_id"
        case tags
        case imageUrls = "image_urls"
        case isEncrypted = "is_encrypted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CloudCategory: Codable {
    let id: String
    let userId: String
    let localId: String?
    let name: String
    let icon: String?
    let color: String?
    let order: Int?
    let isEncrypted: Bool?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case localId = "local_id"
        case name, icon, color, order
        case isEncrypted = "is_encrypted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    @MainActor func decryptedName() -> String {
        guard isEncrypted == true else { return name }
        return (try? EncryptionService.shared.decryptOptional(name)) ?? name
    }
}



// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
