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
                bookmarks: filteredBookmarks.map { BookmarkDisplayModel(bookmark: $0, category: category) },
                viewModel: viewModel,
                totalBookmarks: bookmarks.map { BookmarkDisplayModel(bookmark: $0, category: category) },
                onRefresh: {
                    try? await SyncService.shared.fetchBookmarks(categoryId: category.id)
                    await MainActor.run {
                        loadBookmarks()
                    }
                },
                emptyTitle: LanguageManager.shared.localized("categoryDetail.empty.title"),
                emptySubtitle: LanguageManager.shared.localized("categoryDetail.empty.desc"),
                emptyIcon: category.icon
            )
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text(LanguageManager.shared.localized("categoryDetail.search_prompt")))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LanguageManager.shared.localized("common.done")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadBookmarks()
                
                // ✅ Otomatik olarak sunucudan güncel verileri çek
                Task {
                    try? await SyncService.shared.fetchBookmarks(categoryId: category.id)
                    await MainActor.run {
                        loadBookmarks()
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadBookmarks() {
        let result = viewModel.bookmarks(for: category)
        print("📁 [CategoryDetailView] loadBookmarks for '\(category.name)' (ID: \(category.id))")
        print("   - Found \(result.count) bookmarks locally")
        if result.isEmpty {
            print("   - ⚠️ LOCAL LIST IS EMPTY!")
            let allCategories = viewModel.bookmarks.compactMap { $0.categoryId }
            print("   - Local bookmarks have category IDs: \(Set(allCategories))")
        }
        bookmarks = result
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
