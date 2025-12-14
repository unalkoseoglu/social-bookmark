import SwiftUI

/// Ana ekran - Dashboard style
/// Kullanıcı tek bakışta ne eklediğini, neler olduğunu görebilir
struct HomeView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    
    @State private var showingAddSheet = false
    @State private var showingSearch = false
    @State private var selectedCategory: Category?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header - Başlık ve Butonlar
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        
                        Divider()
                    }
                    .background(Color(.systemBackground))
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // İstatistikler
                            statisticsSection
                                .padding(.horizontal, 16)
                            
                            // Hızlı Erişim Filtreleri
                            quickAccessSection
                                .padding(.horizontal, 16)
                            
                            // Kategoriler Grid
                            categoriesGridSection
                                .padding(.horizontal, 16)
                            
                            // Son Eklenenler
                            recentItemsSection
                                .padding(.horizontal, 16)
                            
                            Spacer(minLength: 20)
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddBookmarkView(
                    viewModel: AddBookmarkViewModel(
                        repository: viewModel.bookmarkRepository,
                        categoryRepository: viewModel.categoryRepository
                    ),
                    onSaved: { viewModel.refresh() }
                )
            }
            .sheet(isPresented: $showingSearch) {
                SearchView(viewModel: viewModel)
            }
            .sheet(item: $selectedCategory) { category in
                CategoryDetailView(category: category, viewModel: viewModel)
            }
            .refreshable {
                viewModel.refresh()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bookmarklar", bundle: .main, comment: "Home view title")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("\(viewModel.totalCount) toplam • \(viewModel.unreadCount) okunmadı", bundle: .main, comment: "Stat counts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { showingSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "bookmark.fill",
                value: "\(viewModel.totalCount)",
                title: "Toplam",
                color: .blue
            )
            
            StatCard(
                icon: "circle.fill",
                value: "\(viewModel.unreadCount)",
                title: "Okunmadı",
                color: .orange
            )
            
            StatCard(
                icon: "calendar",
                value: "\(viewModel.thisWeekCount)",
                title: "Bu Hafta",
                color: .green
            )
        }
    }
    
    // MARK: - Quick Access Section
    
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hızlı Erişim", bundle: .main, comment: "Quick access section title")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(0.3)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            HStack(spacing: 10) {
                QuickAccessButton(
                    icon: "circle.fill",
                    title: "Okunmadı",
                    count: viewModel.unreadCount,
                    color: .orange,
                    action: { }
                )
                
                QuickAccessButton(
                    icon: "star.fill",
                    title: "Favoriler",
                    count: 0,
                    color: .yellow,
                    action: { }
                )
                
                QuickAccessButton(
                    icon: "sun.max.fill",
                    title: "Bugün",
                    count: viewModel.todayCount,
                    color: .blue,
                    action: { }
                )
            }
        }
    }
    
    // MARK: - Categories Grid Section
    
    private var categoriesGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kategoriler", bundle: .main, comment: "Categories section title")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(0.3)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                NavigationLink("Düzenle", destination: CategoriesManagementView(viewModel: viewModel))
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            
            if viewModel.categories.isEmpty {
                Button(action: { viewModel.createDefaultCategories() }) {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.title2)
                        Text("Kategorileri Oluştur", bundle: .main, comment: "Create categories button")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.categories) { category in
                        CategoryCardItem(
                            category: category,
                            count: viewModel.bookmarkCount(for: category),
                            action: { selectedCategory = category }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Items Section
    
    private var recentItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Son Eklenenler", bundle: .main, comment: "Recent items section title")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(0.3)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                NavigationLink("Tümünü Gör", destination: AllBookmarksView(viewModel: viewModel))
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            
            if viewModel.recentBookmarks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bookmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Henüz bookmark eklenmedi", bundle: .main, comment: "Empty recent bookmarks message")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentBookmarks.prefix(5)) { bookmark in
                        NavigationLink(destination: BookmarkDetailView(bookmark: bookmark, repository: viewModel.bookmarkRepository)) {
                            RecentItemRow(bookmark: bookmark)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Supporting Components
    
    
    // MARK: - Stat Card
    
    struct StatCard: View {
        let icon: String
        let value: String
        let title: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Category Card Item
    
    struct CategoryCardItem: View {
        let category: Category
        let count: Int
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: category.icon)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(category.color)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Spacer()
                        
                        Text("\(count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                    
                    Text(category.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Quick Access Button
    
    struct QuickAccessButton: View {
        let icon: String
        let title: String
        let count: Int
        let color: Color
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                    
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.caption2)
                            .fontWeight(.medium)
                        
                        Text("\(count)")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Recent Item Row
    
    struct RecentItemRow: View {
        let bookmark: Bookmark
        
        var body: some View {
            HStack(spacing: 12) {
                Text(bookmark.source.emoji)
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .background(bookmark.source.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bookmark.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 6) {
                        Text(bookmark.source.displayName)
                        Text("•")
                        Text(bookmark.relativeDate)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if !bookmark.isRead {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
    }
}
// MARK: - Preview

#Preview {
    HomeView(
        viewModel: HomeViewModel(
            bookmarkRepository: PreviewMockRepository.shared,
            categoryRepository: PreviewMockCategoryRepository.shared
        )
    )
}
