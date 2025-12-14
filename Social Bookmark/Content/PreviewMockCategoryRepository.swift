//
//  PreviewMockCategoryRepository.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 14.12.2025.
//


import Foundation

/// Preview ve test için mock category repository
final class PreviewMockCategoryRepository: CategoryRepositoryProtocol {
    static let shared = PreviewMockCategoryRepository()
    
    private init() {
        createDefaultsIfNeeded()
    }
    
    private var categories: [Category] = []
    
    func fetchAll() -> [Category] {
        categories.sorted { $0.order < $1.order }
    }
    
    func fetch(by id: UUID) -> Category? {
        categories.first { $0.id == id }
    }
    
    func create(_ category: Category) {
        category.order = categories.count
        categories.append(category)
        print("✅ Mock: Created category - \(category.name)")
    }
    
    func update(_ category: Category) {
        print("✅ Mock: Updated category - \(category.name)")
    }
    
    func delete(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        print("✅ Mock: Deleted category - \(category.name)")
    }
    
    func bookmarkCount(for categoryId: UUID) -> Int {
        // Mock için rastgele sayı
        Int.random(in: 0...15)
    }
    
    var count: Int {
        categories.count
    }
    
    func createDefaultsIfNeeded() {
        guard categories.isEmpty else { return }
        categories = Category.createDefaults()
        print("✅ Mock: Created \(categories.count) default categories")
    }
}