//
//  MockCategoryRepository.swift
//  Social BookmarkTests
//
//  Test için kullanılan mock category repository
//

import Foundation
@testable import Social_Bookmark

/// Test için mock category repository
final class MockCategoryRepository: CategoryRepositoryProtocol {
    
    // MARK: - Properties
    
    private var categories: [Category] = []
    
    /// Test için çağrı takibi
    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var fetchAllCallCount = 0
    
    // Bookmark count simülasyonu için
    var bookmarkCounts: [UUID: Int] = [:]
    
    // MARK: - CategoryRepositoryProtocol
    
    func fetchAll() -> [Category] {
        fetchAllCallCount += 1
        return categories.sorted { $0.order < $1.order }
    }
    
    func fetch(by id: UUID) -> Category? {
        return categories.first { $0.id == id }
    }
    
    func create(_ category: Category) {
        createCallCount += 1
        category.order = count
        categories.append(category)
    }
    
    func update(_ category: Category) {
        updateCallCount += 1
        // In-memory olduğu için zaten güncel
    }
    
    func delete(_ category: Category) {
        deleteCallCount += 1
        categories.removeAll { $0.id == category.id }
    }
    
    func bookmarkCount(for categoryId: UUID) -> Int {
        return bookmarkCounts[categoryId] ?? 0
    }
    
    var count: Int {
        return categories.count
    }
    
    func createDefaultsIfNeeded() {
        guard count == 0 else { return }
        
        let defaults = Category.createDefaults()
        for category in defaults {
            categories.append(category)
        }
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        categories.removeAll()
        bookmarkCounts.removeAll()
        createCallCount = 0
        updateCallCount = 0
        deleteCallCount = 0
        fetchAllCallCount = 0
    }
    
    func addSampleData() {
        let samples = [
            Category(name: "Work", icon: "briefcase.fill", colorHex: "#007AFF", order: 0),
            Category(name: "Personal", icon: "person.fill", colorHex: "#34C759", order: 1),
            Category(name: "Learning", icon: "book.fill", colorHex: "#FF9500", order: 2)
        ]
        categories.append(contentsOf: samples)
    }
    
    func setBookmarkCount(for categoryId: UUID, count: Int) {
        bookmarkCounts[categoryId] = count
    }
}
