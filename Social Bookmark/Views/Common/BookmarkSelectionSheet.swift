import SwiftUI
import SwiftData

struct BookmarkSelectionSheet: View {
    let currentBookmark: Bookmark
    @Binding var selectedBookmarkIds: [UUID]
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]
    
    @State private var searchText = ""
    @State private var tempSelectedIds: Set<UUID> = []
    
    var filteredBookmarks: [Bookmark] {
        let query = searchText.lowercased()
        return bookmarks.filter { bookmark in
            // Exclude self
            guard bookmark.id != currentBookmark.id else { return false }
            
            // Exclude already linked (if passed in existing links, but logic might vary)
            // For now, we allow selecting any other bookmark.
            // If already linked, it will be pre-selected.
            
            guard !query.isEmpty else { return true }
            
            return bookmark.title.lowercased().contains(query) ||
                   bookmark.note.lowercased().contains(query) ||
                   bookmark.tags.contains { $0.lowercased().contains(query) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredBookmarks) { bookmark in
                    Button {
                        toggleSelection(for: bookmark)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bookmark.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                
                                if !bookmark.note.isEmpty {
                                    Text(bookmark.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: tempSelectedIds.contains(bookmark.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(tempSelectedIds.contains(bookmark.id) ? .blue : .gray.opacity(0.3))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "selection.search_prompt")
            .navigationTitle("selection.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") {
                        selectedBookmarkIds = Array(tempSelectedIds)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                // Initialize temp selection with existing links
                tempSelectedIds = Set(selectedBookmarkIds)
            }
        }
    }
    
    private func toggleSelection(for bookmark: Bookmark) {
        if tempSelectedIds.contains(bookmark.id) {
            tempSelectedIds.remove(bookmark.id)
        } else {
            tempSelectedIds.insert(bookmark.id)
        }
    }
}
