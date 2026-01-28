import SwiftUI

/// Ana liste ekranı - tüm bookmarkları gösterir (PERFORMANS OPTİMİZE EDİLMİŞ)
struct BookmarkListView: View {
    // MARK: - Properties
    
    /// Home ViewModel - bookmark ekleme için gerekli
    let homeViewModel: HomeViewModel
    
    /// Iç ViewModel - liste filtreleme ve işlemler
    @State private var listViewModel: BookmarkListViewModel
    
    /// Sheet state - yeni bookmark ekle
    @State private var showingAddSheet = false
    
    // MARK: - Initialization
    
    init(homeViewModel: HomeViewModel) {
        self.homeViewModel = homeViewModel
        self._listViewModel = State(
            initialValue: BookmarkListViewModel(
                repository: homeViewModel.bookmarkRepository
            )
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if listViewModel.isLoading {
                    // Yüklenirken spinner göster
                    ProgressView("common.loading")
                } else if listViewModel.isEmpty {
                    // Liste boşsa placeholder
                    emptyStateView
                } else {
                    // Liste dolu - performans optimize edilmiş
                    optimizedBookmarkList
                }
            }
            .navigationTitle("auth.welcome_title")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $listViewModel.searchText,
                prompt: Text("all.search_prompt")
            )
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingAddSheet) {
                // Modal sheet - yeni bookmark ekle
                AddBookmarkView(
                    viewModel: AddBookmarkViewModel(
                        repository: homeViewModel.bookmarkRepository,
                        categoryRepository: homeViewModel.categoryRepository
                    ),
                    onSaved: { listViewModel.loadBookmarks() }
                )
            }
            .refreshable {
                // Pull-to-refresh
                listViewModel.loadBookmarks()
            }
        }
    }
    
    // MARK: - Optimized Subviews
    
    /// Optimize edilmiş bookmark listesi - LazyVStack kullanıyor
    private var optimizedBookmarkList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(listViewModel.bookmarks) { bookmark in
                        NavigationLink(value: bookmark) {
                            OptimizedBookmarkRow(bookmark: bookmark)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            // Context menu - swipe action yerine
                            contextMenuContent(for: bookmark)
                        }
                        
                        if bookmark.id != listViewModel.bookmarks.last?.id {
                            Divider()
                                .padding(.leading, 88)
                        }
                    }
                } header: {
                    statsHeader
                        .background(Color(.systemGroupedBackground))
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(for: Bookmark.self) { bookmark in
            BookmarkDetailView(
                bookmark: bookmark,
                viewModel: homeViewModel
            )
        }
    }
    
    /// Stats header - sticky ve optimize edilmiş
    private var statsHeader: some View {
        HStack {
            Label("home.stat.total_count \(listViewModel.totalCount)", systemImage: "bookmark.fill")
            Spacer()
            Label("home.stat.unread_count \(listViewModel.unreadCount)", systemImage: "circle.fill")
                .foregroundStyle(.orange)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 8)
    }
    
    /// Context menu içeriği
    @ViewBuilder
    private func contextMenuContent(for bookmark: Bookmark) -> some View {
        // Favori toggle
        Button {
            listViewModel.toggleFavorite(bookmark)
        } label: {
            Label(
                bookmark.isFavorite ? "all.action.unfavorite" : "all.action.favorite",
                systemImage: bookmark.isFavorite ? "star.slash" : "star.fill"
            )
        }
        
        // Okundu toggle
        Button {
            listViewModel.toggleReadStatus( bookmark)
        } label: {
            Label(
                bookmark.isRead ? "all.action.mark_unread" : "all.action.mark_read",
                systemImage: bookmark.isRead ? "circle" : "checkmark.circle.fill"
            )
        }
        
        Divider()
        
        // Sil
        Button(role: .destructive) {
            listViewModel.deleteBookmark(bookmark)
        } label: {
            Label("common.delete", systemImage: "trash")
        }
    }
    
    /// Boş durum görünümü
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("home.empty.no_bookmarks")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("home.empty.no_bookmarks_desc")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { showingAddSheet = true }) {
                Label("home.action.add_first", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
    
    /// Toolbar içeriği
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Sağ üst: Yeni bookmark ekle ve ayarlar
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: { showingAddSheet = true }) {
                Image(systemName: "plus")
            }

            NavigationLink {
                SettingsView(homeViewModel: homeViewModel)
            } label: {
                Image(systemName: "gearshape")
            }
        }
        
        // Sol üst: Filtre menüsü
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                // Kaynak filtresi
                Picker("all.filter.source", selection: $listViewModel.selectedSource) {
                    Text("common.all").tag(nil as BookmarkSource?)
                    Divider()
                    ForEach(BookmarkSource.allCases) { source in
                        Text(source.displayName).tag(source as BookmarkSource?)
                    }
                }
                
                Divider()
                
                // Okunmamış filtresi
                Toggle("all.filter.only_unread", isOn: $listViewModel.showOnlyUnread)
                
                Divider()
                
                // Filtreleri temizle
                Button(action: listViewModel.clearFilters) {
                    Label("all.action.clear_filters", systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }
}

// MARK: - Optimized Bookmark Row

/// Performans için optimize edilmiş bookmark row komponenti
struct OptimizedBookmarkRow: View {
    let bookmark: Bookmark
    
    // Image cache için state
    @State private var cachedImage: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Sol: Görsel veya emoji
            thumbnailView
            
            // Orta: Metin bilgileri
            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Text(bookmark.source.displayName)
                    Text("•")
                    Text(bookmark.relativeDate)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Sağ: İkonlar
            statusIconsView
        }
        .padding(.vertical, 8)
        .task {
            // Background thread'de image decode et
            if let imageData = bookmark.imageData, cachedImage == nil {
                cachedImage = await decodeImage(from: imageData)
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let image = cachedImage {
            // Cached decoded image
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            // Fallback: emoji
            Text(bookmark.source.emoji)
                .font(.title2)
                .frame(width: 56, height: 56)
                .background(bookmark.source.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var statusIconsView: some View {
        VStack(spacing: 4) {
            if bookmark.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
            
            if !bookmark.isRead {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    // MARK: - Helper
    
    /// Background thread'de image decode et
    private func decodeImage(from data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            // UIImage decode işlemi background thread'de
            UIImage(data: data)
        }.value
    }
}

// MARK: - Preview

#Preview {
    BookmarkListView(
        homeViewModel: HomeViewModel(
            bookmarkRepository: PreviewMockRepository.shared,
            categoryRepository: PreviewMockCategoryRepository.shared
        )
    )
}
