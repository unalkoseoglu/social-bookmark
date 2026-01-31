import SwiftUI

/// Filtrelenmiş bookmarkları gösteren view
/// Quick Access butonlarından açılır
struct FilteredBookmarksView: View {
    // MARK: - Properties

    let filter: QuickFilter
    @Bindable var viewModel: HomeViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredBookmarks: [Bookmark] {
        let base: [Bookmark]
    

        switch filter {
        case .unread:
            base = viewModel.allBookmarks.filter { !$0.isRead }
        case .favorites:
            base = viewModel.allBookmarks.filter { $0.isFavorite }
        case .today:
            base = viewModel.allBookmarks.filter { Calendar.current.isDateInToday($0.createdAt) }
        }

        guard !searchText.isEmpty else { return base }

        return base.filter { bookmark in
            bookmark.title.localizedCaseInsensitiveContains(searchText) ||
            bookmark.note.localizedCaseInsensitiveContains(searchText) ||
            bookmark.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if filteredBookmarks.isEmpty {
                    emptyStateView
                } else {
                    bookmarkList
                }
            }
            .navigationTitle(filter.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("filtered.search_prompt"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Bookmark List

    private var bookmarkList: some View {
        UnifiedBookmarkList(
            bookmarks: filteredBookmarks,
            viewModel: viewModel,
            emptyTitle: String(localized: emptyTitle),
            emptySubtitle: String(localized: emptyDescription),
            emptyIcon: filter.icon
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey(stringLiteral: String(localized: emptyTitle)), systemImage: filter.icon)
        } description: {
            Text(String(localized: emptyDescription))
        } actions: {
            Button { dismiss() } label: {
                Text("common.go_back")
            }
        }
    }

    // MARK: - Computed Properties

    private var emptyTitle: String.LocalizationValue {
        switch filter {
        case .unread: return "filtered.empty.unread.title"
        case .favorites: return "filtered.empty.favorites.title"
        case .today: return "filtered.empty.today.title"
        }
    }

    private var emptyDescription: String.LocalizationValue {
        switch filter {
        case .unread: return "filtered.empty.unread.desc"
        case .favorites: return "filtered.empty.favorites.desc"
        case .today: return "filtered.empty.today.desc"
        }
    }
}
