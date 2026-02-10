//
//  HomeViewModel.swift
//  Social Bookmark
//
//  ✅ DÜZELTME: Manuel sync çağrıları kaldırıldı
//  SyncableRepository kullanıldığı için otomatik sync yapılıyor

import SwiftUI
import Observation
import SwiftData

/// Ana sayfa ViewModel'i
/// Dashboard için gerekli tüm verileri yönetir
@MainActor
@Observable
final class HomeViewModel {
    // MARK: - Properties
    
    private(set) var bookmarks: [Bookmark] = []
    private(set) var categories: [Category] = []
    private(set) var isLoading = false
    var errorMessage: String?
    
    let bookmarkRepository: BookmarkRepositoryProtocol
    let categoryRepository: CategoryRepositoryProtocol
    
    enum CategorySortOrder: String, CaseIterable, Identifiable {
        case manual = "manual"
        case newest = "newest"
        case alphabetical = "alphabetical"
        case count = "count"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .manual: return LanguageManager.shared.localized("categories.sort.manual")
            case .newest: return LanguageManager.shared.localized("all.sort.newest")
            case .alphabetical: return LanguageManager.shared.localized("all.sort.alphabetical")
            case .count: return LanguageManager.shared.localized("categories.sort.count")
            }
        }
    }
    
    // MARK: - Navigation & Sort State
    var selectedTab: AppTab = .home
    var librarySegment: LibraryView.LibrarySegment = .all
    
    var categorySortOrder: CategorySortOrder = .manual {
        didSet {
            UserDefaults.standard.set(categorySortOrder.rawValue, forKey: "categorySortOrder")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Kategoriler (Seçilen sıralama tercihine göre)
    var sortedCategories: [Category] {
        var result = categories
        
        switch categorySortOrder {
        case .manual:
            result.sort { cat1, cat2 in
                if cat1.order != cat2.order {
                    return cat1.order < cat2.order
                }
                return bookmarkCount(for: cat1) > bookmarkCount(for: cat2)
            }
        case .newest:
            result.sort { $0.createdAt > $1.createdAt }
        case .alphabetical:
            result.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .count:
            result.sort { bookmarkCount(for: $0) > bookmarkCount(for: $1) }
        }
        
        return result
    }

    /// Sadece manuel sıralamaya göre kategoriler (Yönetim ekranı için)
    var manualSortedCategories: [Category] {
        categories.sorted { $0.order < $1.order }
    }
    
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
    
    /// Son eklenenler (Safe for Display)
    var recentDisplayBookmarks: [BookmarkDisplayModel] {
        recentBookmarks
            .filter { $0.modelContext != nil } // Crash önlemi
            .map { bookmark in
                BookmarkDisplayModel(bookmark: bookmark, category: categories.first { cat in cat.id == bookmark.categoryId })
            }
    }
    
    /// Son eklenen bookmarklar
    var recentBookmarks: [Bookmark] {
        bookmarks.sorted { $0.createdAt > $1.createdAt }
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
        
        // Sıralama tercihini yükle
        let savedSort = UserDefaults.standard.string(forKey: "categorySortOrder") ?? "manual"
        self.categorySortOrder = CategorySortOrder(rawValue: savedSort) ?? .manual
        
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
            Task { @MainActor in
                print("🔄 [HomeViewModel] Sync completed, refreshing data...")
                self?.loadData()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .categoriesDidSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("🔄 [HomeViewModel] Categories synced, refreshing data...")
                self?.loadData()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .bookmarksDidSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("🔄 [HomeViewModel] Bookmarks synced, refreshing data...")
                self?.loadData()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .userDidSignIn,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("🔐 [HomeViewModel] User signed in, refreshing and syncing...")
                await self?.refresh()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .userDidSignOut,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("👋 [HomeViewModel] User signed out, clearing data...")
                self?.loadData()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .localDataCleared,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("🧹 [HomeViewModel] Local data cleared, refreshing UI...")
                self?.loadData()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .syncDidFail,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("⚠️ [HomeViewModel] Sync failed notification received")
                self?.errorMessage = String(localized: "error.sync_failed")
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Verileri yenile
    func refresh() async {
        isLoading = true
        
        print("🔄 [HomeViewModel] Refreshing UI data...")
        loadData()

        isLoading = false
    }
    
    /// Belirli bir kategori için bookmark sayısı
    func bookmarkCount(for category: Category) -> Int {
        // Öncelik sunucudan gelen sayıda (sync performansı için)
        if let serverCount = category.bookmarksCount, serverCount > 0 {
            return serverCount
        }
        
        // Sunucu bilgisi yoksa veya 0 ise yerelde filtrele (yeni eklenenler için)
        return bookmarks.filter { $0.categoryId == category.id }.count
    }
    
    /// Belirli bir kaynak için bookmark sayısı
    func bookmarkSourceCount(for source: BookmarkSource) -> Int {
        bookmarks.filter { $0.source == source }.count
    }
    
    /// Belirli bir kategorideki bookmarklar (Safe for Display)
    var displayBookmarks: [BookmarkDisplayModel] {
        bookmarks
            .filter { $0.modelContext != nil } // Crash önlemi: Sadece context'e bağlı olanları map'le
            .map { bookmark in
                BookmarkDisplayModel(bookmark: bookmark, category: categories.first { cat in cat.id == bookmark.categoryId })
            }
    }
    
    /// ID'ye göre bookmark bul (Safe lookup for Navigation)
    func bookmark(with id: UUID) -> Bookmark? {
        if let bookmark = bookmarks.first(where: { $0.id == id }), bookmark.modelContext != nil {
            return bookmark
        }
        return nil
    }
    
    /// Belirli bir kategorideki bookmarklar
    func bookmarks(for category: Category) -> [Bookmark] {
        let filtered = bookmarks.filter { $0.categoryId == category.id }
        // ... (logging removed for brevity)
        return filtered
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

    /// Kategorileri yeniden sırala ve manuel moduna geç
    func reorderCategories(_ reordered: [Category]) {
        for (index, category) in reordered.enumerated() {
            category.order = index
            categoryRepository.update(category)
        }
        withAnimation {
            categorySortOrder = .manual
        }
        loadCategories()
    }

    /// Birden fazla kategoriyi toplu güncelle
    func updateCategories(_ categories: [Category]) {
        for category in categories {
            categoryRepository.update(category)
        }
        loadCategories()
    }
    
    /// Bookmark sil
    /// ✅ DÜZELTME: Manuel sync kaldırıldı
    func deleteBookmark(_ bookmark: Bookmark) {
        // 1. Optimistic update: UI'dan hemen kaldır (ID bazlı temizlik daha güvenli)
        bookmarks.removeAll { $0.id == bookmark.id }
        
        // 2. Fiziksel silme
        bookmarkRepository.delete(bookmark)
        
        // 3. Yenileme: Gecikmeli çağrıyı kaldırıyoruz çünkü crash'e sebep oluyor.
        // Repository'den tekrar yükleyerek state'i senkron tutuyoruz.
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
            self.isLoading = false
            print("✅ [HomeViewModel] loadData completed")
        }
    }
    
    private func loadBookmarks() {
        let fetched = bookmarkRepository.fetchAll()
        
        // ID bazlı tekilleştirme ve geçersiz (silinmiş/detached) nesneleri temizleme
        var seenIds = Set<UUID>()
        bookmarks = fetched.filter { bookmark in
            // SwiftData Safety: Detached veya silinmiş objeleri listeye alma
            guard bookmark.modelContext != nil else { return false }
            
            guard !seenIds.contains(bookmark.id) else { return false }
            seenIds.insert(bookmark.id)
            return true
        }
        
        print("📚 [HomeViewModel] Loaded \(bookmarks.count) unique and valid bookmarks")
    }
    
    private func loadCategories() {
        categories = categoryRepository.fetchAll()
        
        let counts = NSCountedSet(array: categories.map { $0.name })
        for name in counts {
            if let nameStr = name as? String, counts.count(for: name) > 1 {
                print("⚠️ [HomeViewModel] DUPLICATE CATEGORY NAME DETECTED: '\(nameStr)'")
                let ids = categories.filter { $0.name == nameStr }.map { $0.id }
                print("   - IDs: \(ids)")
            }
        }
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
