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
                } else {
                    // UnifiedBookmarkList kendi boş durumunu yönetir
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
        UnifiedBookmarkList(
            bookmarks: listViewModel.bookmarks,
            viewModel: homeViewModel,
            showStats: true,
            emptyTitle: String(localized: "home.empty.no_bookmarks"),
            emptySubtitle: String(localized: "home.empty.no_bookmarks_desc"),
            emptyIcon: "bookmark.slash"
        )
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

// MARK: - Preview

#Preview {
    BookmarkListView(
        homeViewModel: HomeViewModel(
            bookmarkRepository: PreviewMockRepository.shared,
            categoryRepository: PreviewMockCategoryRepository.shared
        )
    )
}
