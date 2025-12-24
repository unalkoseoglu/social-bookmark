//
//  SyncService.swift
//  Social Bookmark
//
//  Merged: Bidirectional sync + Encryption
//

import Foundation
import SwiftData
import Supabase
internal import Combine
import UIKit

// MARK: - Sync State

enum SyncState: Equatable {
    case idle
    case syncing
    case uploading
    case downloading
    case offline
    case error
}

// MARK: - Sync Error

enum SyncError: LocalizedError {
    case notAuthenticated
    case networkError
    case syncFailed(String)
    case downloadFailed(String)
    case conflict

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Oturum açılmamış"
        case .networkError:
            return "Ağ bağlantısı yok"
        case .syncFailed(let message):
            return message
        case .downloadFailed(let message):
            return "İndirme hatası: \(message)"
        case .conflict:
            return "Veri çakışması"
        }
    }
}

// MARK: - Cloud Models

private struct CloudBookmark: Codable {
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

private struct CloudCategory: Codable {
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
}

// MARK: - Sync Service

@MainActor
final class SyncService: ObservableObject {

    static let shared = SyncService()

    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingChangesCount: Int = 0
    @Published private(set) var syncError: SyncError?

    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var modelContext: ModelContext?

    private var autoSyncTimer: Timer?
    private let autoSyncInterval: TimeInterval = 300 // 5 dakika

    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    private init() {
        print("🔄 [SYNC] SyncService initialized")
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("🔄 [SYNC] ModelContext configured")
    }

    // MARK: - Public

    /// Tam senkronizasyon (bidirectional): önce cloud → local, sonra local → cloud
    func performFullSync() async {
        guard canSync() else { return }

        syncState = .syncing
        syncError = nil

        do {
            syncState = .downloading
            try await downloadFromCloud()

            syncState = .uploading
            try await uploadToCloud()

            lastSyncDate = Date()
            syncState = .idle
            NotificationCenter.default.post(name: .syncDidComplete, object: nil)
            print("✅ [SYNC] Full sync completed!")
        } catch {
            print("❌ [SYNC] Error: \(error.localizedDescription)")
            syncError = SyncError.syncFailed(error.localizedDescription)
            syncState = .error
            NotificationCenter.default.post(name: .syncDidFail, object: error)
        }
    }

    func syncChanges() async {
        await performFullSync()
    }

    /// Cloud'dan indir
    func downloadFromCloud() async throws {
        guard let context = modelContext,
              let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }

        try await downloadCategories(context: context, userId: userId)
        try await downloadBookmarks(context: context, userId: userId)

        try context.save()
    }

    /// Local'den cloud'a yükle
    func uploadToCloud() async throws {
        guard let context = modelContext,
              let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }

