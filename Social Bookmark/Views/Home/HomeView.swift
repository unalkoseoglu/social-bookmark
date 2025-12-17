import SwiftUI

/// Ana ekran - Dashboard style
/// Kullanıcı tek bakışta ne eklediğini, neler olduğunu görebilir
struct HomeView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    
    @State private var showingAddSheet = false
    @State private var showingSearch = false
    @State private var selectedCategory: Category?
    @State private var selectedFilter: QuickFilter?
    @StateObject private var sessionStore = SessionStore()
    
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    
                    Divider()
                    
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
            .sheet(item: $selectedFilter) { filter in
                FilteredBookmarksView(
                    filter: filter,
                    viewModel: viewModel
                )
            }
            .refreshable {
                viewModel.refresh()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("home.title")
                    .font(.system(size: 28, weight: .bold))
                
                Text("home.stats_summary \(viewModel.totalCount) \(viewModel.unreadCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Arama butonu
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                // Ekleme butonu
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                
                NavigationLink {
                    SettingsView().environmentObject(sessionStore)
                } label: {
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.blue)
                        .clipShape(Circle())
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
                title: String(localized: "home.stat.total"),
                color: .blue
            )
            
            StatCard(
                icon: "circle.fill",
                value: "\(viewModel.unreadCount)",
                title: String(localized: "home.stat.unread"),
                color: .orange
            )
            
            StatCard(
                icon: "calendar",
                value: "\(viewModel.thisWeekCount)",
                title: String(localized: "home.stat.this_week"),
                color: .green
            )
        }
    }
    
    // MARK: - Quick Access Section
    
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "home.section.quick_access"))
            
            HStack(spacing: 10) {
                QuickAccessButton(
                    icon: "circle.fill",
                    title: String(localized: "home.filter.unread"),
                    count: viewModel.unreadCount,
                    color: .orange
                ) {
                    selectedFilter = .unread
                }
                
                QuickAccessButton(
                    icon: "star.fill",
                    title: String(localized: "home.filter.favorites"),
                    count: viewModel.favoritesCount,
                    color: .yellow
                ) {
                    selectedFilter = .favorites
                }
                
                QuickAccessButton(
                    icon: "sun.max.fill",
                    title: String(localized: "home.filter.today"),
                    count: viewModel.todayCount,
                    color: .blue
                ) {
                    selectedFilter = .today
                }
            }
        }
    }
    
    // MARK: - Categories Grid Section
    
    private var categoriesGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: String(localized: "home.section.categories"))
                
                Spacer()
                
                NavigationLink {
                    CategoriesManagementView(viewModel: viewModel)
                } label: {
                    Text("home.action.edit")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            
            if viewModel.categories.isEmpty {
                emptyCategoriesView
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.categories) { category in
                        CategoryCardItem(
                            category: category,
                            count: viewModel.bookmarkCount(for: category)
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }
    
    private var emptyCategoriesView: some View {
        Button {
            viewModel.createDefaultCategories()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .font(.title2)
                Text("home.action.create_categories")
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color(.systemGray6))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Recent Items Section
    
    private var recentItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: String(localized: "home.section.recent"))
                
                Spacer()
                
                NavigationLink {
                    AllBookmarksView(viewModel: viewModel)
                } label: {
                    Text("home.action.see_all")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            
            if viewModel.recentBookmarks.isEmpty {
                emptyRecentView
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentBookmarks.prefix(5)) { bookmark in
                        NavigationLink {
                            BookmarkDetailView(
                                bookmark: bookmark,
                                repository: viewModel.bookmarkRepository
                            )
                        } label: {
                            RecentItemRow(bookmark: bookmark)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var emptyRecentView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("home.empty.no_bookmarks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quick Filter Enum

enum QuickFilter: String, Identifiable {
    case unread
    case favorites
    case today
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .unread: return String(localized: "home.filter.unread")
        case .favorites: return String(localized: "home.filter.favorites")
        case .today: return String(localized: "home.filter.today")
        }
    }
    
    var icon: String {
        switch self {
        case .unread: return "circle.fill"
        case .favorites: return "star.fill"
        case .today: return "sun.max.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .unread: return .orange
        case .favorites: return .yellow
        case .today: return .blue
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}

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
                .contentTransition(.numericText())
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
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
                        .contentTransition(.numericText())
                }
                
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
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
                        .contentTransition(.numericText())
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
            // Kaynak emoji
            Text(bookmark.source.emoji)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(bookmark.source.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Başlık ve meta bilgi
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
            
            // Okunmadı göstergesi
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
        .contentShape(Rectangle())
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
