//
//  MigrationState.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 24.12.2025.
//


//
//  MigrationState.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 24.12.2025.
//


//
//  AccountMigrationService.swift
//  Social Bookmark
//
//  Anonim kullanıcı verilerini Apple hesabına taşıma servisi
//
//  Senaryo:
//  1. Anonim kullanıcı bookmark/kategori ekler
//  2. Apple ile giriş yapar
//  3. Tüm veriler Apple hesabına tek seferlik aktarılır
//  4. Anonim veriler silinir (geri alınamaz)
//  5. Çıkış yapınca cihazda veri kalmaz
//

import Foundation
import SwiftData
import Supabase
import OSLog
internal import Combine

// MARK: - Migration State

enum MigrationState: Equatable {
    case idle
    case preparing
    case migratingCategories(current: Int, total: Int)
    case migratingBookmarks(current: Int, total: Int)
    case uploadingImages(current: Int, total: Int)
    case cleaningUp
    case completed
    case failed(String)
    
    var isInProgress: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }
    
    var progress: Double {
        switch self {
        case .idle: return 0
        case .preparing: return 0.05
        case .migratingCategories(let current, let total):
            return 0.05 + (Double(current) / Double(max(total, 1))) * 0.15
        case .migratingBookmarks(let current, let total):
            return 0.20 + (Double(current) / Double(max(total, 1))) * 0.50
        case .uploadingImages(let current, let total):
            return 0.70 + (Double(current) / Double(max(total, 1))) * 0.20
        case .cleaningUp: return 0.95
        case .completed: return 1.0
        case .failed: return 0
        }
    }
    
    var description: String {
        switch self {
        case .idle:
            return String(localized: "migration.state.idle")
        case .preparing:
            return String(localized: "migration.state.preparing")
        case .migratingCategories(let current, let total):
            return String(localized: "migration.state.categories \(current) \(total)")
        case .migratingBookmarks(let current, let total):
            return String(localized: "migration.state.bookmarks \(current) \(total)")
        case .uploadingImages(let current, let total):
            return String(localized: "migration.state.images \(current) \(total)")
        case .cleaningUp:
            return String(localized: "migration.state.cleaning")
        case .completed:
            return String(localized: "migration.state.completed")
        case .failed(let error):
            return String(localized: "migration.state.failed \(error)")
        }
    }
}

// MARK: - Migration Error

enum MigrationError: LocalizedError {
    case notAnonymous
    case noNewAccount
    case sameAccount
    case migrationInProgress
    case noDataToMigrate
    case categoryMigrationFailed(String)
    case bookmarkMigrationFailed(String)
    case imageMigrationFailed(String)
    case cleanupFailed(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAnonymous:
            return String(localized: "migration.error.not_anonymous")
        case .noNewAccount:
            return String(localized: "migration.error.no_new_account")
        case .sameAccount:
            return String(localized: "migration.error.same_account")
        case .migrationInProgress:
            return String(localized: "migration.error.in_progress")
        case .noDataToMigrate:
            return String(localized: "migration.error.no_data")
        case .categoryMigrationFailed(let reason):
            return String(localized: "migration.error.category_failed \(reason)")
        case .bookmarkMigrationFailed(let reason):
            return String(localized: "migration.error.bookmark_failed \(reason)")
        case .imageMigrationFailed(let reason):
            return String(localized: "migration.error.image_failed \(reason)")
        case .cleanupFailed(let reason):
            return String(localized: "migration.error.cleanup_failed \(reason)")
        case .networkError:
            return String(localized: "migration.error.network")
        }
    }
}

// MARK: - Migration Result

struct MigrationResult {
    let categoriesMigrated: Int
    let bookmarksMigrated: Int
    let imagesMigrated: Int
    let oldUserId: UUID
    let newUserId: UUID
    let completedAt: Date
}

// MARK: - Account Migration Service

