import SwiftUI

/// Tüm bookmarkları listeleyen view
/// "Tümünü Gör" butonundan açılır
/// ✅ Pagination ile optimize edildi
struct AllBookmarksView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    
    @State private var searchText = ""
    @State private var debouncedSearchText = "" // Debounced search
    @State private var selectedSource: BookmarkSource?
    @State private var sortOrder: SortOrder = .newest
    @State private var showingFilters = false
    
    // MARK: - Pagination State
    
    @State private var displayedBookmarks: [Bookmark] = []
    @State private var currentPage = 0
    @State private var isLoadingMore = false
    
    private let itemsPerPage = 20
    
    // MARK: - Sort Order
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case newest = "newest"
        case oldest = "oldest"
        case alphabetical = "alphabetical"
        case source = "source"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .newest: return String(localized: "all.sort.newest")
            case .oldest: return String(localized: "all.sort.oldest")
            case .alphabetical: return String(localized: "all.sort.alphabetical")
            case .source: return String(localized: "all.sort.source")
            }
        }
        
        var icon: String {
            switch self {
            case .newest: return "arrow.down.circle"
            case .oldest: return "arrow.up.circle"
            case .alphabetical: return "textformat.abc"
            case .source: return "square.grid.2x2"
            }
        }
    }
    
    // MARK: - Filtered & Sorted Bookmarks (OPTIMIZED)
    
    @State private var filteredResults: [Bookmark] = []
    
    private var filteredBookmarks: [Bookmark] {
        filteredResults
    }
    
    // Kaynak bazlı gruplama
    private var groupedBookmarks: [BookmarkSource: [Bookmark]] {
        Dictionary(grouping: displayedBookmarks, by: { $0.source })
    }
    
    private var hasMorePages: Bool {
        displayedBookmarks.count < filteredResults.count
    }
    
    var body: some View {
        bookmarkList
            .navigationTitle(Text("all.title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("all.search_prompt"))
            .toolbar {
                toolbarContent
            }
            .task {
                // İlk açılışta hesapla
                await updateFilteredBookmarks()
                loadInitialPage()
            }
            .onChange(of: searchText) { _, newValue in
                // Debounce logic inside the Task
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                    if searchText == newValue {
                        debouncedSearchText = newValue
                        await updateFilteredBookmarks()
                        resetPagination()
                    }
                }
            }
            .onChange(of: selectedSource) { _, _ in
                Task {
                    await updateFilteredBookmarks()
                    resetPagination()
                }
            }
            .onChange(of: sortOrder) { _, _ in
                Task {
                    await updateFilteredBookmarks()
                    resetPagination()
                }
            }
    }
    
    // MARK: - Optimization Methods
    
    private func updateFilteredBookmarks() async {
        let currentBookmarks = viewModel.allBookmarks
        let currentSearch = debouncedSearchText
        let currentSource = selectedSource
        let currentSort = sortOrder
        
        // Heavy lifting off main thread
        let results = await Task.detached(priority: .userInitiated) {
            var bookmarks = currentBookmarks
            
            // Kaynak filtresi
            if let source = currentSource {
                bookmarks = bookmarks.filter { $0.source == source }
            }
            
            // Arama filtresi
            if !currentSearch.isEmpty {
                let searchLower = currentSearch.lowercased()
                bookmarks = bookmarks.filter { bookmark in
                    bookmark.title.lowercased().contains(searchLower) ||
                    bookmark.note.lowercased().contains(searchLower) ||
                    bookmark.tags.contains { $0.lowercased().contains(searchLower) }
                }
            }
            
            // Sıralama
            switch currentSort {
            case .newest:
                bookmarks.sort { $0.createdAt > $1.createdAt }
            case .oldest:
                bookmarks.sort { $0.createdAt < $1.createdAt }
            case .alphabetical:
                bookmarks.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
            case .source:
                bookmarks.sort { $0.source.rawValue < $1.source.rawValue }
            }
            
            return bookmarks
        }.value
        
        // Update UI on main thread
        withAnimation {
            self.filteredResults = results
        }
    }
    
    // MARK: - Bookmark List
    
    private var bookmarkList: some View {
        UnifiedBookmarkList(
            bookmarks: displayedBookmarks,
            viewModel: viewModel,
            isGroupedBySource: sortOrder == .source,
            showStats: true,
            hasMorePages: hasMorePages,
            isLoadingMore: isLoadingMore,
            onLoadMore: { loadMoreBookmarks() },
            emptyTitle: String(localized: "all.empty.title"),
            emptySubtitle: String(localized: "all.empty.desc"),
            emptyIcon: "bookmark"
        )
    }
    
    // List item logic moved to UnifiedBookmarkList
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                // Sort options
                Section("all.menu.sort") {
                    ForEach(SortOrder.allCases) { order in
                        Button {
                            withAnimation {
                                sortOrder = order
                            }
                        } label: {
                            Label(order.title, systemImage: sortOrder == order ? "checkmark" : order.icon)
                        }
                    }
                }
                
                Divider()
                
                // Mark all as read
                Button {
                    Task {
                        await  markAllAsRead()
                    }
                   
                } label: {
                    Label("all.action.mark_all_read", systemImage: "checkmark.circle.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    // MARK: - Filter Sheet
    
    private var filterSheet: some View {
        NavigationStack {
            List {
                Section("all.filter.source") {
                    ForEach(BookmarkSource.allCases) { source in
                        Button {
                            selectedSource = selectedSource == source ? nil : source
                        } label: {
                            HStack {
                                Text(source.emoji)
                                Text(source.displayName)
                                Spacer()
                                if selectedSource == source {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle(Text("all.filter.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") {
                        showingFilters = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Pagination Methods
    
    private func loadInitialPage() {
        currentPage = 0
        displayedBookmarks = []
        loadMoreBookmarks()
    }
    
    private func resetPagination() {
        loadInitialPage()
    }
    
    private func loadMoreBookmarks() {
        guard !isLoadingMore else { return }
        
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredBookmarks.count)
        
        guard startIndex < filteredBookmarks.count else { return }
        
        isLoadingMore = true
        
        // Simulate async loading
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            
            await MainActor.run {
                let newBookmarks = Array(filteredBookmarks[startIndex..<endIndex])
                displayedBookmarks.append(contentsOf: newBookmarks)
                currentPage += 1
                isLoadingMore = false
            }
        }
    }
    
    private func loadMoreIfNeeded(currentBookmark: Bookmark) {
        guard let index = displayedBookmarks.firstIndex(where: { $0.id == currentBookmark.id }) else { return }
        
        if index >= displayedBookmarks.count - 5 && !isLoadingMore {
            loadMoreBookmarks()
        }
    }
    
    // MARK: - Actions
    
    private func deleteBookmark(_ bookmark: Bookmark) async {
        viewModel.bookmarkRepository.delete(bookmark)
        await viewModel.refresh()
        
        // Remove from displayed list
        if let index = displayedBookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            displayedBookmarks.remove(at: index)
        }
    }
    
    private func toggleRead(_ bookmark: Bookmark) {
        bookmark.isRead.toggle()
        viewModel.bookmarkRepository.update(bookmark)
    }
    
    private func markAllAsRead() async {
        for bookmark in displayedBookmarks where !bookmark.isRead {
            bookmark.isRead = true
            viewModel.bookmarkRepository.update(bookmark)
        }
        await viewModel.refresh()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AllBookmarksView(
            viewModel: HomeViewModel(
                bookmarkRepository: PreviewMockRepository.shared,
                categoryRepository: PreviewMockCategoryRepository.shared
            )
        )
    }
}
