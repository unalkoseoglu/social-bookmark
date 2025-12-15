//
//  SyncableBookmarkRepository.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//
//  BookmarkRepository'yi wrap ederek otomatik sync sağlar
//

import Foundation
import SwiftData

/// Sync destekli BookmarkRepository wrapper
/// Her CRUD işleminden sonra otomatik sync tetikler
final class SyncableBookmarkRepository: BookmarkRepositoryProtocol {
    
    // MARK: - Properties
    
    private let baseRepository: BookmarkRepositoryProtocol
    private let syncService: SyncService
    
    /// Sync aktif mi?
    var isSyncEnabled: Bool = true
    
    // MARK: - Initialization
    
    init(
        baseRepository: BookmarkRepositoryProtocol,
        syncService: SyncService = .shared
    ) {
        self.baseRepository = baseRepository
        self.syncService = syncService
    }
    
    // MARK: - BookmarkRepositoryProtocol
    
    var count: Int {
        baseRepository.count
    }
    
    func fetchAll() -> [Bookmark] {
        baseRepository.fetchAll()
    }
    
    func fetch(by id: UUID) -> Bookmark? {
        baseRepository.fetch(by: id)
    }
    
    func create(_ bookmark: Bookmark) {
        baseRepository.create(bookmark)
        
        // Async sync tetikle
        if isSyncEnabled {
            Task { @MainActor in
                try? await syncService.syncBookmark(bookmark)
            }
        }
    }
    
    func update(_ bookmark: Bookmark) {
        baseRepository.update(bookmark)
        
        // Async sync tetikle
        if isSyncEnabled {
            Task { @MainActor in
                try? await syncService.syncBookmark(bookmark)
            }
        }
    }
    
    func delete(_ bookmark: Bookmark) {
        // Önce cloud'dan sil
        if isSyncEnabled {
            Task { @MainActor in
                try? await syncService.deleteBookmark(bookmark)
            }
        }
        
        baseRepository.delete(bookmark)
    }
    
    func deleteMultiple(_ bookmarks: [Bookmark]) {
        // Önce cloud'dan sil
        if isSyncEnabled {
            Task { @MainActor in
                for bookmark in bookmarks {
                    try? await syncService.deleteBookmark(bookmark)
                }
            }
        }
        
        baseRepository.deleteMultiple(bookmarks)
    }
    
    func search(query: String) -> [Bookmark] {
        baseRepository.search(query: query)
    }
    
    func filter(by source: BookmarkSource) -> [Bookmark] {
        baseRepository.filter(by: source)
    }
    
    func fetchUnread() -> [Bookmark] {
        baseRepository.fetchUnread()
    }
    
    func fetchFavorites() -> [Bookmark] {
        baseRepository.fetchFavorites()
    }
    
    func fetchByCategory(_ categoryId: UUID?) -> [Bookmark] {
        baseRepository.fetchByCategory(categoryId)
    }
    
    func fetchRecent(limit: Int) -> [Bookmark] {
        baseRepository.fetchRecent(limit: limit)
    }
}

/// Sync destekli CategoryRepository wrapper
final class SyncableCategoryRepository: CategoryRepositoryProtocol {
    
    // MARK: - Properties
    
    private let baseRepository: CategoryRepositoryProtocol
    private let syncService: SyncService
    
    /// Sync aktif mi?
    var isSyncEnabled: Bool = true
    
    // MARK: - Initialization
    
    init(
        baseRepository: CategoryRepositoryProtocol,
        syncService: SyncService = .shared
    ) {
        self.baseRepository = baseRepository
        self.syncService = syncService
    }
    
    // MARK: - CategoryRepositoryProtocol
    
    func fetchAll() -> [Category] {
        baseRepository.fetchAll()
    }
    
    func fetch(by id: UUID) -> Category? {
        baseRepository.fetch(by: id)
    }
    
    func create(_ category: Category) {
        baseRepository.create(category)
        
        if isSyncEnabled {
            Task { @MainActor in
                try? await syncService.syncCategory(category)
            }
        }
    }
    
    func update(_ category: Category) {
        baseRepository.update(category)
        
        if isSyncEnabled {
            Task { @MainActor in
                try? await syncService.syncCategory(category)
            }
        }
    }
    
    func delete(_ category: Category) {
        if isSyncEnabled {
            Task { @MainActor in
                try? await syncService.deleteCategory(category)
            }
        }
        
        baseRepository.delete(category)
    }
    
    func createDefaultsIfNeeded() {
        let hadDefaults = !baseRepository.fetchAll().isEmpty
        baseRepository.createDefaultsIfNeeded()
        
        // Yeni kategoriler oluşturulduysa sync et
        if !hadDefaults && isSyncEnabled {
            Task { @MainActor in
                await syncService.syncChanges()
            }
        }
    }
    
    func reorder(_ categories: [Category]) {
        baseRepository.reorder(categories)
        
        if isSyncEnabled {
            Task { @MainActor in
                for category in categories {
                    try? await syncService.syncCategory(category)
                }
            }
        }
    }
}