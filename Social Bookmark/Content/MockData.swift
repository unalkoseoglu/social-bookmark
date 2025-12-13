import Foundation

// MARK: - Preview Mock Repository
// Tüm preview'lar için tek merkezi mock repository

/// Singleton pattern - tüm preview'larda aynı instance'ı kullan
final class PreviewMockRepository: BookmarkRepositoryProtocol {
    /// Shared instance
    static let shared = PreviewMockRepository()
    
    /// Private init - dışarıdan oluşturulmasın
    private init() {}
    
    /// Test bookmarkları
    var bookmarks: [Bookmark] = [
        Bookmark(
            title: "SwiftUI Documentation",
            url: "https://developer.apple.com/swiftui",
            note: "Official docs - must read before starting any SwiftUI project",
            source: .article,
            tags: ["Swift", "iOS", "Documentation"]
        ),
        Bookmark(
            title: "Great Twitter Thread on Async/Await",
            url: "https://twitter.com/johnsundell/status/123456",
            note: "Must read about modern concurrency patterns in Swift",
            source: .twitter,
            tags: ["Swift", "Concurrency"]
        ),
        Bookmark(
            title: "Medium Article on MVVM Architecture",
            url: "https://medium.com/ios-dev/mvvm-architecture",
            note: "MVVM pattern explained with real examples",
            source: .medium,
            isRead: true,
            tags: ["Architecture", "MVVM"]
        ),
        Bookmark(
            title: "Awesome Swift GitHub Repo",
            url: "https://github.com/matteocrippa/awesome-swift",
            note: "Curated list of Swift libraries and resources",
            source: .github,
            tags: ["Swift", "Resources"]
        ),
        Bookmark(
            title: "WWDC 2024 - What's New in SwiftUI",
            url: "https://youtube.com/watch?v=example",
            note: "New features in iOS 18",
            source: .youtube,
            tags: ["WWDC", "SwiftUI", "iOS18"]
        ),
        Bookmark(
            title: "LinkedIn Engineering Blog",
            url: "https://www.linkedin.com/posts/linkedin-engineering_scaling-content-platform",
            note: "How LinkedIn scales its content platform",
            source: .linkedin,
            tags: ["LinkedIn", "Architecture"]
        )
    ]
    
    // MARK: - Repository Protocol Implementation
    
    func fetchAll() -> [Bookmark] {
        bookmarks
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
    
    func deleteMultiple(_ bookmarks: [Bookmark]) {
        for bookmark in bookmarks {
            self.bookmarks.removeAll { $0.id == bookmark.id }
        }
        print("✅ Mock: Deleted \(bookmarks.count) bookmarks")
    }
    
    func search(query: String) -> [Bookmark] {
        guard !query.isEmpty else { return bookmarks }
        let lowercased = query.lowercased()
        return bookmarks.filter {
            $0.title.lowercased().contains(lowercased) ||
            $0.note.lowercased().contains(lowercased)
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
}

// MARK: - Sample Bookmarks (Extension)

extension Bookmark {
    /// Preview için hızlı örnek bookmarklar
    static let sampleArticle = Bookmark(
        title: "Understanding Swift Concurrency",
        url: "https://developer.apple.com/swift/concurrency",
        note: "Deep dive into async/await and actors",
        source: .article,
        tags: ["Swift", "Concurrency"]
    )
    
    static let sampleTwitter = Bookmark(
        title: "iOS Dev Tips Thread",
        url: "https://twitter.com/example/status/123",
        note: "Great tips for improving app performance",
        source: .twitter,
        tags: ["iOS", "Tips"]
    )
    
    static let sampleMedium = Bookmark(
        title: "Building a Bookmark App",
        url: "https://medium.com/@dev/bookmark-app",
        note: "Step by step guide",
        source: .medium,
        isRead: true,
        tags: ["Tutorial"]
    )

    static let sampleLinkedIn = Bookmark(
        title: "LinkedIn Post: Product Updates",
        url: "https://www.linkedin.com/posts/company/product-updates",
        note: "Latest platform releases",
        source: .linkedin,
        tags: ["Release", "LinkedIn"]
    )

    static let sampleReddit = Bookmark(
        title: "Reddit: SwiftUI Tips Thread",
        url: "https://www.reddit.com/r/swift/comments/abc123/swiftui_tips/",
        note: "Community-sourced SwiftUI performance tricks",
        source: .reddit,
        tags: ["Reddit", "SwiftUI"]
    )

    /// Tüm sample bookmarklar
    static var samples: [Bookmark] {
        [sampleArticle, sampleTwitter, sampleMedium, sampleLinkedIn, sampleReddit]
    }
}
