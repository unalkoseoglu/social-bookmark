//
//  SyncableBookmarkRepository.swift
//  Social Bookmark
//
//  ✅ DÜZELTME: Daha güvenilir async sync
//  Task'lar detached olarak çalışır, hata loglanır

import Foundation
import SwiftData
import OSLog

/// Sync destekli BookmarkRepository wrapper
/// Her CRUD işleminden sonra otomatik sync tetikler
final class SyncableBookmarkRepository: BookmarkRepositoryProtocol {
    
    // MARK: - Properties
    
    private let baseRepository: BookmarkRepositoryProtocol
    
    /// Sync aktif mi? (Default: false - Manual sync only)
    var isSyncEnabled: Bool = true
    
    // MARK: - Initialization
    
    init(baseRepository: BookmarkRepositoryProtocol) {
        self.baseRepository = baseRepository
        print("✅ [SyncableBookmarkRepository] Initialized with sync enabled")
    }
    
    // MARK: - BookmarkRepositoryProtocol
    
    var count: Int {
        baseRepository.count
    }
    
    var unreadCount: Int {
        baseRepository.unreadCount
    }
    
    func fetchAll() -> [Bookmark] {
        baseRepository.fetchAll()
    }
    
    func fetch(by id: UUID) -> Bookmark? {
        baseRepository.fetch(by: id)
    }
    
