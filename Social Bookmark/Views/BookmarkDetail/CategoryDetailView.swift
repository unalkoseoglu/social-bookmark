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
            .searchable(text: $searchText, prompt: "Ara...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") {
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
                .foregroundStyle(category.color)
            
            Text("Bu kategoride henüz bookmark yok")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Bookmark eklerken veya düzenlerken bu kategoriyi seçebilirsin")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var bookmarksList: some View {
        List {
            // Header
            Section {
                HStack(spacing: 16) {
                    Image(systemName: category.icon)
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(category.color)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(bookmarks.count) bookmark")
                            .font(.headline)
                        
                        let unread = bookmarks.filter { !$0.isRead }.count
                        if unread > 0 {
                            Text("\(unread) okunmadı")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Bookmarklar
            Section {
                ForEach(filteredBookmarks) { bookmark in
                    NavigationLink {
                        BookmarkDetailView(
                            bookmark: bookmark,viewModel: viewModel,
                        )
                    } label: {
                        CategoryBookmarkRow(bookmark: bookmark)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            removeFromCategory(bookmark)
                        } label: {
                            Label("Kaldır", systemImage: "folder.badge.minus")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleRead(bookmark)
                        } label: {
                            Label(
                                bookmark.isRead ? "Okunmadı" : "Okundu",
                                systemImage: bookmark.isRead ? "circle" : "checkmark.circle.fill"
                            )
                        }
                        .tint(bookmark.isRead ? .orange : .green)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Actions
    
    private func loadBookmarks() {
        bookmarks = viewModel.bookmarks(for: category)
    }
    
    private func removeFromCategory(_ bookmark: Bookmark) {
        bookmark.categoryId = nil
        viewModel.bookmarkRepository.update(bookmark)
        loadBookmarks()
        viewModel.refresh()
    }
    
    private func toggleRead(_ bookmark: Bookmark) {
        bookmark.isRead.toggle()
        viewModel.bookmarkRepository.update(bookmark)
    }
}

// MARK: - Category Bookmark Row

struct CategoryBookmarkRow: View {
    let bookmark: Bookmark
    
    var body: some View {
        HStack(spacing: 12) {
            // Kaynak emoji
            Text(bookmark.source.emoji)
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
