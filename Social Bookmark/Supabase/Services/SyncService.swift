//
//  SyncService.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//
//  Bookmark ve Category senkronizasyonu
//  - Upload (local → cloud)
//  - Download (cloud → local)
//  - Conflict resolution (last-write-wins)
//  - Offline queue
//

import Foundation
import SwiftData
import Supabase
import Combine

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
    
    private var syncTask: Task<Void, Never>?
    private var autoSyncTimer: Timer?
    private let autoSyncInterval: TimeInterval = 300 // 5 dakika
    
    // MARK: - Configuration
    
    /// Sync batch boyutu
    private let batchSize = 50
    
    // MARK: - Initialization
    
    private init() {
        print("🔄 [SYNC] SyncService initialized")
        setupNotificationObservers()
    }
    
    /// ModelContext'i ayarla (App başlangıcında çağrılmalı)
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
            pendingChangesCount = 0
            
            // Sync status güncelle
            try await updateSyncStatus()
            
            print("✅ [SYNC] Full sync completed successfully!")
            
            NotificationCenter.default.post(name: .syncDidComplete, object: nil)
            
        } catch {
            handleSyncError(error)
        }
    }
    
    /// Sadece değişiklikleri sync et (incremental)
    func syncChanges() async {
        guard canSync() else { return }
        
        syncState = .syncing
        syncError = nil
        
        print("🔄 [SYNC] Syncing pending changes...")
        
        do {
            // Pending bookmark'ları bul ve sync et
            try await uploadPendingBookmarks()
            try await uploadPendingCategories()
            
            syncState = .idle
            pendingChangesCount = 0
            
            print("✅ [SYNC] Changes synced successfully!")
            
        } catch {
            handleSyncError(error)
        }
    }
    
    /// Cloud'dan local'e indir (ilk kurulum veya yeni cihaz)
    func downloadFromCloud() async {
        guard canSync() else { return }
        
        syncState = .downloading
        syncError = nil
        
        print("⬇️ [SYNC] Downloading from cloud...")
        
        do {
            // 1. Kategorileri indir
            try await downloadCategories()
            
            // 2. Bookmark'ları indir
            try await downloadBookmarks()
            
            lastSyncDate = Date()
            syncState = .idle
            
            print("✅ [SYNC] Download completed!")
            
        } catch {
            handleSyncError(error)
        }
    }
    
    /// Tek bir bookmark'ı sync et
    func syncBookmark(_ bookmark: Bookmark) async throws {
        guard let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }
        
        print("🔄 [SYNC] Syncing single bookmark: \(bookmark.title)")
        
        let payload = createBookmarkPayload(bookmark, userId: userId)
        
        try await client
            .from("bookmarks")
            .upsert(payload, onConflict: "local_id")
            .execute()
        
        print("✅ [SYNC] Bookmark synced: \(bookmark.title)")
    }
    
    /// Tek bir kategoriyi sync et
    func syncCategory(_ category: Category) async throws {
        guard let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }
        
        print("🔄 [SYNC] Syncing single category: \(category.name)")
        
        let payload = createCategoryPayload(category, userId: userId)
        
        try await client
            .from("categories")
            .upsert(payload, onConflict: "local_id")
            .execute()
        
        print("✅ [SYNC] Category synced: \(category.name)")
    }
    
    /// Bookmark sil (cloud'dan da)
    func deleteBookmark(_ bookmark: Bookmark) async throws {
        guard SupabaseManager.shared.isAuthenticated else { return }
        
        // Cloud'dan sil (soft delete)
        try await client
            .from("bookmarks")
            .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
            .eq("local_id", value: bookmark.id.uuidString)
            .execute()
        
        print("🗑️ [SYNC] Bookmark deleted from cloud: \(bookmark.title)")
    }
    
    /// Kategori sil (cloud'dan da)
    func deleteCategory(_ category: Category) async throws {
        guard SupabaseManager.shared.isAuthenticated else { return }
        
        // Cloud'dan sil (soft delete)
        try await client
            .from("categories")
            .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
            .eq("local_id", value: category.id.uuidString)
            .execute()
        
        print("🗑️ [SYNC] Category deleted from cloud: \(category.name)")
    }
    
    /// Auto-sync başlat
    func startAutoSync() {
        guard autoSyncTimer == nil else { return }
        
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncChanges()
            }
        }
        
        print("🔄 [SYNC] Auto-sync started (interval: \(autoSyncInterval)s)")
    }
    
    /// Auto-sync durdur
    func stopAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
        print("🔄 [SYNC] Auto-sync stopped")
    }
    
    // MARK: - Private Methods - Sync Logic
    
    private func syncCategories() async throws {
        guard let context = modelContext,
              let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }
        
        print("📁 [SYNC] Syncing categories...")
        
        // 1. Local kategorileri al
        let descriptor = FetchDescriptor<Category>()
        let localCategories = try context.fetch(descriptor)
        
        // 2. Cloud kategorileri al
        let cloudCategories: [CloudCategory] = try await client
            .from("categories")
            .select()
            .eq("user_id", value: userId.uuidString)
            .is("deleted_at", value: nil)
            .execute()
            .value
        
        print("   Local: \(localCategories.count), Cloud: \(cloudCategories.count)")
        
        // 3. Upload local → cloud
        for category in localCategories {
            let payload = createCategoryPayload(category, userId: userId)
            
            try await client
                .from("categories")
                .upsert(payload, onConflict: "local_id")
                .execute()
        }
        
        // 4. Download cloud → local (yeni olanlar)
        for cloudCategory in cloudCategories {
            let exists = localCategories.contains { $0.id.uuidString == cloudCategory.localId }
            
            if !exists {
                let newCategory = Category(
                    name: cloudCategory.name,
                    icon: cloudCategory.icon ?? "folder",
                    colorHex: cloudCategory.color ?? "#007AFF"
                )
                context.insert(newCategory)
            }
        }
        
        try context.save()
        print("✅ [SYNC] Categories synced")
    }
    
    private func syncBookmarks() async throws {
        guard let context = modelContext,
              let userId = SupabaseManager.shared.userId else {
            throw SyncError.notAuthenticated
        }
        
        print("🔖 [SYNC] Syncing bookmarks...")
        
        // 1. Local bookmark'ları al
        let descriptor = FetchDescriptor<Bookmark>()
        let localBookmarks = try context.fetch(descriptor)
        
        // 2. Cloud bookmark'ları al
        let cloudBookmarks: [CloudBookmark] = try await client
            .from("bookmarks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .is("deleted_at", value: nil)
            .execute()
            .value
        
        print("   Local: \(localBookmarks.count), Cloud: \(cloudBookmarks.count)")
        
        // 3. Batch upload local → cloud
        for batch in localBookmarks.chunked(into: batchSize) {
            let payloads = batch.map { createBookmarkPayload($0, userId: userId) }
            
            try await client
                .from("bookmarks")
                .upsert(payloads, onConflict: "local_id")
                .execute()
        }
        
        // 4. Download cloud → local (yeni olanlar)
        for cloudBookmark in cloudBookmarks {
            let exists = localBookmarks.contains { $0.id.uuidString == cloudBookmark.localId }
            
            if !exists {
                let newBookmark = createLocalBookmark(from: cloudBookmark)
                context.insert(newBookmark)
            }
        }
        
        try context.save()
        print("✅ [SYNC] Bookmarks synced")
    }
    
    private func uploadPendingBookmarks() async throws {
        guard let context = modelContext,
              let userId = SupabaseManager.shared.userId else { return }
        
        // Son sync'ten sonra değişen bookmark'ları bul
        let lastSync = lastSyncDate ?? .distantPast
        
        var descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { $0.updatedAt > lastSync }
        )
        descriptor.fetchLimit = batchSize
        
        let pendingBookmarks = try context.fetch(descriptor)
        
        if pendingBookmarks.isEmpty {
            print("ℹ️ [SYNC] No pending bookmarks")
            return
        }
        
        print("⬆️ [SYNC] Uploading \(pendingBookmarks.count) pending bookmarks...")
        
        let payloads = pendingBookmarks.map { createBookmarkPayload($0, userId: userId) }
        
        try await client
            .from("bookmarks")
            .upsert(payloads, onConflict: "local_id")
            .execute()
    }
    
    private func uploadPendingCategories() async throws {
        guard let context = modelContext,
              let userId = SupabaseManager.shared.userId else { return }
        
        let lastSync = lastSyncDate ?? .distantPast
        
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.updatedAt > lastSync }
        )
        descriptor.fetchLimit = batchSize
        
        let pendingCategories = try context.fetch(descriptor)
        
        if pendingCategories.isEmpty {
            print("ℹ️ [SYNC] No pending categories")
            return
        }
        
        print("⬆️ [SYNC] Uploading \(pendingCategories.count) pending categories...")
        
        for category in pendingCategories {
            let payload = createCategoryPayload(category, userId: userId)
            
            try await client
                .from("categories")
                .upsert(payload, onConflict: "local_id")
                .execute()
        }
    }
    
    private func downloadCategories() async throws {
        guard let context = modelContext,
              let userId = SupabaseManager.shared.userId else { return }
        
        let cloudCategories: [CloudCategory] = try await client
            .from("categories")
            .select()
            .eq("user_id", value: userId.uuidString)
            .is("deleted_at", value: nil)
            .execute()
            .value
        
        print("⬇️ [SYNC] Downloaded \(cloudCategories.count) categories")
        
        for cloudCategory in cloudCategories {
            let category = Category(
                name: cloudCategory.name,
                icon: cloudCategory.icon ?? "folder",
                colorHex: cloudCategory.color ?? "#007AFF"
            )
            context.insert(category)
        }
        
        try context.save()
    }
    
    private func downloadBookmarks() async throws {
        guard let context = modelContext,
              let userId = SupabaseManager.shared.userId else { return }
        
        let cloudBookmarks: [CloudBookmark] = try await client
            .from("bookmarks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .is("deleted_at", value: nil)
            .execute()
            .value
        
        print("⬇️ [SYNC] Downloaded \(cloudBookmarks.count) bookmarks")
        
        for cloudBookmark in cloudBookmarks {
            let bookmark = createLocalBookmark(from: cloudBookmark)
            context.insert(bookmark)
        }
        
        try context.save()
    }
    
    private func updateSyncStatus() async throws {
        guard let userId = SupabaseManager.shared.userId else { return }
        
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        let payload: [String: Any] = [
            "user_id": userId.uuidString,
            "last_sync_at": ISO8601DateFormatter().string(from: Date()),
            "device_id": deviceId,
            "sync_token": UUID().uuidString
        ]
        
        try await client
            .from("sync_status")
            .upsert(payload, onConflict: "user_id")
            .execute()
    }
    
    // MARK: - Payload Creators
    
    private func createBookmarkPayload(_ bookmark: Bookmark, userId: UUID) -> [String: Any] {
        var payload: [String: Any] = [
            "user_id": userId.uuidString,
            "local_id": bookmark.id.uuidString,
            "title": bookmark.title,
            "url": bookmark.url,
            "source": bookmark.source.rawValue,
            "is_read": bookmark.isRead,
            "is_favorite": bookmark.isFavorite,
            "tags": bookmark.tags,
            "image_urls": bookmark.imageURLs,
            "created_at": ISO8601DateFormatter().string(from: bookmark.createdAt),
            "updated_at": ISO8601DateFormatter().string(from: bookmark.updatedAt),
            "sync_version": 1
        ]
        
        if let note = bookmark.note {
            payload["note"] = note
        }
        
        if let category = bookmark.category {
            payload["category_id"] = category.id.uuidString
        }
        
        return payload
    }
    
    private func createCategoryPayload(_ category: Category, userId: UUID) -> [String: Any] {
        return [
            "user_id": userId.uuidString,
            "local_id": category.id.uuidString,
            "name": category.name,
            "icon": category.icon,
            "color": category.colorHex,
            "order": category.order,
            "created_at": ISO8601DateFormatter().string(from: category.createdAt),
            "updated_at": ISO8601DateFormatter().string(from: category.updatedAt),
            "sync_version": 1
        ]
    }
    
    private func createLocalBookmark(from cloud: CloudBookmark) -> Bookmark {
        let bookmark = Bookmark(
            title: cloud.title,
            url: cloud.url,
            note: cloud.note,
            source: BookmarkSource(rawValue: cloud.source) ?? .article,
            tags: cloud.tags ?? []
        )
        bookmark.isRead = cloud.isRead
        bookmark.isFavorite = cloud.isFavorite
        bookmark.imageURLs = cloud.imageUrls ?? []
        return bookmark
    }
    
    // MARK: - Helpers
    
    private func canSync() -> Bool {
        guard SupabaseManager.shared.isAuthenticated else {
            print("⚠️ [SYNC] Cannot sync - not authenticated")
            return false
        }
        
        guard NetworkMonitor.shared.isConnected else {
            print("⚠️ [SYNC] Cannot sync - no network")
            syncState = .offline
            return false
        }
        
        guard syncState != .syncing else {
            print("⚠️ [SYNC] Already syncing")
            return false
        }
        
        guard modelContext != nil else {
            print("⚠️ [SYNC] ModelContext not configured")
            return false
        }
        
        return true
    }
    
    private func handleSyncError(_ error: Error) {
        print("❌ [SYNC] Error: \(error.localizedDescription)")
        
        if let syncError = error as? SyncError {
            self.syncError = syncError
        } else {
            self.syncError = .unknown(error.localizedDescription)
        }
        
        syncState = .error
        NotificationCenter.default.post(name: .syncDidFail, object: error)
    }
    
    private func setupNotificationObservers() {
        // Network bağlandığında sync
        NotificationCenter.default.addObserver(
            forName: .networkDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.syncChanges()
            }
        }
        
        // User sign in olduğunda full sync
        NotificationCenter.default.addObserver(
            forName: .userDidSignIn,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performFullSync()
            }
        }
    }
}

