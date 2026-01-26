import SwiftData
import Foundation
import OSLog

/// Concrete implementation of BookmarkRepositoryProtocol
/// SwiftData ile veritabanı işlemlerini yönetir
final class BookmarkRepository: BookmarkRepositoryProtocol {
    // MARK: - Properties
    
    /// SwiftData context - tüm DB işlemleri bu üzerinden
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    /// Repository'yi model context ile başlat
    /// - Parameter modelContext: SwiftData context
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    func fetchAll() -> [Bookmark] {
        // FetchDescriptor: SQL query gibi düşün
        // SELECT * FROM Bookmark ORDER BY createdAt DESC
        let descriptor = FetchDescriptor<Bookmark>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        // try? = hata varsa nil döner, uygulama crash etmez
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetch(by id: UUID) -> Bookmark? {
        // #Predicate: Type-safe SQL WHERE clause
        // WHERE id = ?
        let predicate = #Predicate<Bookmark> { bookmark in
            bookmark.id == id
        }
        
        var descriptor = FetchDescriptor<Bookmark>(predicate: predicate)
        descriptor.fetchLimit = 1 // LIMIT 1
        
        return try? modelContext.fetch(descriptor).first
    }
    
    func create(_ bookmark: Bookmark) {
        // INSERT INTO Bookmark ...
        modelContext.insert(bookmark)
        
        // Değişiklikleri kaydet
        try? modelContext.save()
    }
    
    func update(_ bookmark: Bookmark) {
        bookmark.updatedAt = Date()
        try? modelContext.save()
    }
    
    func delete(_ bookmark: Bookmark) {
        // DELETE FROM Bookmark WHERE id = ?
        modelContext.delete(bookmark)
        try? modelContext.save()
    }
    
    func deleteMultiple(_ bookmarks: [Bookmark]) {
        for bookmark in bookmarks {
            modelContext.delete(bookmark)
        }
        try? modelContext.save()
    }
    
    // MARK: - Search & Filter
    
    func search(query: String) -> [Bookmark] {
        guard !query.isEmpty else { return fetchAll() }
        
        let lowercasedQuery = query.lowercased()
        
        // WHERE (title LIKE %query% OR note LIKE %query%)
        let predicate = #Predicate<Bookmark> { bookmark in
            bookmark.title.localizedStandardContains(lowercasedQuery) ||
            bookmark.note.localizedStandardContains(lowercasedQuery)
        }
        
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Logger.repository.error("search failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func filter(by source: BookmarkSource) -> [Bookmark] {
        let predicate = #Predicate<Bookmark> { bookmark in
            bookmark.source == source
        }
        
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Logger.repository.error("filter(by source) failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchUnread() -> [Bookmark] {
        let predicate = #Predicate<Bookmark> { bookmark in
            bookmark.isRead == false
        }
        
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Logger.repository.error("fetchUnread failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func filter(by tag: String) -> [Bookmark] {
        let predicate = #Predicate<Bookmark> { bookmark in
            bookmark.tags.contains(tag)
        }
        
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Logger.repository.error("filter(by tag) failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetch(from startDate: Date, to endDate: Date) -> [Bookmark] {
        let predicate = #Predicate<Bookmark> { bookmark in
            bookmark.createdAt >= startDate && bookmark.createdAt <= endDate
        }
        
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Logger.repository.error("fetch(from:to:) failed: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Statistics
    
    var count: Int {
        let descriptor = FetchDescriptor<Bookmark>()
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            Logger.repository.error("count failed: \(error.localizedDescription)")
            return 0
        }
    }
    
    var unreadCount: Int {
        let predicate = #Predicate<Bookmark> { $0.isRead == false }
        let descriptor = FetchDescriptor<Bookmark>(predicate: predicate)
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            Logger.repository.error("unreadCount failed: \(error.localizedDescription)")
            return 0
        }
    }
}
