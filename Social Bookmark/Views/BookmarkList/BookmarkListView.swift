import SwiftUI

/// Ana liste ekranı - tüm bookmarkları gösterir
struct BookmarkListView: View {
    // MARK: - Properties
    
    /// Home ViewModel - bookmark ekleme için gerekli
    @Bindable var homeViewModel: HomeViewModel
    
    /// Iç ViewModel - liste filtreleme ve işlemler
    @State private var listViewModel: BookmarkListViewModel
    
    /// Sheet state - yeni bookmark ekle
    @State private var showingAddSheet = false
    
    // MARK: - Initialization
    
    init(homeViewModel: HomeViewModel) {
        self.homeViewModel = homeViewModel
        _listViewModel = State(
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
                    ProgressView("Yükleniyor...")
                } else if listViewModel.isEmpty {
                    // Liste boşsa placeholder
                    emptyStateView
                } else {
                    // Liste dolu
                    bookmarkList
                }
            }
            .navigationTitle("Social Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $listViewModel.searchText,
                prompt: "Başlık veya not ara"
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
    
    // MARK: - Subviews
    
    /// Bookmark listesi
    private var bookmarkList: some View {
        List {
            // Stats section
            statsSection
            
            // Bookmarklar
            ForEach(listViewModel.bookmarks) { bookmark in
                NavigationLink {
                    BookmarkDetailView(
                        bookmark: bookmark,
                        viewModel: homeViewModel
                    )
                } label: {
                    BookmarkRow(bookmark: bookmark)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    // Sağdan kaydır: Sil
                    Button(role: .destructive) {
                        withAnimation {
                            listViewModel.deleteBookmark(bookmark)
                        }
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    // Soldan kaydır: Okundu işaretle
                    Button {
                        withAnimation {
                            listViewModel.toggleReadStatus(bookmark)
                        }
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
        .listStyle(.insetGrouped)
    }
    
    /// İstatistik bölümü
    private var statsSection: some View {
        Section {
            HStack {
                Label("\(listViewModel.totalCount) toplam", systemImage: "bookmark.fill")
                Spacer()
                Label("\(listViewModel.unreadCount) okunmadı", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
    
    /// Boş durum görünümü
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
            
            Button(action: { showingAddSheet = true }) {
                Label("İlk Bookmark'ı Ekle", systemImage: "plus.circle.fill")
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
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
            }
        }
        
        // Sol üst: Filtre menüsü
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                // Kaynak filtresi
                Picker("Kaynak", selection: $listViewModel.selectedSource) {
                    Text("Tümü").tag(nil as BookmarkSource?)
                    Divider()
                    ForEach(BookmarkSource.allCases) { source in
                        Text(source.displayName).tag(source as BookmarkSource?)
                    }
                }
                
                Divider()
                
                // Okunmamış filtresi
                Toggle("Sadece Okunmamışlar", isOn: $listViewModel.showOnlyUnread)
                
                Divider()
                
                // Filtreleri temizle
                Button(action: listViewModel.clearFilters) {
                    Label("Filtreleri Temizle", systemImage: "xmark.circle")
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