        try await uploadCategories(context: context, userId: userId)
        try await uploadBookmarks(context: context, userId: userId)
    }

    /// Tek bookmark sync et
    func syncBookmark(_ bookmark: Bookmark) async throws {
        guard let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }

        let existing: [CloudBookmark] = try await client
            .from("bookmarks")
            .select("id, local_id")
            .eq("user_id", value: userId.uuidString)
            .eq("local_id", value: bookmark.id.uuidString)
            .execute()
            .value

        let payload = createBookmarkPayload(bookmark, userId: userId)

        if existing.isEmpty {
            try await client.from("bookmarks").insert(payload).execute()
        } else {
            try await client
                .from("bookmarks")
                .update(payload)
                .eq("user_id", value: userId.uuidString)
                .eq("local_id", value: bookmark.id.uuidString)
                .execute()
        }
    }

    /// Tek kategori sync et
    func syncCategory(_ category: Category) async throws {
        guard let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }

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
        } else {
            try await client
                .from("categories")
                .update(payload)
                .eq("user_id", value: userId.uuidString)
                .eq("local_id", value: category.id.uuidString)
                .execute()
        }
    }

    /// Bookmark sil (cloud)
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

    /// Category sil (cloud)
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

    // MARK: - Auto Sync

    func startAutoSync() {
        stopAutoSync()
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performFullSync()
            }
        }
    }

    func stopAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }

    // MARK: - Download

    private func downloadCategories(context: ModelContext, userId: UUID) async throws {
        let cloudCategories: [CloudCategory] = try await client
            .from("categories")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let localCategories = try context.fetch(FetchDescriptor<Category>())
        let localIdSet = Set(localCategories.map { $0.id.uuidString })

        for cloud in cloudCategories {
            let targetId = cloud.localId ?? cloud.id
            guard !localIdSet.contains(targetId) else { continue }

            let isEnc = (cloud.isEncrypted == true)
            let name = decryptIfNeeded(cloud.name, isEncrypted: isEnc)

            let newCategory = Category(
                id: UUID(uuidString: targetId) ?? UUID(),
                name: name,
                icon: cloud.icon ?? "folder",
                colorHex: cloud.color ?? "#000000",
                order: cloud.order ?? 0
            )

            if let created = ISO8601DateFormatter().date(from: cloud.createdAt) {
                newCategory.createdAt = created
            }

            context.insert(newCategory)
        }
    }

    private func downloadBookmarks(context: ModelContext, userId: UUID) async throws {
        let cloudBookmarks: [CloudBookmark] = try await client
            .from("bookmarks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let localBookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        let localIdSet = Set(localBookmarks.map { $0.id.uuidString })

        for cloud in cloudBookmarks {
            let targetId = cloud.localId ?? cloud.id
            guard !localIdSet.contains(targetId) else { continue }

            let isEnc = (cloud.isEncrypted == true)

            let title = decryptIfNeeded(cloud.title, isEncrypted: isEnc)
            let url = cloud.url.map { decryptIfNeeded($0, isEncrypted: isEnc) }
            let note = cloud.note.map { decryptIfNeeded($0, isEncrypted: isEnc) } ?? ""

            let tags: [String] = (cloud.tags ?? []).map { decryptIfNeeded($0, isEncrypted: isEnc) }

            let source = BookmarkSource(rawValue: cloud.source) ?? .other

            let newBookmark = Bookmark(
                title: title,
                url: url,
                note: note,
                source: source,
                isRead: cloud.isRead,
                isFavorite: cloud.isFavorite,
                tags: tags
            )

            if let uuid = UUID(uuidString: targetId) {
                newBookmark.id = uuid
            }

            if let createdDate = ISO8601DateFormatter().date(from: cloud.createdAt) {
                newBookmark.createdAt = createdDate
            }

            // Eğer image_urls varsa ilkini indirip local'e koy (senin modelinde imageData var diye varsaydım)
            if let firstImageUrl = cloud.imageUrls?.first, !firstImageUrl.isEmpty {
                if let imageData = await downloadImageData(from: firstImageUrl) {
                    newBookmark.imageData = imageData
                }
            }

            // category_id eşlemesi (modelin categoryId tutuyor varsayımı)
            if let categoryId = cloud.categoryId, let uuid = UUID(uuidString: categoryId) {
                newBookmark.categoryId = uuid
            }

            context.insert(newBookmark)
        }
    }

    // MARK: - Upload

    private func uploadCategories(context: ModelContext, userId: UUID) async throws {
        let localCategories = try context.fetch(FetchDescriptor<Category>())

        for category in localCategories {
            let payload = createCategoryPayload(category, userId: userId)
            try await client
                .from("categories")
                .upsert(payload, onConflict: "user_id,local_id")
                .execute()
        }
    }

    private func uploadBookmarks(context: ModelContext, userId: UUID) async throws {
        let localBookmarks = try context.fetch(FetchDescriptor<Bookmark>())

        for bookmark in localBookmarks {
            // İstersen burada resim upload edip image_urls'a koyabilirsin.
            // Senin diğer dosyada ImageUploadService vardı. Projende varsa aç:
            
            var imageUrls: [String] = []
            if let imageData = bookmark.imageData, let image = UIImage(data: imageData) {
                if let uploaded = try? await ImageUploadService.shared.uploadImage(image, for: bookmark.id, index: 0) {
                    imageUrls = [uploaded]
                }
            }
            

            var payload = createBookmarkPayload(bookmark, userId: userId)
            payload["image_urls"] = AnyEncodable(imageUrls)

            // Eğer yukarıdaki image upload aktif edilirse:
            // payload["image_urls"] = AnyEncodable(imageUrls)

            try await client
                .from("bookmarks")
                .upsert(payload, onConflict: "user_id,local_id")
                .execute()
        }
    }

    // MARK: - Helpers

    private func canSync() -> Bool {
        guard modelContext != nil else { return false }
        guard SupabaseManager.shared.isAuthenticated else {
            syncState = .offline
            return false
        }
        guard NetworkMonitor.shared.isConnected else {
            syncState = .offline
            return false
        }
        guard syncState != .syncing else { return false }
        return true
    }

    private func decryptIfNeeded(_ value: String, isEncrypted: Bool) -> String {
        guard isEncrypted else { return value }
        return (try? EncryptionService.shared.decryptOptional(value)) ?? value
    }

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

        // 🔐 Encrypt fields
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
            payload["name"] = AnyEncodable("[Encryption Error]")
            payload["is_encrypted"] = AnyEncodable(false)
        }

        return payload
    }

    private func downloadImageData(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return data
        } catch {
            return nil
        }
    }
}
