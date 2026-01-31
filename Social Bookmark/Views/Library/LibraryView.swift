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
    
    @State private var selectedSegment: LibrarySegment = .all
    @State private var selectedCategory: Category?
    @State private var showingCategoryManagement = false
    @State private var showingAnalytics = false
    @State private var showingUncategorized = false
    @State private var showingFavorites = false
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedSource: BookmarkSource?
    @State private var sortOrder: SortOrder = .newest
    @State private var filteredResults: [Bookmark] = []
    
    // MARK: - Pagination State
    
    @State private var displayedBookmarks: [Bookmark] = []
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
    
    enum LibrarySegment: String, CaseIterable {
        case all = "all"
        case categories = "categories"
        case sources = "sources"
        
        var title: String {
            switch self {
            case .all: return String(localized: "library.segment.all")
            case .categories: return String(localized: "library.segment.categories")
            case .sources: return String(localized: "library.segment.sources")
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Segment Picker
            Picker(String(localized: "addBookmark.select"), selection: $selectedSegment) {
                ForEach(LibrarySegment.allCases, id: \.self) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            
            // Content
            switch selectedSegment {
            case .all:
                allBookmarksContent
            case .categories:
                categoriesContent
            case .sources:
                sourcesContent
            }
        }
        .navigationTitle(String(localized: "library.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
                    if selectedSegment == .all {
                        Menu {
                            Section(String(localized: "all.menu.sort")) {
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
                    
                    Button {
                        showingAnalytics = true
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    
                    if selectedSegment == .categories {
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
                        displayedBookmarks = Array(filteredResults.prefix(count))
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
        
        let results = await Task.detached(priority: .userInitiated) {
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
            
            return bookmarks
        }.value
        
        await MainActor.run {
            self.filteredResults = results
        }
    }
    
    // MARK: - All Bookmarks Content
    
    private var allBookmarksContent: some View {
        UnifiedBookmarkList(
            bookmarks: displayedBookmarks,
            viewModel: viewModel,
            isGroupedBySource: sortOrder == .source,
            showStats: true,
            hasMorePages: hasMorePages,
            isLoadingMore: isLoadingMore,
            onLoadMore: { loadMoreBookmarks() },
            emptyTitle: String(localized: "library.empty.title"),
            emptySubtitle: String(localized: "library.empty.subtitle"),
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
                        title: String(localized: "library.categories.empty.title"),
                        subtitle: String(localized: "library.categories.empty.subtitle")
                    )
                    
                    Button {
                        viewModel.createDefaultCategories()
                    } label: {
                        Label(String(localized: "library.action.create_default_categories"), systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                        spacing: 12
                    ) {
                        // Favoriler (Her zaman en başta)
                        FavoritesCard(count: viewModel.favoritesCount) {
                            showingFavorites = true
                        }
                        
                        ForEach(viewModel.categories) { category in
                            LibraryCategoryCard(
                                category: category,
                                count: viewModel.bookmarkCount(for: category)
                            ) {
                                selectedCategory = category
                            }
                        }
                        
                        // Kategorisiz
                        if viewModel.uncategorizedCount > 0 {
                            UncategorizedCard(count: viewModel.uncategorizedCount) {
                                showingUncategorized = true
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
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
                displayedBookmarks.append(contentsOf: newBookmarks)
                currentPage += 1
                isLoadingMore = false
            }
        }
    }
    
    private func loadMoreIfNeeded(currentBookmark: Bookmark) {
        guard let index = displayedBookmarks.firstIndex(where: { $0.id == currentBookmark.id }) else { return }
        
        if index >= displayedBookmarks.count - 5 {
            loadMoreBookmarks()
        }
    }

    private var hasMorePages: Bool {
        displayedBookmarks.count < filteredResults.count
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
                
                Text(String(localized: "common.favorites"))
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
                bookmarks: filteredBookmarks,
                viewModel: viewModel,
                emptyTitle: String(localized: "common.favorites"),
                emptySubtitle: String(localized: "library.empty.subtitle"),
                emptyIcon: "star"
            )
            .navigationTitle(String(localized: "common.favorites"))
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
                
                Text(String(localized: "common.uncategorized"))
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
                bookmarks: filteredBookmarks,
                viewModel: viewModel,
                emptyTitle: String(localized: "common.uncategorized"),
                emptySubtitle: String(localized: "library.empty.subtitle"),
                emptyIcon: "tray"
            )
            .navigationTitle(String(localized: "common.uncategorized"))
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
