//
//  BookmarkListViewModel.swift
//  Social Bookmark
//
//  ✅ DÜZELTME: Sync completion observer eklendi

import SwiftUI
import Observation

/// Ana liste ekranının business logic'i
/// @Observable: iOS 17+ modern state management
/// View bu değişkenleri izler, değişince otomatik refresh olur
@Observable
final class BookmarkListViewModel {
    // MARK: - Published State
    
    /// Gösterilecek bookmarklar
    private(set) var bookmarks: [Bookmark] = []
    
    /// Yükleniyor mu?
    private(set) var isLoading = false
    
    /// Hata mesajı (varsa)
    private(set) var errorMessage: String?
    
    /// Arama metni - kullanıcı yazarken filtrelenir
    var searchText = "" {
        didSet {
            // searchText değişince otomatik arama yap
            performSearch()
        }
    }
    
    /// Seçili kaynak filtresi (nil = hepsi)
    var selectedSource: BookmarkSource? {
        didSet {
            applyFilter()
        }
    }
    
    /// Sadece okunmamışları göster
    var showOnlyUnread = false {
        didSet {
            loadBookmarks()
        }
    }
    
    // MARK: - Dependencies
    
    /// Repository - veri erişim katmanı
    let repository: BookmarkRepositoryProtocol
    
    // MARK: - Computed Properties
    
    /// Liste boş mu?
    var isEmpty: Bool {
        bookmarks.isEmpty && !isLoading
    }
    
    /// Toplam bookmark sayısı
    var totalCount: Int {
        repository.count
    }
    
    /// Okunmamış sayısı
    var unreadCount: Int {
        repository.unreadCount
    }
    
    // MARK: - Initialization
    
    init(repository: BookmarkRepositoryProtocol) {
        self.repository = repository
        loadBookmarks()
        
        // ✅ YENİ: Sync tamamlandığında listeyi yenile
        setupSyncObserver()
    }
    
    // MARK: - Private Setup
    
    /// ✅ YENİ: Sync completion observer
    private func setupSyncObserver() {
        NotificationCenter.default.addObserver(
            forName: .syncDidComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 [BookmarkListViewModel] Sync completed, refreshing list...")
            self?.loadBookmarks()
        }
    }
    
    // MARK: - Public Methods
    
    /// Bookmarkları yükle/yenile
    func loadBookmarks() {
        isLoading = true
        errorMessage = nil
        
        // @MainActor: UI güncellemeleri main thread'de olmalı
        Task { @MainActor in
            do {
                if showOnlyUnread {
                    bookmarks = repository.fetchUnread()
                } else {
                    bookmarks = repository.fetchAll()
                }
                isLoading = false
            } catch {
                errorMessage = "Yüklenemedi: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    /// Bookmark sil
    /// ✅ SyncableRepository sayesinde otomatik sync yapılır
    func deleteBookmark(_ bookmark: Bookmark) {
        repository.delete(bookmark)
        loadBookmarks() // Listeyi güncelle
    }
    
    /// Birden fazla bookmark sil
    func deleteBookmarks(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { bookmarks[$0] }
        repository.deleteMultiple(itemsToDelete)
        loadBookmarks()
    }
    
    /// Okundu işaretle / işareti kaldır
    /// ✅ SyncableRepository sayesinde otomatik sync yapılır
    func toggleReadStatus(_ bookmark: Bookmark) {
        bookmark.isRead.toggle()
        repository.update(bookmark)
        
        // Sadece okunmamışları gösteriyorsak, listeyi yenile
        if showOnlyUnread {
            loadBookmarks()
        }
    }
    
    /// Tüm bookmarkları okundu işaretle
    func markAllAsRead() {
        for bookmark in bookmarks where !bookmark.isRead {
            bookmark.isRead = true
            repository.update(bookmark)
        }
        loadBookmarks()
    }
    
    /// Favori toggle
    /// ✅ YENİ: Favori toggle metodu eklendi
    func toggleFavorite(_ bookmark: Bookmark) {
        bookmark.isFavorite.toggle()
        repository.update(bookmark)
    }
    
    /// Filtreleri sıfırla
    func clearFilters() {
        searchText = ""
        selectedSource = nil
        showOnlyUnread = false
    }
    
    // MARK: - Private Methods
    
    /// Arama yap
    private func performSearch() {
        guard !searchText.isEmpty else {
            loadBookmarks()
            return
        }
        
        isLoading = true
        
        Task { @MainActor in
            bookmarks = repository.search(query: searchText)
            isLoading = false
        }
    }
    
    /// Kaynak filtresi uygula
    private func applyFilter() {
        guard let source = selectedSource else {
            loadBookmarks()
            return
        }
        
        isLoading = true
        
        Task { @MainActor in
            bookmarks = repository.filter(by: source)
            isLoading = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
