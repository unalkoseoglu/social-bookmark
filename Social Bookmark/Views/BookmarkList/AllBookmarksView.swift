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
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if filteredBookmarks.isEmpty && !isLoadingMore {
                emptyStateView
            } else {
                bookmarkList
            }
        }
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
        List {
            // Stats Section
            statsSection
            
            // Source Filter Chips
            sourceFilterSection
            
            // Bookmarks Section
            if sortOrder == .source {
                sourceGroupedSection
            } else {
                flatListSection
            }
            
            // Load More Section
            if hasMorePages {
                loadMoreSection
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        Section {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(filteredBookmarks.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("all.stats.total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(filteredBookmarks.filter { !$0.isRead }.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("all.stats.unread")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Source Filter Section
    
    private var sourceFilterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All
                    FilterChip(
                        title: String(localized: "all.filter.all"),
                        icon: "square.grid.2x2",
                        isSelected: selectedSource == nil
                    ) {
                        selectedSource = nil
                    }
                    
                    // Individual sources
                    ForEach(BookmarkSource.allCases) { source in
                        let count = viewModel.allBookmarks.filter { $0.source == source }.count
                        if count > 0 {
                            FilterChip(
                                title: source.displayName,
                                emoji: source.emoji,
                                count: count,
                                isSelected: selectedSource == source
                            ) {
                                selectedSource = selectedSource == source ? nil : source
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
    
    // MARK: - Flat List Section
    
    private var flatListSection: some View {
        Section {
            ForEach(displayedBookmarks) { bookmark in
                bookmarkRow(bookmark)
                    .onAppear {
                        // Infinite scroll trigger
                        if bookmark.id == displayedBookmarks.last?.id {
                            loadMoreIfNeeded()
                        }
                    }
            }
        }
    }
    
    // MARK: - Source Grouped Section
    
    private var sourceGroupedSection: some View {
        ForEach(BookmarkSource.allCases.filter { groupedBookmarks[$0] != nil }, id: \.self) { source in
            Section {
                ForEach(groupedBookmarks[source] ?? []) { bookmark in
                    bookmarkRow(bookmark)
                }
            } header: {
                HStack {
                    Text(source.emoji)
                    Text(source.displayName)
                    Spacer()
                    Text("\(groupedBookmarks[source]?.count ?? 0)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Load More Section
    
    private var loadMoreSection: some View {
        Section {
            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Text("common.loading")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                Button {
                    loadMoreBookmarks()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.down.circle")
                        Text("category.icons.show_more")
                        Spacer()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Bookmark Row
    
    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        NavigationLink {
            BookmarkDetailView(
                bookmark: bookmark,
                viewModel: viewModel
            )
        } label: {
            EnhancedBookmarkRow(bookmark: bookmark)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    await deleteBookmark(bookmark)
                }
               
                
              
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggleRead(bookmark)
            } label: {
                Label(
                    bookmark.isRead ? "all.action.mark_unread" : "all.action.mark_read",
                    systemImage: bookmark.isRead ? "circle" : "checkmark.circle"
                )
            }
            .tint(bookmark.isRead ? .orange : .green)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("all.empty.title", systemImage: "bookmark")
        } description: {
            if searchText.isEmpty && selectedSource == nil {
                Text("all.empty.desc")
            } else {
                Text("all.empty.no_results")
            }
        } actions: {
            if selectedSource != nil || !searchText.isEmpty {
                Button {
                    searchText = ""
                    selectedSource = nil
                } label: {
                    Text("all.action.clear_filters")
                }
            }
        }
    }
    
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
    
    private func loadMoreIfNeeded() {
        let threshold = 5
        let remainingItems = filteredBookmarks.count - displayedBookmarks.count
        
        if remainingItems > 0 && remainingItems <= threshold && !isLoadingMore {
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

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var emoji: String? = nil
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.caption)
                }
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                
                Text(title)
                    .font(.subheadline)
                
                if let count = count {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
