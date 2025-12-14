//
//  CategoryRepository.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 14.12.2025.
//


import Foundation
import SwiftData

/// Kategori Repository
/// SwiftData ile kategori CRUD işlemleri
final class CategoryRepository: CategoryRepositoryProtocol {
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    func fetchAll() -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.order, order: .forward)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Category fetchAll error: \(error)")
            return []
        }
    }
    
    func fetch(by id: UUID) -> Category? {
        let predicate = #Predicate<Category> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("❌ Category fetch by id error: \(error)")
            return nil
        }
    }
    
    func create(_ category: Category) {
        // Yeni kategori için sıra numarası
        category.order = count
        
        modelContext.insert(category)
        save()
        print("✅ Created category: \(category.name)")
    }
    
    func update(_ category: Category) {
        save()
        print("✅ Updated category: \(category.name)")
    }
    
    func delete(_ category: Category) {
        modelContext.delete(category)
        save()
        print("✅ Deleted category: \(category.name)")
    }
    
    func bookmarkCount(for categoryId: UUID) -> Int {
        let predicate = #Predicate<Bookmark> { $0.categoryId == categoryId }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            print("❌ Bookmark count error: \(error)")
            return 0
        }
    }
    
    var count: Int {
        let descriptor = FetchDescriptor<Category>()
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            return 0
        }
    }
    
    func createDefaultsIfNeeded() {
        guard count == 0 else { return }
        
        let defaults = Category.createDefaults()
        for category in defaults {
            modelContext.insert(category)
        }
        save()
        print("✅ Created \(defaults.count) default categories")
    }
    
    // MARK: - Private Methods
    
    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("❌ Category save error: \(error)")
        }
    }
}
