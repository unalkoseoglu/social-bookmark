//
//  LibraryView.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 18.12.2025.
//

import SwiftUI

/// Kütüphane ekranı
/// Tüm bookmarklar ve kategoriler burada listelenir
struct LibraryView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    @Binding var selectedTab: AppTab
    @EnvironmentObject private var sessionStore: SessionStore
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchText = ""
    @State private var categorySearchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedSource: BookmarkSource?
    @State private var sortOrder: SortOrder = .newest
    @State private var filteredResults: [Bookmark] = []
    
    // Sheet & Navigation States
    @State private var selectedCategory: Category?
    @State private var showingCategoryManagement = false
    @State private var showingAnalytics = false
    @State private var showingUncategorized = false
    @State private var showingFavorites = false
    

    
    // MARK: - Pagination State
    
    @State private var displayedBookmarks: [BookmarkDisplayModel] = []
    @State private var currentPage = 0
    @State private var isLoadingMore = false
    private let itemsPerPage = 20
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case newest = "newest"
        case oldest = "oldest"
        case alphabetical = "alphabetical"
        case source = "source"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .newest: return LanguageManager.shared.localized("all.sort.newest")
            case .oldest: return LanguageManager.shared.localized("all.sort.oldest")
            case .alphabetical: return LanguageManager.shared.localized("all.sort.alphabetical")
            case .source: return LanguageManager.shared.localized("all.sort.source")
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
    
    enum LibrarySegment: String, CaseIterable {
        case all = "all"
        case categories = "categories"
        case sources = "sources"
        
        var title: String {
            switch self {
            case .all: return LanguageManager.shared.localized("library.segment.all")
            case .categories: return LanguageManager.shared.localized("library.segment.categories")
            case .sources: return LanguageManager.shared.localized("library.segment.sources")
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            segmentPicker
            
            if viewModel.librarySegment == .categories {
                categorySearchBar
            }
            
            contentView
        }
        .navigationTitle(LanguageManager.shared.localized("library.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Back button - Ana Sayfa'ya döner
            // Back button - Ana Sayfa'ya döner
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    selectedTab = .home
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .font(.body)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    if viewModel.librarySegment == .all {
                        Menu {
                            Section(LanguageManager.shared.localized("all.menu.sort")) {
                                ForEach(SortOrder.allCases) { order in
                                    Button {
                                        withAnimation { sortOrder = order }
                                    } label: {
                                        Label(order.title, systemImage: sortOrder == order ? "checkmark" : order.icon)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                    
                    if viewModel.librarySegment == .categories {
                        Menu {
                            Section(LanguageManager.shared.localized("all.menu.sort")) {
                                ForEach(HomeViewModel.CategorySortOrder.allCases) { order in
                                    Button {
                                        withAnimation { viewModel.categorySortOrder = order }
                                    } label: {
                                        Label(order.title, systemImage: viewModel.categorySortOrder == order ? "checkmark" : "arrow.up.arrow.down")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                    
                    Button {
                        showingAnalytics = true
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    
                    if viewModel.librarySegment == .categories {
                        Button {
                            showingCategoryManagement = true
                        } label: {
                            Image(systemName: "folder.badge.gearshape")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAnalytics) {
            AnalyticsView(modelContext: modelContext, homeViewModel: viewModel)
        }
        .sheet(isPresented: $showingUncategorized) {
            UncategorizedBookmarksView(viewModel: viewModel)
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesBookmarksView(viewModel: viewModel)
                .environmentObject(sessionStore)
        }
        .sheet(item: $selectedCategory) { category in
            CategoryDetailView(category: category, viewModel: viewModel)
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showingCategoryManagement) {
            NavigationStack {
                CategoriesManagementView(viewModel: viewModel)
                    .environmentObject(sessionStore)
            }
        }
        .task {
            // Sadece ilk açılışta veya veriler boşsa yükle
            if displayedBookmarks.isEmpty {
                await updateFilteredBookmarks()
                loadInitialPage()
            }
        }
        .onChange(of: viewModel.bookmarks) { _, _ in
            Task {
                await updateFilteredBookmarks()
                // Eğer liste zaten doluysa, agresif bir resetleme yapma
                // Yeni veriler updateFilteredBookmarks ile filteredResults'a girdi
                // displayedBookmarks'ı güncelle ama sayfa yapısını bozma
                await MainActor.run {
                    if !displayedBookmarks.isEmpty {
                        // Basit bir güncelleme: Mevcut sayfa kadar veriyi yenile
                        let count = displayedBookmarks.count
                        let newSource = filteredResults.prefix(count)
                        displayedBookmarks = newSource.map { bookmark in
                            BookmarkDisplayModel(bookmark: bookmark, category: viewModel.categories.first { cat in cat.id == bookmark.categoryId })
                        }
                    } else {
                        loadInitialPage()
                    }
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if searchText == newValue {
                    debouncedSearchText = newValue
                    await updateFilteredBookmarks()
                    loadInitialPage()
                }
            }
        }
        .onChange(of: selectedSource) { _, _ in
            Task {
                await updateFilteredBookmarks()
                loadInitialPage()
            }
        }
        .onChange(of: sortOrder) { _, _ in
            Task {
                await updateFilteredBookmarks()
                loadInitialPage()
            }
        }
    }
    
    // MARK: - Logic
    
    private func updateFilteredBookmarks() async {
        let currentBookmarks = viewModel.allBookmarks
        let currentSearch = debouncedSearchText
        let currentSource = selectedSource
        let currentSort = sortOrder
        
        // SwiftData modelleri (PersistentModel) Sendable değildir. 
        // Bu yüzden Task.detached içinde kullanılamazlar.
        // Filtreleme işlemini MainActor üzerinde gerçekleştiriyoruz.
        var bookmarks = currentBookmarks
        
        if let source = currentSource {
            bookmarks = bookmarks.filter { $0.source == source }
        }
        
        if !currentSearch.isEmpty {
            let searchLower = currentSearch.lowercased()
            bookmarks = bookmarks.filter { bookmark in
                bookmark.title.lowercased().contains(searchLower) ||
                bookmark.note.lowercased().contains(searchLower) ||
                bookmark.tags.contains { $0.lowercased().contains(searchLower) }
            }
        }
        
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
        
        self.filteredResults = bookmarks
    }
    
    // MARK: - All Bookmarks Content
    
    private var allBookmarksContent: some View {
        UnifiedBookmarkList(
            bookmarks: displayedBookmarks,
            viewModel: viewModel,
            totalBookmarks: filteredResults.map { bookmark in
                BookmarkDisplayModel(bookmark: bookmark, category: viewModel.categories.first { cat in cat.id == bookmark.categoryId })
            },
            isGroupedBySource: sortOrder == .source,
            showStats: true,
            hasMorePages: hasMorePages,
            isLoadingMore: isLoadingMore,
            onLoadMore: { loadMoreBookmarks() },
            emptyTitle: LanguageManager.shared.localized("library.empty.title"),
            emptySubtitle: LanguageManager.shared.localized("library.empty.subtitle"),
            emptyIcon: "bookmark"
        )
    }
    
    // Kaynak bazlı gruplama silindi - UnifiedBookmarkList içinde yapılıyor
    
    // MARK: - Categories Content
    
    private var categoriesContent: some View {
        Group {
            if viewModel.categories.isEmpty {
                VStack(spacing: 16) {
                    emptyStateView(
                        icon: "folder",
                        title: LanguageManager.shared.localized("library.categories.empty.title"),
                        subtitle: LanguageManager.shared.localized("library.categories.empty.subtitle")
                    )
                    
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Category Stats Header
                        categoryStatsHeader
                            .padding(.top, 8)
                        
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                            spacing: 12
                        ) {
                            // Favoriler (Sadece arama yoksa göster)
                            if categorySearchText.isEmpty {
                                FavoritesCard(count: viewModel.favoritesCount) {
                                    showingFavorites = true
                                }
                            }
                            
                            ForEach(sortedFilteredCategories) { category in
                                LibraryCategoryCard(
                                    category: category,
                                    count: viewModel.bookmarkCount(for: category)
                                ) {
                                    selectedCategory = category
                                }
                            }
                            
                            // Kategorisiz (Sadece arama yoksa ve varsa göster)
                            if categorySearchText.isEmpty && viewModel.uncategorizedCount > 0 {
                                UncategorizedCard(count: viewModel.uncategorizedCount) {
                                    showingUncategorized = true
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
    
    // MARK: - Category Helpers
    
    private var categoryStatsHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.categories.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(LanguageManager.shared.localized("library.stats.category_count"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.allBookmarks.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(LanguageManager.shared.localized("library.stats.bookmark_count"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var sortedFilteredCategories: [Category] {
        var result = viewModel.sortedCategories
        
        // Search filter
        if !categorySearchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(categorySearchText) }
        }
        
        return result
    }
    
    // MARK: - Sources Content
    
    private var sourcesContent: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(viewModel.sourcesWithCounts, id: \.source) { item in
                    SourceCard(source: item.source, count: item.count)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Empty State
    
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(subtitle)
        }
    }
    
    // MARK: - Pagination Methods
    
    private func loadInitialPage() {
        currentPage = 0
        displayedBookmarks = []
        loadMoreBookmarks()
    }
    
    private func loadMoreBookmarks() {
        guard !isLoadingMore else { return }
        
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredResults.count)
        
        guard startIndex < filteredResults.count else { return }
        
        isLoadingMore = true
        
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            await MainActor.run {
                let newBookmarks = Array(filteredResults[startIndex..<endIndex])
                let mapped = newBookmarks.map { bookmark in
                     BookmarkDisplayModel(bookmark: bookmark, category: viewModel.categories.first { cat in cat.id == bookmark.categoryId })
                }
                displayedBookmarks.append(contentsOf: mapped)
                currentPage += 1
                isLoadingMore = false
            }
        }
    }
    
    private func loadMoreIfNeeded(currentBookmark: BookmarkDisplayModel) {
        guard let index = displayedBookmarks.firstIndex(where: { $0.id == currentBookmark.id }) else { return }
        
        if index >= displayedBookmarks.count - 5 {
            loadMoreBookmarks()
        }
    }

    private var hasMorePages: Bool {
        displayedBookmarks.count < filteredResults.count
    }
}

// MARK: - SearchBar Component

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: {
                    self.text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - LibraryView Extensions

extension LibraryView {
    private var segmentPicker: some View {
        Picker(LanguageManager.shared.localized("addBookmark.select"), selection: $viewModel.librarySegment) {
            ForEach(LibrarySegment.allCases, id: \.self) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }
    
    private var categorySearchBar: some View {
        SearchBar(text: $categorySearchText, placeholder: LanguageManager.shared.localized("category.icons.search"))
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.librarySegment {
        case .all:
            allBookmarksContent
        case .categories:
            categoriesContent
        case .sources:
            sourcesContent
        }
    }
}



// MARK: - Library Category Card

struct LibraryCategoryCard: View {
    let category: Category
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(category.color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }
                
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Favorites Card

struct FavoritesCard: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }
                
                Text(LanguageManager.shared.localized("common.favorites"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct FavoritesBookmarksView: View {
    let viewModel: HomeViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    
    private var filteredBookmarks: [Bookmark] {
        viewModel.bookmarks.filter { $0.isFavorite }
    }
    
    var body: some View {
        NavigationStack {
            UnifiedBookmarkList(
                bookmarks: filteredBookmarks.map { bookmark in
                    BookmarkDisplayModel(bookmark: bookmark, category: viewModel.categories.first { cat in cat.id == bookmark.categoryId })
                },
                viewModel: viewModel,
                totalBookmarks: filteredBookmarks.map { bookmark in
                    BookmarkDisplayModel(bookmark: bookmark, category: viewModel.categories.first { cat in cat.id == bookmark.categoryId })
                },
                emptyTitle: LanguageManager.shared.localized("common.favorites"),
                emptySubtitle: LanguageManager.shared.localized("library.empty.subtitle"),
                emptyIcon: "star"
            )
            .navigationTitle(LanguageManager.shared.localized("common.favorites"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Uncategorized Card

struct UncategorizedCard: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }
                
                Text(LanguageManager.shared.localized("common.uncategorized"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct UncategorizedBookmarksView: View {
    let viewModel: HomeViewModel
    
    private var filteredBookmarks: [Bookmark] {
        viewModel.bookmarks.filter { $0.categoryId == nil }
    }
    
    var body: some View {
        NavigationStack {
            UnifiedBookmarkList(
                bookmarks: filteredBookmarks.map { bookmark in
                     BookmarkDisplayModel(bookmark: bookmark, category: viewModel.categories.first { cat in cat.id == bookmark.categoryId })
                },
                viewModel: viewModel,
                totalBookmarks: filteredBookmarks.map { bookmark in
                     BookmarkDisplayModel(bookmark: bookmark, category: viewModel.categories.first { cat in cat.id == bookmark.categoryId })
                },
                emptyTitle: LanguageManager.shared.localized("common.uncategorized"),
                emptySubtitle: LanguageManager.shared.localized("library.empty.subtitle"),
                emptyIcon: "tray"
            )
            .navigationTitle(LanguageManager.shared.localized("common.uncategorized"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Source Card

struct SourceCard: View {
    let source: BookmarkSource
    let count: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(source.emoji)
                    .font(.title)
                    .frame(width: 44, height: 44)
                    .background(source.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
            }
            
            Text(source.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LibraryView(
            viewModel: HomeViewModel(
                bookmarkRepository: PreviewMockRepository.shared,
                categoryRepository: PreviewMockCategoryRepository.shared
            ),
            selectedTab: .constant(.library)
        )
    }
}
