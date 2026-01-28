import SwiftUI

/// Ana ekran - Yeni Dashboard tasarımı
/// Saat bazlı selamlama, kategoriler (max 6), son eklenenler, ve widgetlar
struct HomeView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var selectedCategory: Category?
    @State private var selectedFilter: QuickFilter?
    @State private var showingAddCategory = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingPaywall = false
    @AppStorage("hasDismissedNotificationCard") private var hasDismissedNotificationCard = false
    
    // MARK: - Time-based Greeting
    // MARK: - Time-based Greeting
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            return String(localized: "greeting.morning")
        case 12..<18:
            return String(localized: "greeting.afternoon")
        case 18..<22:
            return String(localized: "greeting.evening")
        default:
            return String(localized: "greeting.night")
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: Date())
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header: Greeting + Tarih
                headerSection
                    .padding(.horizontal, 16)
                
                // Pro Limit Uyarısı (Eğer free kullanıcı ve limit dolmak üzereyse)
                if !subscriptionManager.isPro && viewModel.totalCount >= 40 {
                    limitWarningCard
                        .padding(.horizontal, 16)
                }
                
                // Bildirim Promosyon Kartı (Eğer izin verilmemişse ve dismiss edilmemişse)
                if !notificationManager.isAuthorized && !hasDismissedNotificationCard {
                    notificationPromotionalCard
                        .padding(.horizontal, 16)
                }
                
                // Kategoriler (max 6, 2x3 grid)
                categoriesSection
                
                // Son Eklenenler (max 6)
                recentBookmarksSection
                
                // Widget'lar
                widgetsSection
                
                Spacer(minLength: 20)
            }
            .containerRelativeFrame(.horizontal)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
       
        .sheet(item: $selectedCategory) { category in
            CategoryDetailView(category: category, viewModel: viewModel)
                .environmentObject(sessionStore)
        }
        .sheet(item: $selectedFilter) { filter in
            FilteredBookmarksView(filter: filter, viewModel: viewModel)
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView { category in
                 viewModel.addCategory(category)
            }
            .environmentObject(sessionStore)
        }
        .refreshable {
          await viewModel.refresh()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
                .environmentObject(sessionStore)
        }
        .id(languageManager.refreshID)
        .onAppear {
            print("🏠 [HomeView] onAppear - loading data")
            viewModel.loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { _ in
            print("🔐 [HomeView] User signed in - triggering explicit refresh")
            Task {
                await viewModel.refresh()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                if !subscriptionManager.isPro {
                    Button {
                        showingPaywall = true
                    } label: {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Circle())
                    }
                }else if subscriptionManager.isPro {
                    ProBadge()
                }
                
                NavigationLink {
                    SettingsView().environmentObject(sessionStore)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Limit Warning Card
    
    private var limitWarningCard: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "info.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "home.limit.approaching"))
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Text(String(localized: "home.limit.approaching_desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(String(localized: "home.action.upgrade"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Notification Promotional Card
    
    private var notificationPromotionalCard: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "home.notification_card.title"))
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Text(String(localized: "home.notification_card.subtitle"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Action Button
                Button {
                    notificationManager.requestAuthorization()
                } label: {
                    Text(String(localized: "common.ok"))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                
               
                
            }
            .padding(.leading, 12)
            .padding(.vertical, 16)
            .padding(.trailing, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.1), lineWidth: 1)
            )
            
            // Close Button
            Button {
                withAnimation {
                    hasDismissedNotificationCard = true
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary.opacity(0.4))
                    .font(.system(size: 18))
                    .padding(4)
            }
        }
    }
    
    // MARK: - Categories Section (max 6, 3x2)
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HomeSectionHeader(
                    title: String(localized: "home.section.categories"),
                    icon: "folder.fill"
                )
                
                Spacer()
                
                if !viewModel.categories.isEmpty {
                    NavigationLink {
                        CategoriesManagementView(viewModel: viewModel)
                    } label: {
                        Text(String(localized: "home.action.edit"))
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            if viewModel.categories.isEmpty {
                emptyCategoriesCard
                    .padding(.horizontal, 16)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                    spacing: 12
                ) {
                    ForEach(Array(viewModel.categories.prefix(6))) { category in
                        CompactCategoryCard(
                            category: category,
                            count: viewModel.bookmarkCount(for: category)
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var emptyCategoriesCard: some View {
        Button {
            showingAddCategory = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "home.empty.add_category"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(String(localized: "home.empty.add_category_desc"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Recent Bookmarks Section (max 6)
    
    private var recentBookmarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HomeSectionHeader(
                    title: String(localized: "home.section.recent"),
                    icon: "bookmark.fill"
                )
                
                Spacer()
                
                if viewModel.bookmarks.count > 6 {
                    NavigationLink {
                        AllBookmarksView(viewModel: viewModel)
                    } label: {
                        Text(String(localized: "home.action.see_all"))
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            if viewModel.recentBookmarks.isEmpty {
                emptyRecentCard
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentBookmarks.prefix(6).enumerated()), id: \.element.id) { index, bookmark in
                        NavigationLink {
                            BookmarkDetailView(
                                bookmark: bookmark,
                                viewModel: viewModel
                            )
                        } label: {
                            EnhancedBookmarkRow(bookmark: bookmark).padding(14)
                        }
                        .buttonStyle(.plain)
                        
                        if index < min(5, viewModel.recentBookmarks.count - 1) {
                            Divider()
                                .padding(.leading, 98)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var emptyRecentCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 4) {
                Text(String(localized: "home.empty.no_bookmarks"))
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(String(localized: "home.empty.no_bookmarks_desc"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Widgets Section
    
    private var widgetsSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Reading Progress Widget
                ReadingProgressWidget(
                    readCount: viewModel.totalCount - viewModel.unreadCount,
                    totalCount: viewModel.totalCount
                )
                .frame(maxWidth: .infinity)
                
                // Quick Stats Widget
                QuickStatsWidget(
                    todayCount: viewModel.todayCount,
                    weekCount: viewModel.thisWeekCount,
                    favoritesCount: viewModel.favoritesCount
                ) { filter in
                    selectedFilter = filter
                }
                .frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            
        
            
        }
    }
}

// MARK: - Home Section Header

struct HomeSectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.3)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Compact Category Card (3 per row)

struct CompactCategoryCard: View {
    let category: Category
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(category.color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(category.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}



// MARK: - Reading Progress Widget

struct ReadingProgressWidget: View {
    let readCount: Int
    let totalCount: Int
    
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(readCount) / Double(totalCount)
    }
    
    private var percentage: Int {
        Int(progress * 100)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundStyle(.blue)
                Text(String(localized: "widget.reading_progress"))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                Text("%\(percentage)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
            .frame(width: 70, height: 70)
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            Text(String(localized: "widget.read_count \(readCount) \(totalCount)"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Quick Stats Widget

struct QuickStatsWidget: View {
    let todayCount: Int
    let weekCount: Int
    let favoritesCount: Int
    let onFilterTap: (QuickFilter) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.purple)
                Text(String(localized: "widget.quick_stats"))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            VStack(spacing: 10) {
                quickStatRow(
                    icon: "sun.max.fill",
                    title: String(localized: "common.today"),
                    count: todayCount,
                    color: .orange
                ) {
                    onFilterTap(.today)
                }
                
                quickStatRow(
                    icon: "calendar",
                    title: String(localized: "common.this_week"),
                    count: weekCount,
                    color: .green
                ) {
                    // TODO: This week filter
                }
                
                quickStatRow(
                    icon: "star.fill",
                    title: String(localized: "common.favorites"),
                    count: favoritesCount,
                    color: .yellow
                ) {
                    onFilterTap(.favorites)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func quickStatRow(
        icon: String,
        title: String,
        count: Int,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Popular Tags Widget

struct PopularTagsWidget: View {
    let tags: [String]
    let viewModel: HomeViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.green)
                Text(String(localized: "widget.popular_tags"))
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    NavigationLink {
                        TaggedBookmarksView(tag: tag, viewModel: viewModel)
                    } label: {
                        Text("#\(tag)")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Tagged Bookmarks View (for tag navigation)

struct TaggedBookmarksView: View {
    let tag: String
    let viewModel: HomeViewModel
    
    private var filteredBookmarks: [Bookmark] {
        viewModel.bookmarks.filter { $0.tags.contains(tag) }
    }
    
    var body: some View {
        List {
            ForEach(filteredBookmarks) { bookmark in
                NavigationLink {
                    BookmarkDetailView(
                        bookmark: bookmark,
                        viewModel: viewModel
                    )
                } label: {
                    EnhancedBookmarkRow(bookmark: bookmark).padding(14)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("#\(tag)")
        .navigationBarTitleDisplayMode(.large)
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

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: width, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView(
            viewModel: HomeViewModel(
                bookmarkRepository: PreviewMockRepository.shared,
                categoryRepository: PreviewMockCategoryRepository.shared
            )
        )
        .environmentObject(SessionStore())
    }
}