    func create(_ bookmark: Bookmark) {
        print("📝 [SyncableBookmarkRepository] Creating bookmark: \(bookmark.title)")
        baseRepository.create(bookmark)
        
        if isSyncEnabled {
            // Bookmark bilgilerini capture et
            let snapshot = createBookmarkSnapshot(bookmark)
            
            Task.detached { @MainActor in
                do {
                    // 📄 Doküman yükleme işlemi (Syncable layer'da yapıyoruz)
                    if snapshot.source == .document, let fileName = snapshot.fileName, snapshot.fileURL == nil {
                        // Not: fileURL nil ise henüz yüklenmemiştir
                        // Burada SyncableBookmarkRepository veya AddBookmarkViewModel'den veriyi geçirmemiz lazım
                        // Ancak Snapshot'ta data yok. 
                        // DÜZELTME: SyncService.syncBookmark içinde veriyi parametre olarak alacak şekilde güncelleyeceğiz.
                    }
                    
                    try await SyncService.shared.syncBookmark(snapshot)
                    print("✅ [SyncableBookmarkRepository] Synced new bookmark: \(snapshot.title)")
                } catch {
                    print("❌ [SyncableBookmarkRepository] Sync failed for new bookmark: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func update(_ bookmark: Bookmark) {
        print("📝 [SyncableBookmarkRepository] Updating bookmark: \(bookmark.title)")
        baseRepository.update(bookmark)
        
        if isSyncEnabled {
            // Bookmark bilgilerini capture et
            let snapshot = createBookmarkSnapshot(bookmark)
            
            Task.detached { @MainActor in
                do {
                    try await SyncService.shared.syncBookmark(snapshot)
                    print("✅ [SyncableBookmarkRepository] Synced updated bookmark: \(snapshot.title)")
                } catch {
                    print("❌ [SyncableBookmarkRepository] Sync failed for updated bookmark: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func delete(_ bookmark: Bookmark) {
        Logger.sync.info("Deleting bookmark: \(bookmark.title)")
        
        if isSyncEnabled {
            // Bookmark bilgilerini capture et (silmeden önce)
            let snapshot = createBookmarkSnapshot(bookmark)
            
            Task.detached { @MainActor in
                do {
                    try await SyncService.shared.deleteBookmark(snapshot)
                    Logger.sync.info("Deleted from cloud: \(snapshot.title)")
                } catch {
                    Logger.sync.error("Cloud delete failed: \(error.localizedDescription)")
                }
            }
        }
        
        baseRepository.delete(bookmark)
    }
    
    func deleteMultiple(_ bookmarks: [Bookmark]) {
        Logger.sync.info("Deleting \(bookmarks.count) bookmarks")
        
        if isSyncEnabled {
            // Tüm bookmark'ları capture et
            let snapshots = bookmarks.map { createBookmarkSnapshot($0) }
            
            Task.detached { @MainActor in
                for snapshot in snapshots {
                    do {
                        try await SyncService.shared.deleteBookmark(snapshot)
                        Logger.sync.info("Deleted from cloud: \(snapshot.title)")
                    } catch {
                        Logger.sync.error("Cloud delete failed for \(snapshot.title): \(error.localizedDescription)")
                    }
                }
            }
        }
        
        baseRepository.deleteMultiple(bookmarks)
    }
    
    // MARK: - Private Helpers
    
    /// SwiftData managed object'i async-safe snapshot'a çevirir
    private func createBookmarkSnapshot(_ bookmark: Bookmark) -> Bookmark {
        let snapshot = Bookmark(
            title: bookmark.title,
            url: bookmark.url,
            note: bookmark.note,
            source: bookmark.source,
            isRead: bookmark.isRead,
            isFavorite: bookmark.isFavorite,
            categoryId: bookmark.categoryId,
            tags: bookmark.tags,
            imageData: bookmark.imageData,
            imagesData: bookmark.imagesData,
            imageUrls: bookmark.imageUrls,
            fileURL: bookmark.fileURL,
            fileName: bookmark.fileName,
            fileExtension: bookmark.fileExtension,
            fileSize: bookmark.fileSize
        )
        snapshot.id = bookmark.id
        snapshot.createdAt = bookmark.createdAt
        snapshot.updatedAt = bookmark.lastUpdated
        return snapshot
    }
    
    func search(query: String) -> [Bookmark] {
        baseRepository.search(query: query)
    }
    
    func filter(by source: BookmarkSource) -> [Bookmark] {
        baseRepository.filter(by: source)
    }
    
    func filter(by tag: String) -> [Bookmark] {
        baseRepository.filter(by: tag)
    }
    
    func fetchUnread() -> [Bookmark] {
        baseRepository.fetchUnread()
    }
    
    func fetch(from startDate: Date, to endDate: Date) -> [Bookmark] {
        baseRepository.fetch(from: startDate, to: endDate)
    }
}

// MARK: - SyncableCategoryRepository

/// Sync destekli CategoryRepository wrapper
final class SyncableCategoryRepository: CategoryRepositoryProtocol {
    
    // MARK: - Properties
    
    private let baseRepository: CategoryRepositoryProtocol
    
    /// Sync aktif mi? (Default: true)
    var isSyncEnabled: Bool = true
    
    // MARK: - Initialization
    
    init(baseRepository: CategoryRepositoryProtocol) {
        self.baseRepository = baseRepository
        Logger.sync.info("SyncableCategoryRepository initialized with sync enabled")
    }
    
    // MARK: - CategoryRepositoryProtocol
    
    var count: Int {
        baseRepository.count
    }
    
    func fetchAll() -> [Category] {
        baseRepository.fetchAll()
    }
    
    func fetch(by id: UUID) -> Category? {
        baseRepository.fetch(by: id)
    }
    
    func create(_ category: Category) {
        Logger.sync.info("Creating category: \(category.name)")
        baseRepository.create(category)
        
        if isSyncEnabled {
            // Category bilgilerini capture et (SwiftData managed object'i async context'e taşıyamayız)
            let categoryId = category.id
            let categoryName = category.name
            let categoryIcon = category.icon
            let categoryColorHex = category.colorHex
            let categoryOrder = category.order
            let categoryCreatedAt = category.createdAt
            let categoryUpdatedAt = category.lastUpdated
            
            Task.detached { @MainActor in
                do {
                    let categorySnapshot = Category(
                        id: categoryId,
                        name: categoryName,
                        icon: categoryIcon,
                        colorHex: categoryColorHex,
                        order: categoryOrder
                    )
                    categorySnapshot.createdAt = categoryCreatedAt
                    categorySnapshot.updatedAt = categoryUpdatedAt
                    
                    try await SyncService.shared.syncCategory(categorySnapshot)
                    Logger.sync.info("Synced new category: \(categoryName)")
                } catch {
                    Logger.sync.error("Sync failed for new category: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func update(_ category: Category) {
        Logger.sync.info("Updating category: \(category.name)")
        baseRepository.update(category)
        
        if isSyncEnabled {
            Task.detached { @MainActor in
                do {
                    try await SyncService.shared.syncCategory(category)
                    Logger.sync.info("Synced updated category: \(category.name)")
                } catch {
                    Logger.sync.error("Sync failed for updated category: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func delete(_ category: Category) {
        Logger.sync.info("Deleting category: \(category.name)")
        
        if isSyncEnabled {
            // Category bilgilerini capture et (silmeden önce)
            let categoryId = category.id
            let categoryName = category.name
            let categoryIcon = category.icon
            let categoryColorHex = category.colorHex
            let categoryOrder = category.order
            let categoryCreatedAt = category.createdAt
            let categoryUpdatedAt = category.lastUpdated
            
            Task.detached { @MainActor in
                do {
                    let categorySnapshot = Category(
                        id: categoryId,
                        name: categoryName,
                        icon: categoryIcon,
                        colorHex: categoryColorHex,
                        order: categoryOrder
                    )
                    categorySnapshot.createdAt = categoryCreatedAt
                    categorySnapshot.updatedAt = categoryUpdatedAt
                    
                    try await SyncService.shared.deleteCategory(categorySnapshot)
                    Logger.sync.info("Deleted from cloud: \(categoryName)")
                } catch {
                    Logger.sync.error("Cloud delete failed: \(error.localizedDescription)")
                }
            }
        }
        
        baseRepository.delete(category)
    }
    
    func bookmarkCount(for categoryId: UUID) -> Int {
        baseRepository.bookmarkCount(for: categoryId)
    }
    
    func createDefaultsIfNeeded() {
        let hadDefaults = baseRepository.count > 0
        baseRepository.createDefaultsIfNeeded()
        
        // Yeni kategoriler oluşturulduysa sync et
        if !hadDefaults && isSyncEnabled {
            Logger.sync.info("Default categories created, syncing...")
            
            Task.detached { @MainActor in
                await SyncService.shared.syncChanges()
                Logger.sync.info("Default categories synced")
            }
        }
    }
}
