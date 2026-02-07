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
import OSLog
import Combine

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
    
    private var modelContext: ModelContext?
    
    private var defaults: UserDefaults {
        UserDefaults(suiteName: APIConstants.appGroupId) ?? .standard
    }
    
    // MARK: - Initialization
    
    private init() {
        Logger.auth.info("AccountMigrationService initialized")
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public Methods
    
    /// Anonim hesaptan Apple hesabına veri taşı (Stubbed for Laravel)
    func migrateAnonymousDataToAppleAccount(
        from anonymousUserId: UUID,
        to newUserId: UUID
    ) async throws -> MigrationResult {
        // NOTE: For now, we return a mock success or throw an error if not implemented
        Logger.auth.info("🔄 [MIGRATION] Stubbed: migration from \(anonymousUserId) to \(newUserId)")
        
        // This is a placeholder since the legacy Supabase logic is removed.
        // True migration should be handled server-side or via new API.
        
        let result = MigrationResult(
            categoriesMigrated: 0,
            bookmarksMigrated: 0,
            imagesMigrated: 0,
            oldUserId: anonymousUserId,
            newUserId: newUserId,
            completedAt: Date()
        )
        
        return result
    }
    
    // MARK: - Supabase to Laravel Migration
    
    private let didMigrateToLaravelKey = "did_migrate_to_laravel_v1"
    
    /// Check if Supabase→Laravel migration is needed and perform it
    /// This runs ONCE per user after app update to migrate from Supabase to Laravel backend
    func performMigrationIfNeeded(modelContext: ModelContext? = nil) async {
        let context = modelContext ?? self.modelContext
        
        guard let modelContext = context else {
            Logger.auth.error("❌ [MIGRATION] Cannot perform migration: ModelContext is nil")
            return
        }
        // Check if already migrated
        guard !defaults.bool(forKey: didMigrateToLaravelKey) else {
            Logger.auth.info("✅ [MIGRATION] Already migrated to Laravel")
            return
        }
        
        // Check if user is authenticated
        guard await AuthService.shared.getCurrentUser() != nil else {
            Logger.auth.info("⏭️ [MIGRATION] No authenticated user, skipping migration")
            return
        }
        
        Logger.auth.info("🔄 [MIGRATION] Starting Supabase → Laravel migration...")
        
        do {
            // Configure self with modelContext
            self.modelContext = modelContext
            
            // Get local data counts
            let bookmarks = try modelContext.fetch(FetchDescriptor<Bookmark>())
            let categories = try modelContext.fetch(FetchDescriptor<Category>())
            
            Logger.auth.info("📊 [MIGRATION] Found \\(bookmarks.count) bookmarks, \\(categories.count) categories locally")
            
            if bookmarks.isEmpty && categories.isEmpty {
                Logger.auth.info("⚠️ [MIGRATION] No local data to migrate, will sync from server")
                
                // Force full sync to get server data
                await SyncService.shared.forceFullSync()
            } else {
                Logger.auth.info("📤 [MIGRATION] Uploading local data to Laravel...")
                
                // Upload local data to Laravel
                try await SyncService.shared.uploadToCloud()
                
                Logger.auth.info("✅ [MIGRATION] Upload complete, now syncing from server...")
                
                // Then sync down any server changes
                await SyncService.shared.forceFullSync()
            }
            
            // Mark migration as complete
            defaults.set(true, forKey: didMigrateToLaravelKey)
            Logger.auth.info("✅ [MIGRATION] Migration complete!")
            
        } catch {
            Logger.auth.error("❌ [MIGRATION] Failed: \\(error.localizedDescription)")
            // Don't mark as complete so we retry next time
        }
    }
    
    /// Public: Tüm local verileri temizle
    func clearAllLocalData() async {
        guard let context = modelContext else {
            Logger.auth.error("🧹 [MIGRATION] ❌ ModelContext is nil! Cannot clear local data.")
            return
        }
        
        Logger.auth.info("🧹 [MIGRATION] Clearing all local data...")
        do {
            let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
            for bookmark in bookmarks { context.delete(bookmark) }
            
            let categories = try context.fetch(FetchDescriptor<Category>())
            for category in categories { context.delete(category) }
            
            try context.save()
            
            // Sync metadata'yı temizle
            defaults.removeObject(forKey: APIConstants.Keys.lastSync)
            
            // Reset migration flag so it runs again for new user
            defaults.removeObject(forKey: didMigrateToLaravelKey)
            
            Logger.auth.info("🧹 [MIGRATION] ✅ Local data and sync metadata cleared successfully")
            NotificationCenter.default.post(name: .localDataCleared, object: nil)
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
