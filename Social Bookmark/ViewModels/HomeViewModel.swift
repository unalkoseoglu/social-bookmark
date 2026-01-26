//
//  HomeViewModel.swift
//  Social Bookmark
//
//  ✅ DÜZELTME: Manuel sync çağrıları kaldırıldı
//  SyncableRepository kullanıldığı için otomatik sync yapılıyor

import SwiftUI
import Observation

/// Ana sayfa ViewModel'i
/// Dashboard için gerekli tüm verileri yönetir
@MainActor
@Observable
final class HomeViewModel {
    // MARK: - Properties
    
    private(set) var bookmarks: [Bookmark] = []
    private(set) var categories: [Category] = []
    private(set) var isLoading = false
    var refreshID = UUID() // ✅ UI'ı yenilemeye zorlamak için
    
    let bookmarkRepository: BookmarkRepositoryProtocol
    let categoryRepository: CategoryRepositoryProtocol
    
    // MARK: - Computed Properties
    
    /// Toplam bookmark sayısı
    var totalCount: Int {
        bookmarkRepository.count
    }
    
    var popularTags: [String] {
        let tags = allBookmarks.flatMap { $0.tags }
        let counts = Dictionary(grouping: tags, by: { $0 }).mapValues(\.count)
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }
    
    var allBookmarks: [Bookmark] {
        bookmarks
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
    
    /// Son eklenen bookmarklar (10 adet)
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
        
        // ✅ YENİ: Sync tamamlandığında verileri yenile
        setupSyncObserver()
    }
    
    // MARK: - Private Setup
    
    /// ✅ YENİ: Sync ve Auth change observers
    private func setupSyncObserver() {
        NotificationCenter.default.addObserver(
            forName: .syncDidComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 [HomeViewModel] Sync completed, refreshing data...")
            self?.loadData()
        }
        
        NotificationCenter.default.addObserver(
            forName: .categoriesDidSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 [HomeViewModel] Categories synced, refreshing data...")
            self?.loadData()
        }
        
        NotificationCenter.default.addObserver(
            forName: .bookmarksDidSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 [HomeViewModel] Bookmarks synced, refreshing data...")
            self?.loadData()
        }
        
        NotificationCenter.default.addObserver(
            forName: .userDidSignIn,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔐 [HomeViewModel] User signed in, refreshing and syncing...")
            Task {
                await self?.refresh()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .userDidSignOut,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("👋 [HomeViewModel] User signed out, clearing data...")
            self?.loadData()
        }
    }
    
    // MARK: - Public Methods
    
    /// Verileri yenile
    func refresh() async {
        isLoading = true
        
        print("🔄 [HomeViewModel] Manual refresh - triggering sync...")
        await SyncService.shared.performFullSync()
        loadData()

        isLoading = false
    }
    
    /// Belirli bir kategori için bookmark sayısı
    func bookmarkCount(for category: Category) -> Int {
        bookmarks.filter { $0.categoryId == category.id }.count
    }
    
    /// Belirli bir kaynak için bookmark sayısı
    func bookmarkSourceCount(for source: BookmarkSource) -> Int {
        bookmarks.filter { $0.source == source }.count
    }
    
    /// Belirli bir kategorideki bookmarklar
    func bookmarks(for category: Category) -> [Bookmark] {
        bookmarks.filter { $0.categoryId == category.id }
    }
    
    /// Varsayılan kategorileri oluştur
    func createDefaultCategories() {
        categoryRepository.createDefaultsIfNeeded()
        loadCategories()
    }
    
    /// Yeni kategori ekle
    /// ✅ DÜZELTME: Manuel sync kaldırıldı - SyncableCategoryRepository otomatik sync yapıyor
    func addCategory(_ category: Category) {
        categoryRepository.create(category)
        loadCategories()
    }
    
    /// Kategori sil
    /// ✅ DÜZELTME: Manuel sync kaldırıldı
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
    /// ✅ DÜZELTME: Debug logları eklendi
    func updateCategory(_ category: Category) {
        print("🔄 [HomeViewModel] updateCategory called")
        print("   - ID: \(category.id)")
        print("   - Name: \(category.name)")
        print("   - Icon: \(category.icon)")
        print("   - Color: \(category.colorHex)")
        
        categoryRepository.update(category)
        loadCategories()
        
        print("✅ [HomeViewModel] updateCategory completed")
    }
    
    /// Bookmark sil
    /// ✅ DÜZELTME: Manuel sync kaldırıldı
    func deleteBookmark(_ bookmark: Bookmark) {
        bookmarkRepository.delete(bookmark)
        loadBookmarks()
    }
    
    /// Bookmark okundu/okunmadı toggle
    /// ✅ DÜZELTME: Manuel sync kaldırıldı
    func toggleReadStatus(_ bookmark: Bookmark) {
        bookmark.isRead.toggle()
        bookmarkRepository.update(bookmark)
    }
    
    /// Bookmark favori toggle
    /// ✅ DÜZELTME: Manuel sync kaldırıldı
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
    
    func loadData() {
        print("📥 [HomeViewModel] loadData called")
        isLoading = true
        loadBookmarks()
        loadCategories()
        
        // Context'in yerleşmesi için çok kısa bir bekleme ve UI yenileme
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.refreshID = UUID()
            self.isLoading = false
            print("✅ [HomeViewModel] loadData completed, refreshID updated")
        }
    }
    
    private func loadBookmarks() {
        bookmarks = bookmarkRepository.fetchAll()
        print("📚 [HomeViewModel] Loaded \(bookmarks.count) bookmarks")
    }
    
    private func loadCategories() {
        categories = categoryRepository.fetchAll()
        print("🗂️ [HomeViewModel] Loaded \(categories.count) categories")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Source with Count

struct SourceCount: Identifiable {
    let source: BookmarkSource
    let count: Int
    
    var id: String { source.rawValue }
}
