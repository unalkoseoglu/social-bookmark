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
    
    var body: some View {
        NavigationStack {
            UnifiedBookmarkList(
                bookmarks: filteredBookmarks,
                viewModel: viewModel,
                emptyTitle: String(localized: "categoryDetail.empty_title"),
                emptySubtitle: String(localized: "categoryDetail.empty_desc"),
                emptyIcon: category.icon
            )
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
    
    // MARK: - Actions
    
    private func loadBookmarks() {
        bookmarks = viewModel.bookmarks(for: category)
    }
    
    // CategoryBookmarkRow and localized delete logic moved/handled by UnifiedBookmarkList
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
