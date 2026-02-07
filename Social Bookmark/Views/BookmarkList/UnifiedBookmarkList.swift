import SwiftUI

/// Unified widget for listing bookmarks across the application
struct UnifiedBookmarkList: View {
    // MARK: - Properties
    
    let bookmarks: [Bookmark]
    let viewModel: HomeViewModel
    
    /// Optional field to provide complete list for stats (if 'bookmarks' is paginated)
    var totalBookmarks: [Bookmark]? = nil
    
    // Configuration
    var showSorting: Bool = false
    var isGroupedBySource: Bool = false
    var showStats: Bool = false
    
    // Pagination (Optional)
    var hasMorePages: Bool = false
    var isLoadingMore: Bool = false
    var onLoadMore: (() -> Void)? = nil
    var onRefresh: (() async -> Void)? = nil
    
    // Empty State
    var emptyTitle: String = String(localized: "library.empty.title")
    var emptySubtitle: String = String(localized: "library.empty.subtitle")
    var emptyIcon: String = "bookmark"
    
    // MARK: - Computed Properties
    
    private var groupedBookmarks: [BookmarkSource: [Bookmark]] {
        Dictionary(grouping: bookmarks, by: { $0.source })
    }
    
    private var sortedSources: [BookmarkSource] {
        BookmarkSource.allCases.filter { groupedBookmarks[$0] != nil }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if bookmarks.isEmpty && !isLoadingMore {
                emptyStateView
            } else {
                
                List {
                    
                    if showStats {
                        
                        statsSection
                    }
                    
                    if isGroupedBySource {
                        sourceGroupedSection
                    } else {
                        flatListSection
                    }
                    
                    if hasMorePages {
                        loadMoreSection
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    if let onRefresh = onRefresh {
                        await onRefresh()
                    }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var flatListSection: some View {
        Section {
            ForEach(bookmarks) { bookmark in
                bookmarkRow(bookmark)
                    .onAppear {
                        checkLoadMore(for: bookmark)
                    }
            }
        }
    }
    
    private var sourceGroupedSection: some View {
        ForEach(sortedSources, id: \.self) { source in
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
                        .font(.caption)
                }
            }
        }
    }
    
    private var statsSection: some View {
        let statsList = totalBookmarks ?? bookmarks
        
        return Section {
            HStack(spacing: 20) {
                statItem(
                    count: statsList.count,
                    label: String(localized: "all.stats.total"),
                    color: .primary
                )
                
                Divider()
                
                statItem(
                    count: statsList.filter { $0.isRead }.count,
                    label: String(localized: "all.stats.read"),
                    color: .green
                )
                
                Divider()
                
                statItem(
                    count: statsList.filter { !$0.isRead }.count,
                    label: String(localized: "all.stats.unread"),
                    color: .orange
                )
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    private func statItem(count: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var loadMoreSection: some View {
        Section {
            HStack {
                Spacer()
                if isLoadingMore {
                    ProgressView()
                    Text(String(localized: "common.loading"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }
    
    // MARK: - Row Component
    
    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
       
        NavigationLink {
            BookmarkDetailView(
                bookmark: bookmark,
                viewModel: viewModel
            )
        } label: {
            
            EnhancedBookmarkRow(
                bookmark: bookmark,
                category: viewModel.categories.first { $0.id == bookmark.categoryId }
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    viewModel.deleteBookmark(bookmark)
                }
            } label: {
                Label(String(localized: "common.delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation {
                    viewModel.toggleReadStatus(bookmark)
                }
            } label: {
                Label(
                    bookmark.isRead ? String(localized: "bookmarkDetail.markUnread") : String(localized: "bookmarkDetail.markRead"),
                    systemImage: bookmark.isRead ? "circle" : "checkmark.circle"
                )
            }
            .tint(bookmark.isRead ? .orange : .green)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: emptyIcon)
        } description: {
            Text(emptySubtitle)
        }
    }
    
    // MARK: - Helpers
    
    private func checkLoadMore(for bookmark: Bookmark) {
        guard let onLoadMore = onLoadMore, hasMorePages, !isLoadingMore else { return }
        
        // Threshold: Last 5 items
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }),
           index >= bookmarks.count - 5 {
            onLoadMore()
        }
    }
}