@MainActor
final class AccountMigrationService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AccountMigrationService()
    
    // MARK: - Published Properties
    
    @Published private(set) var state: MigrationState = .idle
    @Published private(set) var lastResult: MigrationResult?
    @Published private(set) var lastError: MigrationError?
    
    // MARK: - Private Properties
    
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var modelContext: ModelContext?
    
    // Migration tracking
    private var oldAnonymousUserId: UUID?
    private var categoryIdMapping: [UUID: UUID] = [:] // local -> cloud
    
    // MARK: - Initialization
    
    private init() {
        Logger.auth.info("AccountMigrationService initialized")
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public Methods
    
    /// Anonim hesaptan Apple hesabına veri taşı
    /// - Parameters:
    ///   - anonymousUserId: Eski anonim kullanıcı ID'si
    ///   - newUserId: Yeni Apple hesabı kullanıcı ID'si
    /// - Returns: Migration sonucu
    func migrateAnonymousDataToAppleAccount(
        from anonymousUserId: UUID,
        to newUserId: UUID
    ) async throws -> MigrationResult {
        
        // Validation
        guard state != .idle || !state.isInProgress else {
            throw MigrationError.migrationInProgress
        }
        
        guard anonymousUserId != newUserId else {
            throw MigrationError.sameAccount
        }
        
        guard NetworkMonitor.shared.isConnected else {
            throw MigrationError.networkError
        }
        
        Logger.auth.info("🔄 [MIGRATION] Starting migration from \(anonymousUserId) to \(newUserId)")
        
        oldAnonymousUserId = anonymousUserId
        state = .preparing
        lastError = nil
        categoryIdMapping = [:]
        
        var categoriesMigrated = 0
        var bookmarksMigrated = 0
        var imagesMigrated = 0
        
        do {
            // 1. Kategorileri taşı
            categoriesMigrated = try await migrateCategories(
                from: anonymousUserId,
                to: newUserId
            )
            
            // 2. Bookmark'ları taşı
            let bookmarkResult = try await migrateBookmarks(
                from: anonymousUserId,
                to: newUserId
            )
            bookmarksMigrated = bookmarkResult.bookmarks
            imagesMigrated = bookmarkResult.images
            
            // 3. Eski verileri temizle
            state = .cleaningUp
            try await cleanupAnonymousData(userId: anonymousUserId)
            
            // 4. Local verileri temizle
            await clearLocalData()
            
            // Başarılı
            state = .completed
            
            let result = MigrationResult(
                categoriesMigrated: categoriesMigrated,
                bookmarksMigrated: bookmarksMigrated,
                imagesMigrated: imagesMigrated,
                oldUserId: anonymousUserId,
                newUserId: newUserId,
                completedAt: Date()
            )
            
            lastResult = result
            
            Logger.auth.info("✅ [MIGRATION] Completed! Categories: \(categoriesMigrated), Bookmarks: \(bookmarksMigrated), Images: \(imagesMigrated)")
            
            // Sync'i tetikle (yeni hesap için)
            Task {
                await SyncService.shared.performFullSync()
            }
            
            return result
            
        } catch let error as MigrationError {
            state = .failed(error.localizedDescription)
            lastError = error
            Logger.auth.error("❌ [MIGRATION] Failed: \(error.localizedDescription)")
            throw error
        } catch {
            let migrationError = MigrationError.bookmarkMigrationFailed(error.localizedDescription)
            state = .failed(error.localizedDescription)
            lastError = migrationError
            Logger.auth.error("❌ [MIGRATION] Failed: \(error.localizedDescription)")
            throw migrationError
        }
    }
    
    /// Migration durumunu sıfırla
    func reset() {
        state = .idle
        lastError = nil
        categoryIdMapping = [:]
        oldAnonymousUserId = nil
    }
    
    // MARK: - Category Migration
    
    private func migrateCategories(from oldUserId: UUID, to newUserId: UUID) async throws -> Int {
        Logger.auth.info("📁 [MIGRATION] Migrating categories...")
        
        // Anonim kullanıcının kategorilerini al
        let categories: [CloudCategoryResponse] = try await client
            .from("categories")
            .select()
            .eq("user_id", value: oldUserId.uuidString)
            .execute()
            .value
        
        guard !categories.isEmpty else {
            Logger.auth.info("📁 [MIGRATION] No categories to migrate")
            return 0
        }
        
        state = .migratingCategories(current: 0, total: categories.count)
        
        for (index, category) in categories.enumerated() {
            state = .migratingCategories(current: index + 1, total: categories.count)
            
            // Yeni kategori oluştur (yeni user_id ile)
            let newCategoryId = UUID()
            
            let payload: [String: AnyEncodable] = [
                "id": AnyEncodable(newCategoryId.uuidString),
                "user_id": AnyEncodable(newUserId.uuidString),
                "local_id": AnyEncodable(category.localId ?? category.id),
                "name": AnyEncodable(category.name),
                "icon": AnyEncodable(category.icon ?? "folder"),
                "color": AnyEncodable(category.color ?? "#007AFF"),
                "order": AnyEncodable(category.order ?? 0),
                "is_encrypted": AnyEncodable(category.isEncrypted ?? false),
                "created_at": AnyEncodable(category.createdAt),
                "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: Date())),
                "sync_version": AnyEncodable(1)
            ]
            
            try await client
                .from("categories")
                .insert(payload)
                .execute()
            
            // ID mapping'i kaydet (eski cloud id -> yeni cloud id)
            if let oldId = UUID(uuidString: category.id) {
                categoryIdMapping[oldId] = newCategoryId
            }
            
            Logger.auth.debug("📁 [MIGRATION] Category migrated: \(category.name)")
        }
        
        Logger.auth.info("📁 [MIGRATION] \(categories.count) categories migrated")
        return categories.count
    }
    
    // MARK: - Bookmark Migration
    
    private func migrateBookmarks(from oldUserId: UUID, to newUserId: UUID) async throws -> (bookmarks: Int, images: Int) {
        Logger.auth.info("🔖 [MIGRATION] Migrating bookmarks...")
        
        // Anonim kullanıcının bookmark'larını al
        let bookmarks: [CloudBookmarkResponse] = try await client
            .from("bookmarks")
            .select()
            .eq("user_id", value: oldUserId.uuidString)
            .execute()
            .value
        
        guard !bookmarks.isEmpty else {
            Logger.auth.info("🔖 [MIGRATION] No bookmarks to migrate")
            return (0, 0)
        }
        
        state = .migratingBookmarks(current: 0, total: bookmarks.count)
        
        var imageCount = 0
        var imagesTotal = bookmarks.compactMap { $0.imageUrls }.flatMap { $0 }.count
        
        for (index, bookmark) in bookmarks.enumerated() {
            state = .migratingBookmarks(current: index + 1, total: bookmarks.count)
            
            // Yeni bookmark ID
            let newBookmarkId = UUID()
            
            // Category ID'yi yeni ID'ye çevir
            var newCategoryId: String? = nil
            if let oldCategoryIdString = bookmark.categoryId,
               let oldCategoryId = UUID(uuidString: oldCategoryIdString),
               let mappedId = categoryIdMapping[oldCategoryId] {
                newCategoryId = mappedId.uuidString
            }
            
            // Görselleri taşı (Storage'da kopyala)
            var newImageUrls: [String] = []
            if let oldImageUrls = bookmark.imageUrls, !oldImageUrls.isEmpty {
                state = .uploadingImages(current: imageCount, total: imagesTotal)
                
                for oldPath in oldImageUrls {
                    if let newPath = await copyStorageFile(
                        from: oldPath,
                        oldUserId: oldUserId,
                        newUserId: newUserId,
                        newBookmarkId: newBookmarkId
                    ) {
                        newImageUrls.append(newPath)
                        imageCount += 1
                        state = .uploadingImages(current: imageCount, total: imagesTotal)
                    }
                }
            }
            
            // Yeni bookmark oluştur
            var payload: [String: AnyEncodable] = [
                "id": AnyEncodable(newBookmarkId.uuidString),
                "user_id": AnyEncodable(newUserId.uuidString),
                "local_id": AnyEncodable(bookmark.localId ?? bookmark.id),
                "title": AnyEncodable(bookmark.title),
                "url": AnyEncodable(bookmark.url ?? ""),
                "note": AnyEncodable(bookmark.note ?? ""),
                "source": AnyEncodable(bookmark.source),
                "is_read": AnyEncodable(bookmark.isRead),
                "is_favorite": AnyEncodable(bookmark.isFavorite),
                "tags": AnyEncodable(bookmark.tags ?? []),
                "image_urls": AnyEncodable(newImageUrls),
                "is_encrypted": AnyEncodable(bookmark.isEncrypted ?? false),
                "created_at": AnyEncodable(bookmark.createdAt),
                "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: Date())),
                "sync_version": AnyEncodable(1)
            ]
            
            if let categoryId = newCategoryId {
                payload["category_id"] = AnyEncodable(categoryId)
            }
            
            try await client
                .from("bookmarks")
                .insert(payload)
                .execute()
            
            Logger.auth.debug("🔖 [MIGRATION] Bookmark migrated: \(bookmark.title.prefix(30))...")
        }
        
        Logger.auth.info("🔖 [MIGRATION] \(bookmarks.count) bookmarks, \(imageCount) images migrated")
        return (bookmarks.count, imageCount)
    }
    
    // MARK: - Storage File Copy
    
    private func copyStorageFile(
        from oldPath: String,
        oldUserId: UUID,
        newUserId: UUID,
        newBookmarkId: UUID
    ) async -> String? {
        let storage = client.storage.from("bookmark-images")
        
        do {
            // 1. Eski dosyayı indir
            let data = try await storage.download(path: oldPath)
            
            // 2. Yeni path oluştur
            let fileName = oldPath.components(separatedBy: "/").last ?? "\(UUID().uuidString.prefix(8)).jpg"
            let newPath = "\(newUserId.uuidString)/\(newBookmarkId.uuidString)/\(fileName)"
            
            // 3. Yeni lokasyona yükle
            try await storage.upload(
                newPath,
                data: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )
            
            Logger.auth.debug("🖼️ [MIGRATION] Image copied: \(oldPath) -> \(newPath)")
            return newPath
            
        } catch {
            Logger.auth.error("🖼️ [MIGRATION] Failed to copy image: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Cleanup
    
    /// Anonim kullanıcının cloud verilerini sil
    private func cleanupAnonymousData(userId: UUID) async throws {
        Logger.auth.info("🧹 [MIGRATION] Cleaning up anonymous data...")
        
        // 1. Bookmark'ları sil
        try await client
            .from("bookmarks")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        // 2. Kategorileri sil
        try await client
            .from("categories")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        // 3. Storage'daki görselleri sil
        let storage = client.storage.from("bookmark-images")
        let folderPath = userId.uuidString
        
        do {
            let files = try await storage.list(path: folderPath)
            
            if !files.isEmpty {
                // Alt klasörleri bul ve sil
                for folder in files {
                    let subPath = "\(folderPath)/\(folder.name)"
                    let subFiles = try await storage.list(path: subPath)
                    let filePaths = subFiles.map { "\(subPath)/\($0.name)" }
                    
                    if !filePaths.isEmpty {
                        try await storage.remove(paths: filePaths)
                    }
                }
            }
        } catch {
            Logger.auth.warning("🧹 [MIGRATION] Storage cleanup warning: \(error.localizedDescription)")
            // Storage temizleme hatası critical değil, devam et
        }
        
        // 4. User profile'ı sil (varsa)
        try await client
            .from("user_profiles")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        Logger.auth.info("🧹 [MIGRATION] Anonymous data cleaned up")
    }
    
    /// Local SwiftData verilerini temizle
    private func clearLocalData() async {
        guard let context = modelContext else { return }
        
        Logger.auth.info("🧹 [MIGRATION] Clearing local data...")
        
        do {
            // Tüm bookmark'ları sil
            let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
            for bookmark in bookmarks {
                context.delete(bookmark)
            }
            
            // Tüm kategorileri sil
            let categories = try context.fetch(FetchDescriptor<Category>())
            for category in categories {
                context.delete(category)
            }
            
            try context.save()
            
            Logger.auth.info("🧹 [MIGRATION] Local data cleared")
        } catch {
            Logger.auth.error("🧹 [MIGRATION] Failed to clear local data: \(error.localizedDescription)")
        }
    }
    
    /// Public: Tüm local verileri temizle
    func clearAllLocalData() async {
        Logger.auth.info("🧹 [MIGRATION] clearAllLocalData called")
        
        guard let context = modelContext else {
            Logger.auth.error("🧹 [MIGRATION] ❌ ModelContext is nil! Cannot clear local data.")
            return
        }
        
        Logger.auth.info("🧹 [MIGRATION] Clearing all local data...")
        do {
            let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
            Logger.auth.info("🧹 [MIGRATION] Deleting \(bookmarks.count) bookmarks...")
            for bookmark in bookmarks { context.delete(bookmark) }
            
            let categories = try context.fetch(FetchDescriptor<Category>())
            Logger.auth.info("🧹 [MIGRATION] Deleting \(categories.count) categories...")
            for category in categories { context.delete(category) }
            
            try context.save()
            Logger.auth.info("🧹 [MIGRATION] ✅ Local data cleared successfully")
        } catch {
            Logger.auth.error("🧹 [MIGRATION] Failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Cloud Response Models

private struct CloudCategoryResponse: Codable {
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

struct CloudBookmarkResponse: Codable {
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
