import SwiftUI

/// Ana liste ekranı - tüm bookmarkları gösterir
struct BookmarkListView: View {
    // MARK: - Properties
    
    /// ViewModel - business logic burada
    @State private var viewModel: BookmarkListViewModel
    
    /// Sheet state - yeni bookmark ekle
    @State private var showingAddSheet = false
    
    // MARK: - Initialization
    
    init(viewModel: BookmarkListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    // Yüklenirken spinner göster
                    ProgressView("Yükleniyor...")
                } else if viewModel.isEmpty {
                    // Liste boşsa placeholder
                    emptyStateView
                } else {
                    // Liste dolu
                    bookmarkList
                }
            }
            .navigationTitle("Social Bookmark")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $viewModel.searchText,
                prompt: "Başlık veya not ara"
            )
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingAddSheet) {
                // Modal sheet - yeni bookmark ekle
                AddBookmarkView(
                    viewModel: AddBookmarkViewModel(repository: viewModel.repository),
                    onSaved: {
                        viewModel.loadBookmarks()
                    }
                )
            }
            .refreshable {
                // Pull-to-refresh
                viewModel.loadBookmarks()
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
            ForEach(viewModel.bookmarks) { bookmark in
                NavigationLink {
                    BookmarkDetailView(
                        bookmark: bookmark,
                        repository: viewModel.repository
                    )
                } label: {
                    BookmarkRow(bookmark: bookmark)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    // Sağdan kaydır: Sil
                    Button(role: .destructive) {
                        withAnimation {
                            viewModel.deleteBookmark(bookmark)
                        }
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    // Soldan kaydır: Okundu işaretle
                    Button {
                        withAnimation {
                            viewModel.toggleReadStatus(bookmark)
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
                Label("\(viewModel.totalCount) toplam", systemImage: "bookmark.fill")
                Spacer()
                Label("\(viewModel.unreadCount) okunmadı", systemImage: "circle.fill")
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
                Picker("Kaynak", selection: $viewModel.selectedSource) {
                    Text("Tümü").tag(nil as BookmarkSource?)
                    Divider()
                    ForEach(BookmarkSource.allCases) { source in
                        Text(source.displayName).tag(source as BookmarkSource?)
                    }
                }
                
                Divider()
                
                // Okunmamış filtresi
                Toggle("Sadece Okunmamışlar", isOn: $viewModel.showOnlyUnread)
                
                Divider()
                
                // Filtreleri temizle
                Button(action: viewModel.clearFilters) {
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
        viewModel: BookmarkListViewModel(
            repository: PreviewMockRepository.shared
        )
    )
}
