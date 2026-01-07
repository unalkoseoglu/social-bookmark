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
import OSLog

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
    let userId: String?
    let localId: String?
    let name: String?
    let icon: String?
    let color: String?
    let order: Int?
    let isEncrypted: Bool?
    let createdAt: String?
    let updatedAt: String?

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
        Logger.sync.info("SyncService initialized")
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        Logger.sync.info("ModelContext configured")
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
            Logger.sync.info("Full sync completed!")
        } catch {
            Logger.sync.error("Sync error: \(error.localizedDescription)")
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
        print("🔄 [SYNC] Downloading from cloud for user: \(userId.uuidString)")

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
            print("❌ [SYNC] syncBookmark: Not authenticated")
            throw SyncError.notAuthenticated
        }

        print("🔄 [SYNC] syncBookmark START")
        print("   - Title: \(bookmark.title)")
        print("   - ID: \(bookmark.id)")

        // 🔑 Category'nin cloud ID'sini bul
        var cloudCategoryId: String? = nil
        if let localCategoryId = bookmark.categoryId {
            let catResponse: [CloudCategory] = try await client
                .from("categories")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("local_id", value: localCategoryId.uuidString)
                .execute()
                .value
            
            cloudCategoryId = catResponse.first?.id
        }

        // Mevcut kayıt var mı kontrol et
        let countResponse = try await client
            .from("bookmarks")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .eq("local_id", value: bookmark.id.uuidString)
            .execute()
        
        let existingCount = countResponse.count ?? 0
        print("📋 [SYNC] Existing count: \(existingCount)")

        var payload = createBookmarkPayload(bookmark, userId: userId)
        
        // 🖼️ Image upload
        var imageUrls: [String] = []
        if let imageData = bookmark.imageData, let image = UIImage(data: imageData) {
            do {
                let uploaded = try await ImageUploadService.shared.uploadImage(image, for: bookmark.id, index: 0)
                imageUrls.append(uploaded)
                print("📤 [SYNC] Uploaded image: \(uploaded)")
            } catch {
                print("❌ [SYNC] Image upload failed: \(error)")
            }
        }
        
        // ✅ image_urls ekle
        if !imageUrls.isEmpty {
            payload["image_urls"] = AnyEncodable(imageUrls)
        }
        
        // 🔑 Cloud category ID'yi kullan
        if let cloudId = cloudCategoryId {
            payload["category_id"] = AnyEncodable(cloudId)
        } else {
            payload["category_id"] = AnyEncodable(nil as String?)
        }

        if existingCount == 0 {
            print("➕ [SYNC] INSERT bookmark")
            try await client.from("bookmarks").insert(payload).execute()
        } else {
            print("🔄 [SYNC] UPDATE bookmark")
            try await client
                .from("bookmarks")
                .update(payload)
                .eq("user_id", value: userId.uuidString)
                .eq("local_id", value: bookmark.id.uuidString)
                .execute()
        }
        print("✅ [SYNC] Bookmark sync done")
    }

    func syncCategory(_ category: Category) async throws {
        guard let userId = SupabaseManager.shared.userId else {
            print("❌ [SYNC] syncCategory: Not authenticated")
            throw SyncError.notAuthenticated
        }

        print("🔄 [SYNC] syncCategory: \(category.name), icon=\(category.icon), color=\(category.colorHex)")

        // Mevcut kayıt var mı kontrol et - sadece count al
        let countResponse = try await client
            .from("categories")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .eq("local_id", value: category.id.uuidString)
            .execute()
        
        let existingCount = countResponse.count ?? 0
        print("📋 [SYNC] Existing count: \(existingCount)")

        // ✅ createCategoryPayload kullan - şifreleme ile
        var payload = createCategoryPayload(category, userId: userId)

        if existingCount == 0 {
            print("➕ [SYNC] INSERT")
            try await client.from("categories").insert(payload).execute()
        } else {
            print("🔄 [SYNC] UPDATE")
            try await client
                .from("categories")
                .update(payload)
                .eq("user_id", value: userId.uuidString)
                .eq("local_id", value: category.id.uuidString)
                .execute()
        }
        print("✅ [SYNC] Done")
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
            guard let targetUUID = UUID(uuidString: targetId) else { continue }
            if localIdSet.contains(targetId) || localIdSet.contains(cloud.id) || localIdSet.contains(targetUUID.uuidString) {
                continue
            }

            let isEnc = (cloud.isEncrypted == true)
            let name = decryptIfNeeded(cloud.name ?? "Unnamed", isEncrypted: isEnc)

            let newCategory = Category(
                id: UUID(uuidString: targetId) ?? UUID(),
                name: name,
                icon: cloud.icon ?? "folder",
                colorHex: cloud.color ?? "#000000",
                order: cloud.order ?? 0
            )

            if let createdAt = cloud.createdAt, let created = ISO8601DateFormatter().date(from: createdAt) {
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
        
        // Local bookmark'ları ID'ye göre map'le
        var localBookmarkMap: [String: Bookmark] = [:]
        for bookmark in localBookmarks {
            localBookmarkMap[bookmark.id.uuidString] = bookmark
        }
        
        // Cloud category ID → local ID mapping
        let cloudCategories: [CloudCategory] = try await client
            .from("categories")
            .select("id, local_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        var cloudToLocalCategoryMap: [String: String] = [:]
        for cat in cloudCategories {
            if let localId = cat.localId {
                cloudToLocalCategoryMap[cat.id] = localId
            }
        }
        
        for cloud in cloudBookmarks {
            let targetId = cloud.localId ?? cloud.id
            guard let targetUUID = UUID(uuidString: targetId) else { continue }
            
            // ✅ DÜZELTME: Mevcut bookmark varsa güncelle, yoksa oluştur
            if let existingBookmark = localBookmarkMap[targetUUID.uuidString] {
                print("🔄 [DOWNLOAD] Updating existing bookmark: \(cloud.title)")
                
                // Title, note, tags vs. güncelle
                let isEnc = (cloud.isEncrypted == true)
                existingBookmark.title = decryptIfNeeded(cloud.title, isEncrypted: isEnc)
                existingBookmark.url = cloud.url.map { decryptIfNeeded($0, isEncrypted: isEnc) }
                existingBookmark.note = cloud.note.map { decryptIfNeeded($0, isEncrypted: isEnc) } ?? ""
                existingBookmark.tags = (cloud.tags ?? []).map { decryptIfNeeded($0, isEncrypted: isEnc) }
                existingBookmark.isRead = cloud.isRead
                existingBookmark.isFavorite = cloud.isFavorite
                
                // 🖼️ Resimleri güncelle
                if let imageUrls = cloud.imageUrls, !imageUrls.isEmpty {
                    print("🖼️ [DOWNLOAD] Found \(imageUrls.count) images for existing bookmark")
                    
                    // İlk resmi indir
                    if let firstImagePath = imageUrls.first {
                        print("   📥 Downloading image from: \(firstImagePath)")
                        
                        if let image = await ImageUploadService.shared.loadImage(from: firstImagePath) {
                            if let imageData = image.jpegData(compressionQuality: 0.8) {
                                existingBookmark.imageData = imageData
                                print("   ✅ Image downloaded and saved")
                            }
                        } else {
                            print("   ❌ Failed to download image")
                        }
                    }
                    
                    existingBookmark.imageUrls = imageUrls
                }
                
                // Category güncelle
                if let cloudCategoryId = cloud.categoryId,
                   let localCategoryId = cloudToLocalCategoryMap[cloudCategoryId],
                   let uuid = UUID(uuidString: localCategoryId) {
                    existingBookmark.categoryId = uuid
                }
                
                continue  // Next bookmark
            }
            
            // ✅ YENİ BOOKMARK OLUŞTUR
            print("➕ [DOWNLOAD] Creating new bookmark: \(cloud.title)")
            
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

            newBookmark.id = targetUUID

            if let createdDate = ISO8601DateFormatter().date(from: cloud.createdAt) {
                newBookmark.createdAt = createdDate
            }

            // 🖼️ Resimleri indir
            if let imageUrls = cloud.imageUrls, !imageUrls.isEmpty {
                print("🖼️ [DOWNLOAD] Found \(imageUrls.count) images for new bookmark")
                
                if let firstImagePath = imageUrls.first {
                    print("   📥 Downloading image from: \(firstImagePath)")
                    
                    if let image = await ImageUploadService.shared.loadImage(from: firstImagePath) {
                        if let imageData = image.jpegData(compressionQuality: 0.8) {
                            newBookmark.imageData = imageData
                            print("   ✅ Image downloaded and saved")
                        }
                    } else {
                        print("   ❌ Failed to download image")
                    }
                }
                
                newBookmark.imageUrls = imageUrls
            }

            // Category mapping
            if let cloudCategoryId = cloud.categoryId,
               let localCategoryId = cloudToLocalCategoryMap[cloudCategoryId],
               let uuid = UUID(uuidString: localCategoryId) {
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
        
        // Önce tüm kategorilerin local_id → cloud_id mapping'ini al
        let cloudCategories: [CloudCategory] = try await client
            .from("categories")
            .select("id, local_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        // local_id → cloud_id map oluştur
        var categoryIdMap: [String: String] = [:]
        for cat in cloudCategories {
            if let localId = cat.localId {
                categoryIdMap[localId] = cat.id
            }
        }
        
        Logger.sync.info("📦 Category ID map created with \(categoryIdMap.count) entries")

        for bookmark in localBookmarks {
            // ✅ DÜZELTME: Önce payload oluştur, sonra image_urls ekle
            var payload = createBookmarkPayload(bookmark, userId: userId)
            
            // 🖼️ Image upload
            var imageUrls: [String] = []
            
            // Tek resim varsa (imageData)
            if let imageData = bookmark.imageData, let image = UIImage(data: imageData) {
                do {
                    let uploaded = try await ImageUploadService.shared.uploadImage(image, for: bookmark.id, index: 0)
                    imageUrls.append(uploaded)
                    print("📤 [SYNC] Uploaded image: \(uploaded)")
                } catch {
                    print("❌ [SYNC] Image upload failed: \(error)")
                }
            }
            
            // Çoklu resimler varsa (imagesData) - BONUS
            if let imagesData = bookmark.imagesData {
                for (index, imageData) in imagesData.enumerated() {
                    if let image = UIImage(data: imageData) {
                        do {
                            let uploaded = try await ImageUploadService.shared.uploadImage(image, for: bookmark.id, index: index)
                            imageUrls.append(uploaded)
                            print("📤 [SYNC] Uploaded image \(index): \(uploaded)")
                        } catch {
                            print("❌ [SYNC] Image \(index) upload failed: \(error)")
                        }
                    }
                }
            }
            
            // ✅ DÜZELTME: image_urls'i payload'a ekle (override değil!)
            if !imageUrls.isEmpty {
                payload["image_urls"] = AnyEncodable(imageUrls)
                print("✅ [SYNC] Added \(imageUrls.count) image URLs to payload")
            }
            
            // 🔑 Category ID'yi cloud ID ile değiştir
            if let localCategoryId = bookmark.categoryId?.uuidString,
               let cloudCategoryId = categoryIdMap[localCategoryId] {
                payload["category_id"] = AnyEncodable(cloudCategoryId)
                Logger.sync.debug("🔗 Mapped category \(localCategoryId) → \(cloudCategoryId)")
            } else {
                payload["category_id"] = AnyEncodable(nil as String?)
            }

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

            // ✅ DÜZELTME: image_urls'i burada SET ETME!
            // Caller (uploadBookmarks) set edecek

        } catch {
            payload["title"] = AnyEncodable("[Encryption Error]")
            payload["url"] = AnyEncodable("")
            payload["note"] = AnyEncodable("")
            payload["tags"] = AnyEncodable([String]())
            payload["is_encrypted"] = AnyEncodable(false)
        }

        // Not: category_id ve image_urls caller tarafından eklenir

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
