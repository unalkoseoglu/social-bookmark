import SwiftUI
import Observation

/// Ana sayfa ViewModel'i
/// Dashboard için gerekli tüm verileri yönetir
@Observable
final class HomeViewModel {
    // MARK: - Properties
    
    private(set) var bookmarks: [Bookmark] = []
    private(set) var categories: [Category] = []
    private(set) var isLoading = false
    
    let bookmarkRepository: BookmarkRepositoryProtocol
    let categoryRepository: CategoryRepositoryProtocol
    
    // MARK: - Computed Properties
    
    /// Toplam bookmark sayısı
    var totalCount: Int {
        bookmarkRepository.count
    }
    
    /// Okunmamış bookmark sayısı
    var unreadCount: Int {
        bookmarkRepository.unreadCount
    }
    
    /// Bu hafta eklenen bookmark sayısı
    var thisWeekCount: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return 0
        }
        return bookmarkRepository.fetch(from: weekStart, to: now).count
    }
    
    /// Bugün eklenen bookmark sayısı
    var todayCount: Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return bookmarkRepository.fetch(from: startOfDay, to: Date()).count
    }
    
    /// Favori bookmark sayısı
    var favoritesCount: Int {
        bookmarks.filter { $0.isFavorite }.count
    }
    
    /// Kategorisiz bookmark sayısı
    var uncategorizedCount: Int {
        bookmarks.filter { $0.categoryId == nil }.count
    }
    
    /// Son eklenen bookmarklar (5 adet)
    var recentBookmarks: [Bookmark] {
        Array(bookmarks.prefix(10))
    }
    
    /// Kaynak bazlı istatistikler
    var sourcesWithCounts: [(source: BookmarkSource, count: Int)] {
        BookmarkSource.allCases.compactMap { source in
            let count = bookmarks.filter { $0.source == source }.count
            return count > 0 ? (source: source, count: count) : nil
        }.sorted { $0.count > $1.count }
    }
    
    // MARK: - Initialization
    
    init(bookmarkRepository: BookmarkRepositoryProtocol, categoryRepository: CategoryRepositoryProtocol) {
        self.bookmarkRepository = bookmarkRepository
        self.categoryRepository = categoryRepository
        
        loadData()
    }
    
    // MARK: - Public Methods
    
    /// Verileri yenile
    func refresh() {
        loadData()
    }
    
    /// Belirli bir kategori için bookmark sayısı
    func bookmarkCount(for category: Category) -> Int {
        bookmarks.filter { $0.categoryId == category.id }.count
    }
    
    /// Belirli bir kategorideki bookmarklar
    func bookmarks(for category: Category) -> [Bookmark] {
        bookmarks.filter { $0.categoryId == category.id }
    }
    
    /// QuickFilter için bookmark sayısı
    func count(for filter: QuickFilter) -> Int {
        switch filter {
        case .unread:
            return unreadCount
        case .favorites:
            return favoritesCount
        case .today:
            return todayCount
        case .thisWeek:
            return thisWeekCount
        case .uncategorized:
            return uncategorizedCount
        case .source(let source):
            return bookmarks.filter { $0.source == source }.count
        }
    }
    
    /// QuickFilter için bookmarkları getir
    func bookmarks(for filter: QuickFilter) -> [Bookmark] {
        switch filter {
        case .unread:
            return bookmarks.filter { !$0.isRead }
        case .favorites:
            return bookmarks.filter { $0.isFavorite }
        case .today:
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            return bookmarks.filter { $0.createdAt >= startOfDay }
        case .thisWeek:
            let calendar = Calendar.current
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
                return []
            }
            return bookmarks.filter { $0.createdAt >= weekStart }
        case .uncategorized:
            return bookmarks.filter { $0.categoryId == nil }
        case .source(let source):
            return bookmarks.filter { $0.source == source }
        }
    }
    
    /// Varsayılan kategorileri oluştur
    func createDefaultCategories() {
        categoryRepository.createDefaultsIfNeeded()
        loadCategories()
    }
    
    /// Yeni kategori ekle
    func addCategory(_ category: Category) {
        categoryRepository.create(category)
        loadCategories()
    }
    
    /// Kategori sil
    func deleteCategory(_ category: Category) {
        // Önce bu kategorideki bookmarkların categoryId'sini nil yap
        for bookmark in bookmarks(for: category) {
            bookmark.categoryId = nil
            bookmarkRepository.update(bookmark)
        }
        
        categoryRepository.delete(category)
        loadData()
    }
    
    /// Kategori güncelle
    func updateCategory(_ category: Category) {
        categoryRepository.update(category)
        loadCategories()
    }
    
    /// Bookmark sil
    func deleteBookmark(_ bookmark: Bookmark) {
        bookmarkRepository.delete(bookmark)
        loadBookmarks()
    }
    
    /// Bookmark okundu/okunmadı toggle
    func toggleReadStatus(_ bookmark: Bookmark) {
        bookmark.isRead.toggle()
        bookmarkRepository.update(bookmark)
    }
    
    /// Bookmark favori toggle
    func toggleFavorite(_ bookmark: Bookmark) {
        bookmark.isFavorite.toggle()
        bookmarkRepository.update(bookmark)
    }
    
    /// Arama yap
    func search(query: String) -> [Bookmark] {
        guard !query.isEmpty else { return bookmarks }
        return bookmarkRepository.search(query: query)
    }
    
    // MARK: - Private Methods
    
    private func loadData() {
        isLoading = true
        loadBookmarks()
        loadCategories()
        isLoading = false
    }
    
    private func loadBookmarks() {
        bookmarks = bookmarkRepository.fetchAll()
    }
    
    private func loadCategories() {
        categories = categoryRepository.fetchAll()
    }
}

// MARK: - Source with Count

struct SourceCount: Identifiable {
    let source: BookmarkSource
    let count: Int
    
    var id: String { source.rawValue }
}
