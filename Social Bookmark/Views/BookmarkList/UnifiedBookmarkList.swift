import SwiftUI

/// Unified widget for listing bookmarks across the application
struct UnifiedBookmarkList: View {
    // MARK: - Properties
    
    let bookmarks: [BookmarkDisplayModel]
    let viewModel: HomeViewModel
    
    /// Optional field to provide complete list for stats (if 'bookmarks' is paginated)
    var totalBookmarks: [BookmarkDisplayModel]? = nil
    
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
    var emptyTitle: String = LanguageManager.shared.localized("library.empty.title")
    var emptySubtitle: String = LanguageManager.shared.localized("library.empty.subtitle")
    var emptyIcon: String = "bookmark"
    
    // MARK: - Computed Properties
    
    private var groupedBookmarks: [BookmarkSource: [BookmarkDisplayModel]] {
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
                        .foregroundStyle(.primary)
                    Text(source.displayName)
                        .foregroundStyle(.primary)
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
                    label: LanguageManager.shared.localized("all.stats.total"),
                    color: .primary
                )
                
                Divider()
                
                statItem(
                    count: statsList.filter { $0.isRead }.count,
                    label: LanguageManager.shared.localized("all.stats.read"),
                    color: .green
                )
                
                Divider()
                
                statItem(
                    count: statsList.filter { !$0.isRead }.count,
                    label: LanguageManager.shared.localized("all.stats.unread"),
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
                    Text(LanguageManager.shared.localized("common.loading"))
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
    
    private func bookmarkRow(_ displayModel: BookmarkDisplayModel) -> some View {
        // Safe navigation: Sadece bookmark gerçekte varsa git
        // Yoksa row hala güvenli bir şekilde gösterilir
        Group {
            if let realBookmark = viewModel.bookmark(with: displayModel.id) {
                NavigationLink {
                    BookmarkDetailView(
                        bookmark: realBookmark, // Gerçek objeyi burada pass ediyoruz
                        viewModel: viewModel
                    )
                } label: {
                    EnhancedBookmarkRow(bookmark: displayModel)
                }
            } else {
                // Obje silinmişse veya bulunamazsa sadece row göster (tıklanamaz veya disable olabilir)
                EnhancedBookmarkRow(bookmark: displayModel)
                    .contentShape(Rectangle()) // Tıklanabilir alan ama action yok
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let realBookmark = viewModel.bookmark(with: displayModel.id) {
                Button(role: .destructive) {
                    withAnimation {
                        viewModel.deleteBookmark(realBookmark)
                    }
                } label: {
                    Label(LanguageManager.shared.localized("common.delete"), systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let realBookmark = viewModel.bookmark(with: displayModel.id) {
                Button {
                    withAnimation {
                        viewModel.toggleReadStatus(realBookmark)
                    }
                } label: {
                    Label(
                        displayModel.isRead ? LanguageManager.shared.localized("bookmarkDetail.markUnread") : LanguageManager.shared.localized("bookmarkDetail.markRead"),
                        systemImage: displayModel.isRead ? "circle" : "checkmark.circle"
                    )
                }
                .tint(displayModel.isRead ? .orange : .green)
            }
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
    
    private func checkLoadMore(for bookmark: BookmarkDisplayModel) {
        guard let onLoadMore = onLoadMore, hasMorePages, !isLoadingMore else { return }
        
        // Threshold: Last 5 items
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }),
           index >= bookmarks.count - 5 {
            onLoadMore()
        }
    }
}
