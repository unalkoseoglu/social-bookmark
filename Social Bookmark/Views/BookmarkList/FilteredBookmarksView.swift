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
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: filter.icon)
                        .font(.title2)
                        .foregroundStyle(filter.color)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(filteredBookmarks.count)")
                            .font(.title)
                            .fontWeight(.bold)

                        Text(filterDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Section {
                ForEach(filteredBookmarks) { bookmark in
                    NavigationLink {
                        BookmarkDetailView(
                            bookmark: bookmark,
                            viewModel: viewModel
                        )
                    } label: {
                        FilteredBookmarkRow(bookmark: bookmark, filter: filter)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteBookmark(bookmark)
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        leadingActions(for: bookmark)
                    }
                }
            } header: {
                Text("filtered.section.bookmarks")
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func leadingActions(for bookmark: Bookmark) -> some View {
        switch filter {
        case .unread:
            Button { markAsRead(bookmark) } label: {
                Label("filtered.mark_read", systemImage: "checkmark.circle")
            }
            .tint(.green)

        case .favorites:
            Button { toggleFavorite(bookmark) } label: {
                Label("filtered.unfavorite", systemImage: "star.slash")
            }
            .tint(.orange)

        case .today:
            EmptyView()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: filter.icon)
        } description: {
            Text(emptyDescription)
        } actions: {
            Button { dismiss() } label: {
                Text("common.go_back")
            }
        }
    }

    // MARK: - Computed Properties

    private var filterDescription: String {
        switch filter {
        case .unread: return String(localized: "filtered.desc.unread")
        case .favorites: return String(localized: "filtered.desc.favorites")
        case .today: return String(localized: "filtered.desc.today")
        }
    }

    private var emptyTitle: LocalizedStringKey {
        switch filter {
        case .unread: return "filtered.empty.unread.title"
        case .favorites: return "filtered.empty.favorites.title"
        case .today: return "filtered.empty.today.title"
        }
    }

    private var emptyDescription: LocalizedStringKey {
        switch filter {
        case .unread: return "filtered.empty.unread.desc"
        case .favorites: return "filtered.empty.favorites.desc"
        case .today: return "filtered.empty.today.desc"
        }
    }

    // MARK: - Actions

    private func deleteBookmark(_ bookmark: Bookmark) {
        withAnimation {
            viewModel.bookmarkRepository.delete(bookmark)
            viewModel.refresh()
        }
    }

    private func markAsRead(_ bookmark: Bookmark) {
        withAnimation {
            bookmark.isRead = true
            viewModel.bookmarkRepository.update(bookmark)
            viewModel.refresh()
        }
    }

    private func toggleFavorite(_ bookmark: Bookmark) {
        withAnimation {
            bookmark.isFavorite.toggle()
            viewModel.bookmarkRepository.update(bookmark)
            viewModel.refresh()
        }
    }
}

// MARK: - Filtered Bookmark Row

struct FilteredBookmarkRow: View {
    let bookmark: Bookmark
    let filter: QuickFilter

    var body: some View {
        HStack(spacing: 12) {
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

                    Text("•").foregroundStyle(.tertiary)

                    Text(bookmark.relativeDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if bookmark.hasTags {
                        Text("•").foregroundStyle(.tertiary)

                        Text(bookmark.tags.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            statusIndicator
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch filter {
        case .unread:
            Circle().fill(.orange).frame(width: 10, height: 10)
        case .favorites:
            Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
        case .today:
            Image(systemName: "clock.fill").font(.caption).foregroundStyle(.blue)
        }
    }
}
