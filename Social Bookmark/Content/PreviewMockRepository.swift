//
//  PreviewMockRepository.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 14.12.2025.
//


import Foundation

/// Preview ve test için mock repository
final class PreviewMockRepository: BookmarkRepositoryProtocol {
    static let shared = PreviewMockRepository()
    
    private var bookmarks: [Bookmark] = []
    
    private init() {
        // Örnek veriler ekle
        setupSampleData()
    }
    
    func fetchAll() -> [Bookmark] {
        bookmarks.sorted { $0.createdAt > $1.createdAt }
    }
    
    func fetch(by id: UUID) -> Bookmark? {
        bookmarks.first { $0.id == id }
    }
    
    func create(_ bookmark: Bookmark) {
        bookmarks.append(bookmark)
        print("✅ Mock: Created bookmark - \(bookmark.title)")
    }
    
    func update(_ bookmark: Bookmark) {
        print("✅ Mock: Updated bookmark - \(bookmark.title)")
    }
    
    func delete(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        print("✅ Mock: Deleted bookmark - \(bookmark.title)")
    }
    
    func deleteMultiple(_ bookmarksToDelete: [Bookmark]) {
        let ids = Set(bookmarksToDelete.map { $0.id })
        bookmarks.removeAll { ids.contains($0.id) }
    }
    
    func search(query: String) -> [Bookmark] {
        let lowercased = query.lowercased()
        return bookmarks.filter {
            $0.title.lowercased().contains(lowercased) ||
            $0.note.lowercased().contains(lowercased) ||
            $0.tags.contains { $0.lowercased().contains(lowercased) }
        }
    }
    
    func filter(by source: BookmarkSource) -> [Bookmark] {
        bookmarks.filter { $0.source == source }
    }
    
    func fetchUnread() -> [Bookmark] {
        bookmarks.filter { !$0.isRead }
    }
    
    func filter(by tag: String) -> [Bookmark] {
        bookmarks.filter { $0.tags.contains(tag) }
    }
    
    func fetch(from startDate: Date, to endDate: Date) -> [Bookmark] {
        bookmarks.filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
    }
    
    var count: Int {
        bookmarks.count
    }
    
    var unreadCount: Int {
        bookmarks.filter { !$0.isRead }.count
    }
    
    // MARK: - Sample Data
    
    private func setupSampleData() {
        let calendar = Calendar.current
        let now = Date()
        
        bookmarks = [
            Bookmark(
                title: "SwiftUI ile Modern iOS Geliştirme",
                url: "https://developer.apple.com/swiftui",
                note: "Apple'ın resmi SwiftUI dokümantasyonu",
                source: .article,
                isRead: true,
                isFavorite: true,
                tags: ["swift", "ios", "swiftui"],
               
            ),
           
           
            Bookmark(
                title: "Kariyer tavsiyeleri - Developer roadmap",
                url: "https://linkedin.com/posts/example",
                source: .linkedin,
                tags: ["career", "advice"]
            ),
            Bookmark(
                title: "WWDC 2024 Keynote",
                url: "https://youtube.com/watch?v=example",
                source: .youtube,
                tags: ["wwdc", "apple"]
            )
        ]
        
        // Tarihleri çeşitlendir
        for (index, bookmark) in bookmarks.enumerated() {
            if let date = calendar.date(byAdding: .day, value: -index, to: now) {
                // Not: @Model sınıfında createdAt readonly olabilir, bu durumda init'te ayarlanmalı
            }
        }
    }
}
