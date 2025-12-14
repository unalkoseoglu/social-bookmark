import SwiftUI

/// Ana ekran - Dashboard style
/// Kullanıcı tek bakışta ne eklediğini, neler olduğunu görebilir
struct HomeView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    
    @State private var showingAddSheet = false
    @State private var showingSearch = false
    @State private var selectedCategory: Category?
    @State private var selectedQuickFilter: QuickFilter?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // 1. Hızlı İstatistikler
                    quickStatsSection
                    
                    // 2. Hızlı Filtreler (Son eklenenler, Okunmamışlar vs.)
                    quickFiltersSection
                    
                    // 3. Kategoriler Grid
                    categoriesSection
                    
                    // 4. Kaynağa Göre (Twitter, Reddit vs.)
                    sourcesSection
                    
                    // 5. Son Eklenenler
                    recentBookmarksSection
                }
                .padding()
            }
            .navigationTitle("Bookmarklar")
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddBookmarkView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingSearch) {
                SearchView(viewModel: viewModel)
            }
            .sheet(item: $selectedCategory) { category in
                CategoryDetailView(category: category, viewModel: viewModel)
            }
            .sheet(item: $selectedQuickFilter) { filter in
                QuickFilterDetailView(filter: filter, viewModel: viewModel)
            }
            .refreshable {
                viewModel.refresh()
            }
        }
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Toplam",
                value: "\(viewModel.totalCount)",
                icon: "bookmark.fill",
                color: .blue
            )
            
            StatCard(
                title: "Okunmadı",
                value: "\(viewModel.unreadCount)",
                icon: "circle.fill",
                color: .orange
            )
            
            StatCard(
                title: "Bu Hafta",
                value: "\(viewModel.thisWeekCount)",
                icon: "calendar",
                color: .green
            )
        }
    }
    
    // MARK: - Quick Filters Section
    
    private var quickFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Hızlı Erişim", icon: "bolt.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(QuickFilter.allCases) { filter in
                        QuickFilterChip(
                            filter: filter,
                            count: viewModel.count(for: filter)
                        ) {
                            selectedQuickFilter = filter
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Kategoriler", icon: "folder.fill")
                
                Spacer()
                
                NavigationLink {
                    CategoriesManagementView(viewModel: viewModel)
                } label: {
                    Text("Düzenle")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            
            if viewModel.categories.isEmpty {
                EmptyCategoriesCard {
                    // Varsayılan kategorileri oluştur
                    viewModel.createDefaultCategories()
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(viewModel.categories) { category in
                        CategoryCard(
                            category: category,
                            bookmarkCount: viewModel.bookmarkCount(for: category)
                        ) {
                            selectedCategory = category
                        }
                    }
                    
                    // Kategorisiz kartı
                    UncategorizedCard(
                        count: viewModel.uncategorizedCount
                    ) {
                        selectedQuickFilter = .uncategorized
                    }
                }
            }
        }
    }
    
    // MARK: - Sources Section
    
    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Kaynaklara Göre", icon: "square.grid.2x2.fill")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(viewModel.sourcesWithCounts, id: \.source) { item in
                    SourceCard(
                        source: item.source,
                        count: item.count
                    ) {
                        selectedQuickFilter = .source(item.source)
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Bookmarks Section
    
    private var recentBookmarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Son Eklenenler", icon: "clock.fill")
                
                Spacer()
                
                NavigationLink {
                    AllBookmarksView(viewModel: viewModel)
                } label: {
                    Text("Tümünü Gör")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            
            if viewModel.recentBookmarks.isEmpty {
                EmptyRecentCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentBookmarks.prefix(5)) { bookmark in
                        NavigationLink {
                            BookmarkDetailView(
                                bookmark: bookmark,
                                repository: viewModel.bookmarkRepository
                            )
                        } label: {
                            RecentBookmarkRow(bookmark: bookmark)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Quick Filter Enum

enum QuickFilter: Identifiable, CaseIterable, Hashable {
    case unread
    case favorites
    case today
    case thisWeek
    case uncategorized
    case source(BookmarkSource)
    
    var id: String {
        switch self {
        case .unread: return "unread"
        case .favorites: return "favorites"
        case .today: return "today"
        case .thisWeek: return "thisWeek"
        case .uncategorized: return "uncategorized"
        case .source(let source): return "source_\(source.rawValue)"
        }
    }
    
    var title: String {
        switch self {
        case .unread: return "Okunmadı"
        case .favorites: return "Favoriler"
        case .today: return "Bugün"
        case .thisWeek: return "Bu Hafta"
        case .uncategorized: return "Kategorisiz"
        case .source(let source): return source.displayName
        }
    }
    
    var icon: String {
        switch self {
        case .unread: return "circle"
        case .favorites: return "star.fill"
        case .today: return "sun.max.fill"
        case .thisWeek: return "calendar"
        case .uncategorized: return "folder"
        case .source(let source): return source.systemIcon
        }
    }
    
    var color: Color {
        switch self {
        case .unread: return .orange
        case .favorites: return .yellow
        case .today: return .blue
        case .thisWeek: return .green
        case .uncategorized: return .gray
        case .source(let source): return source.color
        }
    }
    
    static var allCases: [QuickFilter] {
        [.unread, .favorites, .today, .thisWeek]
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: QuickFilter, rhs: QuickFilter) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Supporting Components

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
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

struct QuickFilterChip: View {
    let filter: QuickFilter
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: filter.icon)
                    .foregroundStyle(filter.color)
                
                Text(filter.title)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(filter.color.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct CategoryCard: View {
    let category: Category
    let bookmarkCount: Int
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
                    
                    Text("\(bookmarkCount)")
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

struct UncategorizedCard: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "folder")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                
                Text("Kategorisiz")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(Color.gray.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }
}

struct SourceCard: View {
    let source: BookmarkSource
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(source.emoji)
                    .font(.title)
                
                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(source.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct RecentBookmarkRow: View {
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
        .padding(.vertical, 4)
    }
}

struct EmptyCategoriesCard: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("Henüz kategori yok")
                .font(.headline)
            
            Text("Bookmarklarını düzenlemek için kategoriler oluştur")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Varsayılan Kategorileri Ekle", action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct EmptyRecentCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("Henüz bookmark eklenmedi")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
