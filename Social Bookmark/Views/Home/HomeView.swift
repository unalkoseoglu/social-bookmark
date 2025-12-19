import SwiftUI

/// Ana ekran - Yeni Dashboard tasarımı
/// Saat bazlı selamlama, kategoriler (max 6), son eklenenler, ve widgetlar
struct HomeView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    
    @State private var selectedCategory: Category?
    @State private var selectedFilter: QuickFilter?
    @State private var showingAddCategory = false
    
    // MARK: - Time-based Greeting
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            return String(localized: "greeting.morning") // "Günaydın"
        case 12..<18:
            return String(localized: "greeting.afternoon") // "Tünaydın"
        case 18..<22:
            return String(localized: "greeting.evening") // "İyi akşamlar"
        default:
            return String(localized: "greeting.night") // "İyi geceler"
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMMM, EEEE" // "28 Aralık, Perşembe"
        return formatter.string(from: Date())
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header: Greeting + Tarih
                headerSection
                    .padding(.horizontal, 16)
                
                // Kategoriler (max 6, 3x2 grid)
                categoriesSection
                
                // Son Eklenenler (max 6)
                recentBookmarksSection
                
                // Widget'lar
                widgetsSection
                
                Spacer(minLength: 20)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
       
        .sheet(item: $selectedCategory) { category in
            CategoryDetailView(category: category, viewModel: viewModel)
        }
        .sheet(item: $selectedFilter) { filter in
            FilteredBookmarksView(filter: filter, viewModel: viewModel)
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView { category in
                viewModel.addCategory(category)
            }
        }
        .refreshable {
            viewModel.refresh()
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
            
            
         
            

                NavigationLink {
                    SettingsView().environmentObject(sessionStore)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundStyle(.secondary)
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
                        Text("Düzenle")
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
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
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
                    Text("Kategori Ekle")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Bookmarklarını düzenlemek için kategoriler oluştur")
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
                    title: String(localized: "home.title"),
                    icon: "bookmark.fill"
                )
                
                Spacer()
                
                if viewModel.bookmarks.count > 6 {
                    NavigationLink {
                        AllBookmarksView(viewModel: viewModel)
                    } label: {
                        Text(String(localized: "library.segment.all"))
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
                            EnhancedBookmarkRow(bookmark: bookmark)
                        }
                        .buttonStyle(.plain)
                        
                        if index < min(5, viewModel.recentBookmarks.count - 1) {
                            Divider()
                                .padding(.leading, 88)
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
                Text("Henüz bookmark eklenmedi")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Paylaş butonuyla içerik ekleyin")
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
            .fixedSize(horizontal: false, vertical: true) // Eşit yükseklik için
            .padding(.horizontal, 16)
            
            // Popular Tags Widget
            if !viewModel.popularTags.isEmpty {
                PopularTagsWidget(
                    tags: Array(viewModel.popularTags.prefix(8)),
                    viewModel: viewModel
                )
                .padding(.horizontal, 16)
            }
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
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(category.color)
                }
                
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

// MARK: - Enhanced Bookmark Row (Daha büyük, 3-4 satır içerik)

struct EnhancedBookmarkRow: View {
    let bookmark: Bookmark
    
    private var contentPreview: String {
        if !bookmark.note.isEmpty {
            return bookmark.note
        } else if let extractedText = bookmark.extractedText, !extractedText.isEmpty {
            return extractedText
        } else if let url = bookmark.url {
            return url
        }
        return "İçerik yok"
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Thumbnail or Source Icon
            Group {
                if let imageData = bookmark.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        bookmark.source.color.opacity(0.15)
                        Text(bookmark.source.emoji)
                            .font(.title2)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(bookmark.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                // Content Preview (3-4 satır)
                Text(contentPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                
                // Meta Info
                HStack( alignment: .center, spacing: 8) {
                    // Source Badge
                    HStack(spacing: 4) {
                        Text(bookmark.source.emoji)
                            .font(.caption2)
                        Text(bookmark.source.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Text(bookmark.relativeDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                }
            }
            
            // Status Indicators
            VStack(alignment: .center, spacing: 6) {
                if !bookmark.isRead {
                    Circle()
                        .fill(.orange)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                
            }
            .padding(.top, 4)
        }
        .padding(14)
        .contentShape(Rectangle())
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
                Text("Okuma İlerlemesi")
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
            
            Text("\(readCount)/\(totalCount) okundu")
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
                Text("Hızlı İstatistikler")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            VStack(spacing: 10) {
                quickStatRow(
                    icon: "sun.max.fill",
                    title: "Bugün",
                    count: todayCount,
                    color: .orange
                ) {
                    onFilterTap(.today)
                }
                
                quickStatRow(
                    icon: "calendar",
                    title: "Bu Hafta",
                    count: weekCount,
                    color: .green
                ) {
                    // TODO: This week filter
                }
                
                quickStatRow(
                    icon: "star.fill",
                    title: "Favoriler",
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
                Text("Popüler Etiketler")
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
                    BookmarkListRow(bookmark: bookmark)
                }
            }
        }
        .listStyle(.plain)
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
