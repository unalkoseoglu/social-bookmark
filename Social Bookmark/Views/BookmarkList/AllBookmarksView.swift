import SwiftUI

/// Tüm bookmarkları listeleyen ekran
struct AllBookmarksView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    
    @State private var searchText = ""
    @State private var sortOption: SortOption = .newest
    @State private var selectedSource: BookmarkSource?
    @State private var selectedCategory: Category?
    @State private var showOnlyUnread = false
    @State private var showOnlyFavorites = false
    
    private var filteredBookmarks: [Bookmark] {
        var result = viewModel.bookmarks
        
        // Arama filtresi
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.note.lowercased().contains(query) ||
                $0.tags.contains { $0.lowercased().contains(query) }
            }
        }
        
        // Kaynak filtresi
        if let source = selectedSource {
            result = result.filter { $0.source == source }
        }
        
        // Kategori filtresi
        if let category = selectedCategory {
            result = result.filter { $0.categoryId == category.id }
        }
        
        // Okunmadı filtresi
        if showOnlyUnread {
            result = result.filter { !$0.isRead }
        }
        
        // Favori filtresi
        if showOnlyFavorites {
            result = result.filter { $0.isFavorite }
        }
        
        // Sıralama
        switch sortOption {
        case .newest:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            result.sort { $0.createdAt < $1.createdAt }
        case .alphabetical:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .source:
            result.sort { $0.source.displayName < $1.source.displayName }
        }
        
        return result
    }
    
    private var hasActiveFilters: Bool {
        selectedSource != nil || selectedCategory != nil || showOnlyUnread || showOnlyFavorites
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if viewModel.bookmarks.isEmpty {
                emptyStateView
            } else {
                bookmarksList
            }
        }
        .navigationTitle("Tüm Bookmarklar")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Başlık, not veya etiket ara...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Henüz bookmark yok")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("İnternette bulduğun değerli içerikleri kaydetmeye başla")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var bookmarksList: some View {
        List {
            // Aktif filtreler
            if hasActiveFilters {
                activeFiltersSection
            }
            
            // İstatistik
            Section {
                HStack {
                    Label("\(filteredBookmarks.count) bookmark", systemImage: "bookmark.fill")
                    
                    Spacer()
                    
                    let unreadCount = filteredBookmarks.filter { !$0.isRead }.count
                    if unreadCount > 0 {
                        Label("\(unreadCount) okunmadı", systemImage: "circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            // Bookmark listesi
            Section {
                ForEach(filteredBookmarks) { bookmark in
                    NavigationLink {
                        BookmarkDetailView(
                            bookmark: bookmark,
                            repository: viewModel.bookmarkRepository
                        )
                    } label: {
                        AllBookmarksRow(
                            bookmark: bookmark,
                            category: categoryFor(bookmark)
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteBookmark(bookmark)
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            viewModel.toggleReadStatus(bookmark)
                        } label: {
                            Label(
                                bookmark.isRead ? "Okunmadı" : "Okundu",
                                systemImage: bookmark.isRead ? "circle" : "checkmark.circle.fill"
                            )
                        }
                        .tint(bookmark.isRead ? .orange : .green)
                        
                        Button {
                            viewModel.toggleFavorite(bookmark)
                        } label: {
                            Label(
                                bookmark.isFavorite ? "Favoriden Çıkar" : "Favorile",
                                systemImage: bookmark.isFavorite ? "star.slash" : "star.fill"
                            )
                        }
                        .tint(.yellow)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var activeFiltersSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let source = selectedSource {
                        FilterTag(
                            title: source.displayName,
                            icon: source.systemIcon,
                            color: source.color
                        ) {
                            selectedSource = nil
                        }
                    }
                    
                    if let category = selectedCategory {
                        FilterTag(
                            title: category.name,
                            icon: category.icon,
                            color: category.color
                        ) {
                            selectedCategory = nil
                        }
                    }
                    
                    if showOnlyUnread {
                        FilterTag(
                            title: "Okunmadı",
                            icon: "circle.fill",
                            color: .orange
                        ) {
                            showOnlyUnread = false
                        }
                    }
                    
                    if showOnlyFavorites {
                        FilterTag(
                            title: "Favoriler",
                            icon: "star.fill",
                            color: .yellow
                        ) {
                            showOnlyFavorites = false
                        }
                    }
                    
                    Button {
                        clearAllFilters()
                    } label: {
                        Text("Temizle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
    
    private var filterMenu: some View {
        Menu {
            // Sıralama
            Section("Sıralama") {
                Picker("Sırala", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Label(option.title, systemImage: option.icon)
                            .tag(option)
                    }
                }
            }
            
            Divider()
            
            // Kaynak filtresi
            Section("Kaynak") {
                Button {
                    selectedSource = nil
                } label: {
                    HStack {
                        Text("Tümü")
                        if selectedSource == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                ForEach(BookmarkSource.allCases) { source in
                    Button {
                        selectedSource = source
                    } label: {
                        HStack {
                            Text(source.emoji)
                            Text(source.displayName)
                            if selectedSource == source {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            // Kategori filtresi
            if !viewModel.categories.isEmpty {
                Section("Kategori") {
                    Button {
                        selectedCategory = nil
                    } label: {
                        HStack {
                            Text("Tümü")
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    ForEach(viewModel.categories) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(category.color)
                                Text(category.name)
                                if selectedCategory?.id == category.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Toggle filtreler
            Toggle("Sadece Okunmamış", isOn: $showOnlyUnread)
            Toggle("Sadece Favoriler", isOn: $showOnlyFavorites)
            
            if hasActiveFilters {
                Divider()
                
                Button(role: .destructive) {
                    clearAllFilters()
                } label: {
                    Label("Filtreleri Temizle", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }
    
    // MARK: - Helpers
    
    private func categoryFor(_ bookmark: Bookmark) -> Category? {
        guard let categoryId = bookmark.categoryId else { return nil }
        return viewModel.categories.first { $0.id == categoryId }
    }
    
    private func clearAllFilters() {
        selectedSource = nil
        selectedCategory = nil
        showOnlyUnread = false
        showOnlyFavorites = false
    }
}

// MARK: - All Bookmarks Row

struct AllBookmarksRow: View {
    let bookmark: Bookmark
    let category: Category?
    
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
                
                HStack(spacing: 6) {
                    Text(bookmark.source.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text(bookmark.relativeDate)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    if let category = category {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 2) {
                            Image(systemName: category.icon)
                            Text(category.name)
                        }
                        .font(.caption)
                        .foregroundStyle(category.color)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                if bookmark.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
                
                if !bookmark.isRead {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Tag

struct FilterTag: View {
    let title: String
    let icon: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            
            Text(title)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
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
