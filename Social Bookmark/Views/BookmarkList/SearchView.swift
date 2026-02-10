import SwiftUI
import Combine

/// Bookmark arama ekranı
/// Native iOS searchable modifier ile çalışır
/// Optimized: Debounced search, cached results
struct SearchView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    @Binding var selectedTab: AppTab
    @Binding var searchText: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScope: SearchScope = .all
    
    // MARK: - Optimized Search State
    
    /// Debounced search text - arama geciktirilir
    @State private var debouncedSearchText = ""
    
    /// Cached search results
    @State private var cachedResults: [Bookmark] = []
    
    /// Search task for cancellation
    @State private var searchTask: Task<Void, Never>?
    
    /// Is searching
    @State private var isSearching = false
    
    // Recent searches (could be persisted)
    @State private var recentSearches: [String] = []
    
    // Cached popular tags - sadece bir kez hesaplanır
    @State private var cachedPopularTags: [String] = []
    
    // MARK: - Search Scope
    
    enum SearchScope: String, CaseIterable, Identifiable {
        case all, title, notes, tags
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .all: return LanguageManager.shared.localized("search.scope.all")
            case .title: return LanguageManager.shared.localized("search.scope.title")
            case .notes: return LanguageManager.shared.localized("search.scope.notes")
            case .tags: return LanguageManager.shared.localized("search.scope.tags")
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Scope picker
            scopePicker
            
            // Content
            if debouncedSearchText.isEmpty {
                suggestionsView
            } else if isSearching {
                searchingView
            } else if cachedResults.isEmpty {
                noResultsView
            } else {
                resultsListView
            }
        }
        .navigationTitle(LanguageManager.shared.localized("search.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Cache popular tags once
            if cachedPopularTags.isEmpty {
                cachedPopularTags = Array(viewModel.popularTags.prefix(10))
            }
        }
        .onChange(of: searchText) { _, newValue in
            debounceSearch(newValue)
        }
        .onChange(of: selectedScope) { _, _ in
            // Scope değişince yeniden ara
            if !debouncedSearchText.isEmpty {
                performSearch(debouncedSearchText)
            }
        }
        .onSubmit(of: .search) {
            if !searchText.isEmpty {
                addToRecentSearches(searchText)
            }
        }
    }
    
    // MARK: - Debounced Search
    
    private func debounceSearch(_ query: String) {
        // Cancel previous task
        searchTask?.cancel()
        
        // Empty query - clear immediately
        if query.isEmpty {
            debouncedSearchText = ""
            cachedResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // Debounce: 300ms bekle
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                debouncedSearchText = query
                performSearch(query)
            }
        }
    }
    
    // MARK: - Perform Search
    
    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            cachedResults = []
            isSearching = false
            return
        }
        
        // Background'da ara
        Task.detached(priority: .userInitiated) {
            let results = await searchBookmarks(query: query, scope: selectedScope)
            
            await MainActor.run {
                cachedResults = results
                isSearching = false
            }
        }
    }
    
    /// Background'da arama yap
    private func searchBookmarks(query: String, scope: SearchScope) async -> [Bookmark] {
        let lowercasedQuery = query.lowercased()
        let bookmarks = viewModel.allBookmarks
        
        return bookmarks.filter { bookmark in
            switch scope {
            case .all:
                return bookmark.title.localizedStandardContains(lowercasedQuery) ||
                       bookmark.note.localizedStandardContains(lowercasedQuery) ||
                       bookmark.tags.contains { $0.localizedStandardContains(lowercasedQuery) } ||
                       (bookmark.url?.localizedStandardContains(lowercasedQuery) ?? false)
                
            case .title:
                return bookmark.title.localizedStandardContains(lowercasedQuery)
                
            case .notes:
                return bookmark.note.localizedStandardContains(lowercasedQuery)
                
            case .tags:
                return bookmark.tags.contains { $0.localizedStandardContains(lowercasedQuery) }
            }
        }
    }
    
    // MARK: - Scope Picker
    
    private var scopePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchScope.allCases) { scope in
                    ScopeButton(
                        title: scope.title,
                        isSelected: selectedScope == scope
                    ) {
                        selectedScope = scope
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Searching View
    
    private var searchingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text(LanguageManager.shared.localized("search.searching"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Suggestions View
    
    private var suggestionsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Recent searches
                if !recentSearches.isEmpty {
                    recentSearchesSection
                }
                
                // Popular tags
                if !cachedPopularTags.isEmpty {
                    popularTagsSection
                }
                
                // Source shortcuts
                sourceShortcutsSection
            }
            .padding(16)
        }
    }
    
    // MARK: - Recent Searches Section
    
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LanguageManager.shared.localized("search.recent"))
                    .font(.headline)
                
                Spacer()
                
                Button(LanguageManager.shared.localized("search.clear")) {
                    recentSearches.removeAll()
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(recentSearches, id: \.self) { search in
                    RecentSearchChip(text: search) {
                        searchText = search
                    }
                }
            }
        }
    }
    
    // MARK: - Popular Tags Section
    
    private var popularTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LanguageManager.shared.localized("search.popular_tags"))
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                ForEach(cachedPopularTags, id: \.self) { tag in
                    TagChip(tag: tag) {
                        searchText = tag
                        selectedScope = .tags
                    }
                }
            }
        }
    }
    
    // MARK: - Source Shortcuts Section
    
    private var sourceShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LanguageManager.shared.localized("search.browse_by_source"))
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(BookmarkSource.allCases) { source in
                    let count = viewModel.bookmarkSourceCount(for: source )
                    if count > 0 {
                        SourceShortcutCard(source: source, count: count) {
                            searchText = source.displayName
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - No Results View
    
    private var noResultsView: some View {
        ContentUnavailableView {
            Label(LanguageManager.shared.localized("search.no_results.title"), systemImage: "magnifyingglass")
        } description: {
            Text(LanguageManager.shared.localized("search.no_results.desc %@", debouncedSearchText))
        } actions: {
            Button {
                searchText = ""
            } label: {
                Text(LanguageManager.shared.localized("search.try_again"))
            }
        }
    }
    
    // MARK: - Results List View
    
    private var resultsListView: some View {
        List {
            Section {
                Text(LanguageManager.shared.localized("search.results_count %lld", Int64(cachedResults.count)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(cachedResults) { bookmark in
                NavigationLink {
                    BookmarkDetailView(
                        bookmark: bookmark,
                        viewModel: viewModel
                    )
                } label: {
                    SearchResultRow(
                        bookmark: bookmark,
                        searchText: debouncedSearchText,
                        scope: selectedScope
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Helpers
    
    private func addToRecentSearches(_ search: String) {
        if !recentSearches.contains(search) {
            recentSearches.insert(search, at: 0)
            if recentSearches.count > 5 {
                recentSearches.removeLast()
            }
        }
    }
}

// MARK: - Scope Button

private struct ScopeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Search Chip

private struct RecentSearchChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                Text(text)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Chip

private struct TagChip: View {
    let tag: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.caption2)
                Text(tag)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Source Shortcut Card

struct SourceShortcutCard: View {
    let source: BookmarkSource
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(source.emoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let bookmark: Bookmark
    let searchText: String
    let scope: SearchView.SearchScope
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack(spacing: 8) {
                Text(bookmark.source.emoji)
                    .font(.caption)
                
                Text(bookmark.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Spacer()
                
                if !bookmark.isRead {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
            }
            
            // Note snippet - only if relevant
            if shouldShowNoteSnippet {
                noteSnippetView
            }
            
            // Tags - only if relevant
            if shouldShowTags {
                tagsView
            }
            
            // Meta info
            metaInfoView
        }
        .padding(.vertical, 4)
    }
    
    private var shouldShowNoteSnippet: Bool {
        (scope == .notes || scope == .all) && !bookmark.note.isEmpty
    }
    
    private var shouldShowTags: Bool {
        (scope == .tags || scope == .all) && bookmark.hasTags
    }
    
    @ViewBuilder
    private var noteSnippetView: some View {
        if let snippet = createSnippet() {
            Text(snippet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
    
    private func createSnippet() -> String? {
        guard let range = bookmark.note.range(of: searchText, options: .caseInsensitive) else {
            return nil
        }
        
        let start = bookmark.note.index(range.lowerBound, offsetBy: -20, limitedBy: bookmark.note.startIndex) ?? bookmark.note.startIndex
        let end = bookmark.note.index(range.upperBound, offsetBy: 40, limitedBy: bookmark.note.endIndex) ?? bookmark.note.endIndex
        
        return "...\(bookmark.note[start..<end])..."
    }
    
    private var tagsView: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag.fill")
                .font(.caption2)
                .foregroundStyle(.blue)
            
            Text(bookmark.tags.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.blue)
                .lineLimit(1)
        }
    }
    
    private var metaInfoView: some View {
        HStack(spacing: 6) {
            Text(bookmark.source.displayName)
            Text("•")
            Text(bookmark.relativeDate)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SearchView(
            viewModel: HomeViewModel(
                bookmarkRepository: PreviewMockRepository.shared,
                categoryRepository: PreviewMockCategoryRepository.shared
            ),
            selectedTab: .constant(.search),
            searchText: .constant("")
        )
    }
}
