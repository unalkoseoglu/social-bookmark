import SwiftUI

/// Tüm bookmarkları listeleyen view
/// "Tümünü Gör" butonundan açılır
struct AllBookmarksView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    
    @State private var searchText = ""
    @State private var selectedSource: BookmarkSource?
    @State private var sortOrder: SortOrder = .newest
    @State private var showingFilters = false
    
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
    
    // MARK: - Filtered & Sorted Bookmarks
    
    private var filteredBookmarks: [Bookmark] {
        var bookmarks = viewModel.allBookmarks
        
        // Kaynak filtresi
        if let source = selectedSource {
            bookmarks = bookmarks.filter { $0.source == source }
        }
        
        // Arama filtresi
        if !searchText.isEmpty {
            bookmarks = bookmarks.filter { bookmark in
                bookmark.title.localizedCaseInsensitiveContains(searchText) ||
                bookmark.note.localizedCaseInsensitiveContains(searchText) ||
                bookmark.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Sıralama
        switch sortOrder {
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
    }
    
    // Kaynak bazlı gruplama
    private var groupedBookmarks: [BookmarkSource: [Bookmark]] {
        Dictionary(grouping: filteredBookmarks, by: { $0.source })
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if filteredBookmarks.isEmpty {
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
        .sheet(isPresented: $showingFilters) {
            filterSheet
        }
    }
    
    // MARK: - Bookmark List
    
    private var bookmarkList: some View {
        List {
            // Stats header
            Section {
                statsHeader
            }
            
            // Source filter chips
            Section {
                sourceFilterChips
            }
            
            // Bookmarks
            if sortOrder == .source {
                // Kaynak bazlı gruplu liste
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
            } else {
                // Düz liste
                Section {
                    ForEach(filteredBookmarks) { bookmark in
                        bookmarkRow(bookmark)
                    }
                } header: {
                    Text("all.section.bookmarks")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(filteredBookmarks.count)")
                    .font(.title)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
                
                Text("all.stats.total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
                .frame(height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(filteredBookmarks.filter { !$0.isRead }.count)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
                
                Text("all.stats.unread")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Sort indicator
            Menu {
                ForEach(SortOrder.allCases) { order in
                    Button {
                        withAnimation {
                            sortOrder = order
                        }
                    } label: {
                        Label(order.title, systemImage: order.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: sortOrder.icon)
                    Text(sortOrder.title)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Source Filter Chips
    
    private var sourceFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All sources
                FilterChip(
                    title: String(localized: "all.filter.all"),
                    icon: "square.grid.2x2",
                    isSelected: selectedSource == nil
                ) {
                    withAnimation {
                        selectedSource = nil
                    }
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
                            withAnimation {
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
                deleteBookmark(bookmark)
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
                    markAllAsRead()
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
    
    // MARK: - Actions
    
    private func deleteBookmark(_ bookmark: Bookmark) {
        withAnimation {
            viewModel.bookmarkRepository.delete(bookmark)
            viewModel.refresh()
        }
    }
    
    private func toggleRead(_ bookmark: Bookmark) {
        withAnimation {
            bookmark.isRead.toggle()
            viewModel.bookmarkRepository.update(bookmark)
            viewModel.refresh()
        }
    }
    
    private func markAllAsRead() {
        for bookmark in filteredBookmarks where !bookmark.isRead {
            bookmark.isRead = true
            viewModel.bookmarkRepository.update(bookmark)
        }
        viewModel.refresh()
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

// MARK: - All Bookmarks Row

struct AllBookmarksRow: View {
    let bookmark: Bookmark
    
    var body: some View {
        HStack(spacing: 12) {
            // Kaynak emoji
            Text(bookmark.source.emoji)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(bookmark.source.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(bookmark.source.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text(bookmark.relativeDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if bookmark.hasTags {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.caption2)
                            Text("\(bookmark.tags.count)")
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if !bookmark.isRead {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                }
                
                if bookmark.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(.vertical, 4)
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
