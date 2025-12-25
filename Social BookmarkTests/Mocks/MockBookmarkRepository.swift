//
//  MockBookmarkRepository.swift
//  Social BookmarkTests
//
//  Test için kullanılan mock repository
//

import Foundation
@testable import Social_Bookmark

/// Test için mock repository
/// Gerçek veritabanı yerine in-memory storage kullanır
final class MockBookmarkRepository: BookmarkRepositoryProtocol {
    
    // MARK: - Properties
    
    /// In-memory storage
    private var bookmarks: [Bookmark] = []
    
    /// Test için çağrı takibi
    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var fetchAllCallCount = 0
    
    // MARK: - BookmarkRepositoryProtocol
    
    func fetchAll() -> [Bookmark] {
        fetchAllCallCount += 1
        return bookmarks.sorted { $0.createdAt > $1.createdAt }
    }
    
    func fetch(by id: UUID) -> Bookmark? {
        return bookmarks.first { $0.id == id }
    }
    
    func create(_ bookmark: Bookmark) {
        createCallCount += 1
        bookmarks.append(bookmark)
    }
    
    func update(_ bookmark: Bookmark) {
        updateCallCount += 1
        // In-memory olduğu için zaten güncel
    }
    
    func delete(_ bookmark: Bookmark) {
        deleteCallCount += 1
        bookmarks.removeAll { $0.id == bookmark.id }
    }
    
    func deleteMultiple(_ bookmarks: [Bookmark]) {
        for bookmark in bookmarks {
            delete(bookmark)
        }
    }
    
    func search(query: String) -> [Bookmark] {
        guard !query.isEmpty else { return fetchAll() }
        let lowercased = query.lowercased()
        return bookmarks.filter {
            $0.title.lowercased().contains(lowercased) ||
            $0.note.lowercased().contains(lowercased)
        }
    }
    
    func filter(by source: BookmarkSource) -> [Bookmark] {
        return bookmarks.filter { $0.source == source }
    }
    
    func fetchUnread() -> [Bookmark] {
        return bookmarks.filter { !$0.isRead }
    }
    
    func filter(by tag: String) -> [Bookmark] {
        return bookmarks.filter { $0.tags.contains(tag) }
    }
    
    func fetch(from startDate: Date, to endDate: Date) -> [Bookmark] {
        return bookmarks.filter {
            $0.createdAt >= startDate && $0.createdAt <= endDate
        }
    }
    
    var count: Int {
        return bookmarks.count
    }
    
    var unreadCount: Int {
        return bookmarks.filter { !$0.isRead }.count
    }
    
    // MARK: - Test Helpers
    
    /// Test verilerini temizle
    func reset() {
        bookmarks.removeAll()
        createCallCount = 0
        updateCallCount = 0
        deleteCallCount = 0
        fetchAllCallCount = 0
    }
    
    /// Test için örnek bookmark'lar ekle
    func addSampleData() {
        let samples = [
            createBookmark(title: "Swift Tutorial", source: .article, tags: ["swift", "ios"]),
            createBookmark(title: "Twitter Post", source: .twitter, isRead: true),
            createBookmark(title: "Reddit Discussion", source: .reddit, tags: ["discussion"]),
            createBookmark(title: "LinkedIn Article", source: .linkedin),
            createBookmark(title: "Medium Blog", source: .medium, isFavorite: true)
        ]
        bookmarks.append(contentsOf: samples)
    }
    
    private func createBookmark(
        title: String,
        source: BookmarkSource = .other,
        isRead: Bool = false,
        isFavorite: Bool = false,
        tags: [String] = []
    ) -> Bookmark {
        return Bookmark(
            title: title,
            url: "https://example.com/\(title.lowercased().replacingOccurrences(of: " ", with: "-"))",
            note: "Note for \(title)",
            source: source,
            isRead: isRead,
            isFavorite: isFavorite,
            tags: tags
        )
    }
}