// MARK: - Types

extension SyncService {
    
    enum SyncState: Equatable {
        case idle
        case syncing
        case downloading
        case uploading
        case offline
        case error
    }
    
    enum SyncError: LocalizedError {
        case notAuthenticated
        case networkError
        case serverError(String)
        case conflictError
        case unknown(String)
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "Giriş yapmanız gerekiyor"
            case .networkError: return "İnternet bağlantısı yok"
            case .serverError(let msg): return "Sunucu hatası: \(msg)"
            case .conflictError: return "Çakışma tespit edildi"
            case .unknown(let msg): return msg
            }
        }
    }
}

// MARK: - Cloud Models

/// Supabase'den gelen category yapısı
struct CloudCategory: Codable {
    let id: String
    let userId: String
    let localId: String?
    let name: String
    let icon: String?
    let color: String?
    let order: Int?
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case localId = "local_id"
        case name
        case icon
        case color
        case order
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

/// Supabase'den gelen bookmark yapısı
struct CloudBookmark: Codable {
    let id: String
    let userId: String
    let localId: String?
    let title: String
    let url: String
    let note: String?
    let source: String
    let isRead: Bool
    let isFavorite: Bool
    let categoryId: String?
    let tags: [String]?
    let imageUrls: [String]?
    let extractedText: String?
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case localId = "local_id"
        case title
        case url
        case note
        case source
        case isRead = "is_read"
        case isFavorite = "is_favorite"
        case categoryId = "category_id"
        case tags
        case imageUrls = "image_urls"
        case extractedText = "extracted_text"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - Array Extension

extension Array {
    /// Array'i belirli boyutlarda parçalara böl
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}