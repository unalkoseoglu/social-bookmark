import SwiftUI

/// Kategori detay ekranı - kategorideki bookmarkları listeler
struct CategoryDetailView: View {
    // MARK: - Properties
    
    let category: Category
    @Bindable var viewModel: HomeViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var bookmarks: [Bookmark] = []
    @State private var searchText = ""
    
    private var filteredBookmarks: [Bookmark] {
        if searchText.isEmpty {
            return bookmarks
        }
        let query = searchText.lowercased()
        return bookmarks.filter {
            $0.title.lowercased().contains(query) ||
            $0.note.lowercased().contains(query)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    emptyStateView
                } else {
                    bookmarksList
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("categoryDetail.search_prompt"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadBookmarks()
            }
        }
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: category.icon)
                .font(.system(size: 60))
                .foregroundStyle(category.color.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("categoryDetail.empty_title")
                    .font(.headline)
                Text("categoryDetail.empty_desc")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
    }
    
    private var bookmarksList: some View {
        List {
            ForEach(filteredBookmarks) { bookmark in
                NavigationLink {
                    BookmarkDetailView(bookmark: bookmark, viewModel: viewModel)
                } label: {
                    EnhancedBookmarkRow(bookmark: bookmark)
                }
            }
            .onDelete(perform: deleteBookmarks)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func loadBookmarks() {
        bookmarks = viewModel.bookmarks(for: category)
    }
    
    private func deleteBookmarks(at offsets: IndexSet) {
        for index in offsets {
            let bookmark = filteredBookmarks[index]

                    viewModel.deleteBookmark(bookmark)

               }
            
        loadBookmarks()
    }
}

// MARK: - Category Bookmark Row

struct CategoryBookmarkRow: View {
    let bookmark: Bookmark
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: bookmark.source.systemIcon)
                .foregroundStyle(bookmark.source.color)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(bookmark.source.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(bookmark.source.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text(bookmark.relativeDate)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            if bookmark.isRead {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    CategoryDetailView(
        category: Category(name: "Test", icon: "star.fill", colorHex: "#FFD60A"),
        viewModel: HomeViewModel(
            bookmarkRepository: PreviewMockRepository.shared,
            categoryRepository: PreviewMockCategoryRepository.shared
        )
    )
}
