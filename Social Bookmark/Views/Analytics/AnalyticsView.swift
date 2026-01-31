import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AnalyticsViewModel
    
    @State private var selectedTab: AnalyticsTab = .general
    @State private var selectedCategory: Category?
    @State private var selectedSnapshot: BookmarkSnapshot?
    @State private var selectedFilter: FilterType?
    @EnvironmentObject private var sessionStore: SessionStore
    @Bindable var homeViewModel: HomeViewModel // Added HomeViewModel for details navigation
    
    init(modelContext: ModelContext, homeViewModel: HomeViewModel) {
        self.homeViewModel = homeViewModel
        _viewModel = StateObject(wrappedValue: AnalyticsViewModel(modelContext: modelContext))
    }
    
    enum AnalyticsTab: String, CaseIterable {
        case general = "Genel"
        case time = "Zaman"
        case categories = "Kategori"
    }
    
    enum FilterType: String, Identifiable {
        case read = "Okunmuş"
        case stale = "Eskimiş"
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Tab Picker
                Picker("Tabs", selection: $selectedTab) {
                    ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("İstatistikler hesaplanıyor...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 300)
                        } else {
                            switch selectedTab {
                            case .general:
                                generalTabView
                            case .time:
                                timeTabView
                            case .categories:
                                categoryTabView
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Analiz")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await viewModel.refreshData()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refreshData()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    @ViewBuilder
    private var generalTabView: some View {
        OverviewCard(
            total: viewModel.totalBookmarks,
            thisWeek: viewModel.thisWeekCount,
            favorites: viewModel.favoriteCount,
            readCount: viewModel.readCount,
            categories: viewModel.categoryCount,
            staleCount: viewModel.staleBookmarksCount,
            totalReadPercentage: viewModel.totalBookmarks > 0 ? Double(viewModel.readCount) / Double(viewModel.totalBookmarks) : 0,
            onReadTap: { selectedFilter = .read },
            onStaleTap: { selectedFilter = .stale },
            onCategoriesTap: { selectedTab = .categories }
        )
        
        PlatformBreakdownCard(breakdown: viewModel.platformBreakdown)
        
        ReadingHabitsCard(readCount: viewModel.readCount, unreadCount: viewModel.unreadCount)
        
        LinkHealthCard(stats: viewModel.linkHealth, brokenLinks: viewModel.brokenLinks) { snapshot in
            selectedSnapshot = snapshot
        }
        
        highlightCard
    }
    
    @ViewBuilder
    private var timeTabView: some View {
        Picker("Süre", selection: $viewModel.activityWindow) {
            Text("30 Gün").tag(30)
            Text("90 Gün").tag(90)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: viewModel.activityWindow) { _, _ in
            Task {
                await viewModel.refreshData()
            }
        }
        
        ActivityHeatmap(activity: viewModel.dailyActivity)
        
        TimeOfDayCard(breakdown: viewModel.timeOfDayBreakdown)
        
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatCard(title: "Güncel Streak", value: "\(viewModel.currentStreak) Gün", icon: "flame.fill", color: .orange)
                StatCard(title: "En Uzun Streak", value: "\(viewModel.longestStreak) Gün", icon: "trophy.fill", color: .yellow)
            }
            
            if let activeDay = viewModel.mostActiveDay {
                StatCard(title: "En Aktif Gün", value: activeDay, icon: "calendar.badge.clock", color: .blue)
            }
        }
    }
    
    @ViewBuilder
    private var categoryTabView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kategori Analizi")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if viewModel.categoryBreakdown.isEmpty {
                Text("Henüz kategori verisi yok")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.categoryBreakdown) { item in
                    Button {
                        // Fetch the actual category model from context using ID
                        let id = item.id
                        let descriptor = FetchDescriptor<Category>(predicate: #Predicate<Category> { $0.id == id })
                        if let category = try? modelContext.fetch(descriptor).first {
                            selectedCategory = category
                        }
                    } label: {
                        HStack {
                            Image(systemName: item.icon)
                                .foregroundStyle(Color(hex: item.colorHex) ?? .blue)
                                .frame(width: 30)
                            
                            Text(item.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text("\(item.count)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .sheet(item: $selectedCategory) { category in
            CategoryDetailView(category: category, viewModel: homeViewModel)
                .environmentObject(sessionStore)
        }
        .sheet(item: $selectedSnapshot) { snapshot in
            // Fetch the actual bookmark model using the snapshot's title or id if we had it.
            // Since Snapshot has title and url, we can search by that.
            let title = snapshot.title
            let url = snapshot.url
            let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate<Bookmark> { $0.title == title })
            
            if let bookmark = try? modelContext.fetch(descriptor).first {
                BookmarkDetailView(bookmark: bookmark, viewModel: homeViewModel)
                    .environmentObject(sessionStore)
            } else {
                Text("Bookmark bulunamadı")
            }
        }
        .sheet(item: $selectedFilter) { filter in
            AnalyticsFilteredListView(filterType: filter, homeViewModel: homeViewModel)
                .environmentObject(sessionStore)
        }
    }
    
    @ViewBuilder
    private var highlightCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🌟 Öne Çıkanlar")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if let favoriteTitle = viewModel.mostFavoritedTitle {
                Button {
                    let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate<Bookmark> { $0.title == favoriteTitle })
                    if let bookmark = try? modelContext.fetch(descriptor).first {
                        selectedSnapshot = BookmarkSnapshot(id: bookmark.id, title: bookmark.title, url: bookmark.url)
                    }
                } label: {
                    HighlightRow(title: "En çok favorilenen", content: favoriteTitle, icon: "star.fill", color: .yellow)
                }
            }
            
            if let oldestTitle = viewModel.oldestUnreadTitle {
                Button {
                    let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate<Bookmark> { $0.title == oldestTitle })
                    if let bookmark = try? modelContext.fetch(descriptor).first {
                        selectedSnapshot = BookmarkSnapshot(id: bookmark.id, title: bookmark.title, url: bookmark.url)
                    }
                } label: {
                    HighlightRow(title: "En eski okunmamış", content: oldestTitle, icon: "clock.fill", color: .blue)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct HighlightRow: View {
    let title: String
    let content: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(content)
                    .font(.subheadline)
                    .lineLimit(1)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title3.bold())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct AnalyticsFilteredListView: View {
    let filterType: AnalyticsView.FilterType
    let homeViewModel: HomeViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: SessionStore
    
    private var title: String {
        filterType == .read ? "Okunmuş Bookmarklar" : "Eskimiş Bookmarklar"
    }
    
    private var filteredBookmarks: [Bookmark] {
        switch filterType {
        case .read:
            return homeViewModel.bookmarks.filter { $0.isRead }
        case .stale:
            let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            return homeViewModel.bookmarks.filter { !$0.isRead && $0.createdAt < sixMonthsAgo }
        }
    }
    
    var body: some View {
        NavigationStack {
            UnifiedBookmarkList(
                bookmarks: filteredBookmarks,
                viewModel: homeViewModel,
                emptyTitle: String(localized: "all.empty.no_results"),
                emptySubtitle: "",
                emptyIcon: "tray"
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
