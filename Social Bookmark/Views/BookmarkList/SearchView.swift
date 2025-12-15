import SwiftUI

/// Bookmark arama ekranı
/// Header'daki arama butonundan açılır
struct SearchView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedScope: SearchScope = .all
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - Search Scope
    
    enum SearchScope: String, CaseIterable, Identifiable {
        case all = "all"
        case title = "title"
        case notes = "notes"
        case tags = "tags"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .all: return String(localized: "search.scope.all")
            case .title: return String(localized: "search.scope.title")
            case .notes: return String(localized: "search.scope.notes")
            case .tags: return String(localized: "search.scope.tags")
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResults: [Bookmark] {
        guard !searchText.isEmpty else { return [] }
        
        let query = searchText.lowercased()
        
        return viewModel.allBookmarks.filter { bookmark in
            switch selectedScope {
            case .all:
                return bookmark.title.localizedCaseInsensitiveContains(query) ||
                       bookmark.note.localizedCaseInsensitiveContains(query) ||
                       bookmark.tags.contains { $0.localizedCaseInsensitiveContains(query) } ||
                       (bookmark.url?.localizedCaseInsensitiveContains(query) ?? false)
                
            case .title:
                return bookmark.title.localizedCaseInsensitiveContains(query)
                
            case .notes:
                return bookmark.note.localizedCaseInsensitiveContains(query)
                
            case .tags:
                return bookmark.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }
    }
    
    // Recent searches (could be persisted)
    @State private var recentSearches: [String] = []
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Scope picker
                scopePicker
                
                // Content
                if searchText.isEmpty {
                    suggestionsView
                } else if searchResults.isEmpty {
                    noResultsView
                } else {
                    resultsListView
                }
            }
            .navigationTitle(Text("search.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isSearchFocused = true
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField(String(localized: "search.placeholder"), text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        if !searchText.isEmpty {
                            addToRecentSearches(searchText)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Scope Picker
    
    private var scopePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchScope.allCases) { scope in
                    Button {
                        withAnimation {
                            selectedScope = scope
                        }
                    } label: {
                        Text(scope.title)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedScope == scope ? Color.blue : Color(.systemGray6))
                            .foregroundStyle(selectedScope == scope ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Suggestions View
    
    private var suggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Recent searches
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("search.recent")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("search.clear") {
                                recentSearches.removeAll()
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                        
                        FlowLayout(spacing: 8) {
                            ForEach(recentSearches, id: \.self) { search in
                                Button {
                                    searchText = search
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.caption)
                                        Text(search)
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
                    }
                }
                
                // Popular tags
                if !viewModel.popularTags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("search.popular_tags")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.popularTags.prefix(10), id: \.self) { tag in
                                Button {
                                    searchText = tag
                                    selectedScope = .tags
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "tag.fill")
                                            .font(.caption)
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
                    }
                }
                
                // Source shortcuts
                VStack(alignment: .leading, spacing: 12) {
                    Text("search.browse_by_source")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(BookmarkSource.allCases) { source in
                            let count = viewModel.allBookmarks.filter { $0.source == source }.count
                            if count > 0 {
                                SourceShortcutCard(source: source, count: count) {
                                    searchText = source.displayName
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - No Results View
    
    private var noResultsView: some View {
        ContentUnavailableView {
            Label("search.no_results.title", systemImage: "magnifyingglass")
        } description: {
            Text("search.no_results.desc \(searchText)")
        } actions: {
            Button {
                searchText = ""
            } label: {
                Text("search.try_again")
            }
        }
    }
    
    // MARK: - Results List View
    
    private var resultsListView: some View {
        List {
            Section {
                Text("search.results_count \(searchResults.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(searchResults) { bookmark in
                NavigationLink {
                    BookmarkDetailView(
                        bookmark: bookmark,
                        repository: viewModel.bookmarkRepository
                    )
                } label: {
                    SearchResultRow(
                        bookmark: bookmark,
                        searchText: searchText,
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
            
            // Eşleşen içeriği göster
            if scope == .notes || scope == .all, !bookmark.note.isEmpty {
                if let matchRange = bookmark.note.range(of: searchText, options: .caseInsensitive) {
                    let startIndex = bookmark.note.index(matchRange.lowerBound, offsetBy: -20, limitedBy: bookmark.note.startIndex) ?? bookmark.note.startIndex
                    let endIndex = bookmark.note.index(matchRange.upperBound, offsetBy: 40, limitedBy: bookmark.note.endIndex) ?? bookmark.note.endIndex
                    let snippet = String(bookmark.note[startIndex..<endIndex])
                    
                    Text("...\(snippet)...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Etiketler
            if scope == .tags || scope == .all, bookmark.hasTags {
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
            
            // Meta bilgi
            HStack(spacing: 6) {
                Text(bookmark.source.displayName)
                Text("•")
                Text(bookmark.relativeDate)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: .unspecified
            )
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: width, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    SearchView(
        viewModel: HomeViewModel(
            bookmarkRepository: PreviewMockRepository.shared,
            categoryRepository: PreviewMockCategoryRepository.shared
        )
    )
}
