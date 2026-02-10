import Foundation
import SwiftData
import SwiftUI
import Combine

// MARK: - Sendable Helper Models

struct PlatformCount: Identifiable, Equatable, Sendable {
    let id = UUID()
    let source: BookmarkSource
    let count: Int
}

struct CategoryCount: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let icon: String
    let colorHex: String
    let count: Int
}

struct DateActivity: Identifiable, Equatable, Sendable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct TimeOfDayCount: Identifiable, Equatable, Sendable {
    let id = UUID()
    let label: String
    let count: Int
    let icon: String
}

struct LinkHealthStats: Equatable, Sendable {
    var active: Int = 0
    var broken: Int = 0
    var checking: Int = 0
    
    var activePercentage: Double {
        let total = active + broken + checking
        return total > 0 ? Double(active) / Double(total) : 0
    }
}

struct AnalyticsData: Sendable {
    let totalBookmarks: Int
    let thisWeekCount: Int
    let readCount: Int
    let favoriteCount: Int
    let categoryCount: Int
    let platformBreakdown: [PlatformCount]
    let categoryBreakdown: [CategoryCount]
    let dailyActivity: [DateActivity]
    let currentStreak: Int
    let longestStreak: Int
    let mostFavoritedTitle: String?
    let oldestUnreadTitle: String?
    let brokenLinksCount: Int
    let totalLinksWithUrl: Int
    let brokenLinks: [BookmarkSnapshot]
    let staleBookmarksCount: Int
    let timeOfDayBreakdown: [TimeOfDayCount]
    let mostActiveDay: String?
}

struct BookmarkSnapshot: Identifiable, Sendable {
    let id: UUID
    let title: String
    let url: String?
}

// MARK: - ViewModel

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var totalBookmarks: Int = 0
    @Published var thisWeekCount: Int = 0
    @Published var readCount: Int = 0
    @Published var unreadCount: Int = 0
    @Published var favoriteCount: Int = 0
    @Published var categoryCount: Int = 0
    @Published var activityWindow: Int = 30 // 30 or 90 days
    
    @Published var platformBreakdown: [PlatformCount] = []
    @Published var categoryBreakdown: [CategoryCount] = []
    @Published var dailyActivity: [DateActivity] = []
    
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    
    @Published var mostFavoritedTitle: String?
    @Published var oldestUnreadTitle: String?
    
    @Published var brokenLinks: [BookmarkSnapshot] = []
    @Published var staleBookmarksCount: Int = 0
    @Published var timeOfDayBreakdown: [TimeOfDayCount] = []
    @Published var mostActiveDay: String?
    @Published var linkHealth: LinkHealthStats = LinkHealthStats()
    
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func refreshData() async {
        isLoading = true
        
        let container = modelContext.container
        let window = activityWindow
        
        // Bu işlemi tamamen main thread dışına taşıyoruz
        let result = await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            // static ve nonisolated olduğu için main thread'e jump yapmaz
            return AnalyticsViewModel.performBackgroundCalculations(context: context, window: window)
        }.value
        
        // UI Güncelleme
        applyResult(result)
        
        // Phase 2: Link Health Check (Asenkron olarak başlasın, UI'ı bloklamasın)
        Task {
            await checkLinkHealth()
        }
        
        isLoading = false
    }
    
    private func applyResult(_ data: AnalyticsData) {
        self.totalBookmarks = data.totalBookmarks
        self.thisWeekCount = data.thisWeekCount
        self.readCount = data.readCount
        self.unreadCount = data.totalBookmarks - data.readCount
        self.favoriteCount = data.favoriteCount
        self.categoryCount = data.categoryCount
        self.platformBreakdown = data.platformBreakdown
        self.categoryBreakdown = data.categoryBreakdown
        self.dailyActivity = data.dailyActivity
        self.currentStreak = data.currentStreak
        self.longestStreak = data.longestStreak
        self.mostFavoritedTitle = data.mostFavoritedTitle
        self.oldestUnreadTitle = data.oldestUnreadTitle
        self.brokenLinks = data.brokenLinks
        self.staleBookmarksCount = data.staleBookmarksCount
        self.timeOfDayBreakdown = data.timeOfDayBreakdown
        self.mostActiveDay = data.mostActiveDay
        self.linkHealth = LinkHealthStats(
            active: 0,
            broken: 0,
            checking: data.totalLinksWithUrl
        )
    }
    
    // nonisolated - Runs truly in background without locking MainActor
    private nonisolated static func performBackgroundCalculations(context: ModelContext, window: Int) -> AnalyticsData {
        let calendar = Calendar.current
        let now = Date()
        
        // 1. Overview counts (Optimized with fetchCount if possible)
        let totalCount = (try? context.fetchCount(FetchDescriptor<Bookmark>())) ?? 0
        
        let readDescriptor = FetchDescriptor<Bookmark>(predicate: #Predicate<Bookmark> { $0.isRead })
        let readCount = (try? context.fetchCount(readDescriptor)) ?? 0
        
        let favoriteDescriptor = FetchDescriptor<Bookmark>(predicate: #Predicate<Bookmark> { $0.isFavorite })
        let favoriteCount = (try? context.fetchCount(favoriteDescriptor)) ?? 0
        
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let thisWeekDescriptor = FetchDescriptor<Bookmark>(predicate: #Predicate<Bookmark> { $0.createdAt >= startOfWeek })
        let thisWeekCount = (try? context.fetchCount(thisWeekDescriptor)) ?? 0
        
        let catCount = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        
        let urlDescriptor = FetchDescriptor<Bookmark>(predicate: #Predicate<Bookmark> { $0.url != nil })
        let totalWithUrl = (try? context.fetchCount(urlDescriptor)) ?? 0
        
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        let staleDescriptor = FetchDescriptor<Bookmark>(predicate: #Predicate<Bookmark> { !$0.isRead && $0.createdAt <= sixMonthsAgo })
        let staleCount = (try? context.fetchCount(staleDescriptor)) ?? 0
        
        // 2. Fetch all for complex aggregations
        let allBookmarks = (try? context.fetch(FetchDescriptor<Bookmark>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let allCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        
        // 3. Platform Breakdown
        var sourceMap: [BookmarkSource: Int] = [:]
        for b in allBookmarks {
            sourceMap[b.source, default: 0] += 1
        }
        let platformBreakdown = sourceMap.map { PlatformCount(source: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        // 4. Category Breakdown
        var catCounts: [UUID: Int] = [:]
        for b in allBookmarks {
            if let cid = b.categoryId {
                catCounts[cid, default: 0] += 1
            }
        }
        var categoryBreakdown = allCategories.compactMap { cat -> CategoryCount? in
            let count = catCounts[cat.id] ?? 0
            guard count > 0 else { return nil }
            return CategoryCount(id: cat.id, name: cat.name, icon: cat.icon, colorHex: cat.colorHex, count: count)
        }
        
        // Uncategorized
        let uncategorizedCount = allBookmarks.filter { $0.categoryId == nil }.count
        if uncategorizedCount > 0 {
            categoryBreakdown.append(CategoryCount(
                id: UUID(), // Dummy ID for UI
                name: String(localized: "common.uncategorized"),
                icon: "questionmark.folder",
                colorHex: "#6B7280",
                count: uncategorizedCount
            ))
        }
        categoryBreakdown.sort { $0.count > $1.count }
        
        // 5. Daily Activity
        let today = calendar.startOfDay(for: now)
        let nDaysAgo = calendar.date(byAdding: .day, value: -(window - 1), to: today) ?? today
        
        var activityMap: [Date: Int] = [:]
        for b in allBookmarks where b.createdAt >= nDaysAgo {
            let day = calendar.startOfDay(for: b.createdAt)
            activityMap[day, default: 0] += 1
        }
        
        var dailyActivity: [DateActivity] = []
        for i in 0..<window {
            if let date = calendar.date(byAdding: .day, value: i, to: nDaysAgo) {
                dailyActivity.append(DateActivity(date: date, count: activityMap[date] ?? 0))
            }
        }
        
        // 5.1 Time of Day Breakdown
        var morning = 0   // 6-12
        var afternoon = 0 // 12-18
        var evening = 0   // 18-24
        var night = 0     // 0-6
        
        for b in allBookmarks {
            let hour = calendar.component(.hour, from: b.createdAt)
            switch hour {
            case 6..<12: morning += 1
            case 12..<18: afternoon += 1
            case 18..<24: evening += 1
            default: night += 1
            }
        }
        
        let timeOfDayBreakdown = [
            TimeOfDayCount(label: "morning", count: morning, icon: "sun.max.fill"),
            TimeOfDayCount(label: "afternoon", count: afternoon, icon: "sun.horizon.fill"),
            TimeOfDayCount(label: "evening", count: evening, icon: "moon.stars.fill"),
            TimeOfDayCount(label: "night", count: night, icon: "sparkles")
        ]
        
        // 6. Streaks
        let uniqueDays = Set(allBookmarks.map { calendar.startOfDay(for: $0.createdAt) }).sorted(by: >)
        var currentStreak = 0
        if !uniqueDays.isEmpty {
            var checkDate = today
            if !uniqueDays.contains(today) {
                checkDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            }
            
            for date in uniqueDays {
                if calendar.isDate(date, inSameDayAs: checkDate) {
                    currentStreak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                } else if date < checkDate {
                    break
                }
            }
        }
        
        var longestStreak = 0
        var tempStreak = 0
        var lastStreakDate: Date?
        for date in uniqueDays.reversed() {
            if let last = lastStreakDate, let next = calendar.date(byAdding: .day, value: 1, to: last), calendar.isDate(date, inSameDayAs: next) {
                tempStreak += 1
            } else {
                tempStreak = 1
            }
            lastStreakDate = date
            longestStreak = max(longestStreak, tempStreak)
        }
        
        // 6.1 Most Active Day of Week
        var weekdayMap: [Int: Int] = [:]
        for b in allBookmarks {
            let day = calendar.component(.weekday, from: b.createdAt)
            weekdayMap[day, default: 0] += 1
        }
        let mostActiveDayNum = weekdayMap.max(by: { $0.value < $1.value })?.key
        let mostActiveDay: String?
        if let dayNum = mostActiveDayNum {
            let formatter = DateFormatter()
            // Burası background thread'de olduğu için shared'dan güvenli okuma yapmalı 
            // Veya direkt sisteme bırakmalı ama biz App seviyesindeki dili istiyoruz.
            // LanguageManager.shared thread-safe mi? currentLanguage bir struct olduğu için kopyası güvenli olmalı.
            formatter.locale = LanguageManager.shared.currentLanguage.locale
            mostActiveDay = formatter.standaloneWeekdaySymbols[dayNum - 1].capitalized
        } else {
            mostActiveDay = nil
        }
        
        // 7. Highlights
        let mostFavoritedTitle = allBookmarks.filter { $0.isFavorite }.last?.title
        let oldestUnreadTitle = allBookmarks.filter { !$0.isRead }.first?.title
        
        // 8. Link Health (Quick count of known broken - if we had a field, otherwise we'll check later)
        // For now, let's assume we don't have a 'isBroken' field in Bookmark model, 
        // but we'll implement a real check in another method.
        
        return AnalyticsData(
            totalBookmarks: totalCount,
            thisWeekCount: thisWeekCount,
            readCount: readCount,
            favoriteCount: favoriteCount,
            categoryCount: catCount,
            platformBreakdown: platformBreakdown,
            categoryBreakdown: categoryBreakdown,
            dailyActivity: dailyActivity,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            mostFavoritedTitle: mostFavoritedTitle,
            oldestUnreadTitle: oldestUnreadTitle,
            brokenLinksCount: 0, // Placeholder
            totalLinksWithUrl: totalWithUrl,
            brokenLinks: [],      // Placeholder
            staleBookmarksCount: staleCount,
            timeOfDayBreakdown: timeOfDayBreakdown,
            mostActiveDay: mostActiveDay
        )
    }
    
    /// Per-link health check (Phase 2)
    func checkLinkHealth() async {
        let container = modelContext.container
        
        // Fetch all bookmarks with URLs
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate<Bookmark> { $0.url != nil })
        guard let bookmarks = try? context.fetch(descriptor) else { return }
        
        var activeCount = 0
        var brokenLinksList: [BookmarkSnapshot] = []
        
        // We check links in parallel with a limit
        await withTaskGroup(of: (BookmarkSnapshot?, Bool).self) { group in
            for bookmark in bookmarks {
                guard let urlString = bookmark.url, let url = URL(string: urlString) else { continue }
                let snapshot = BookmarkSnapshot(id: bookmark.id, title: bookmark.title, url: bookmark.url)
                
                group.addTask {
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 5
                    
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        if let httpResponse = response as? HTTPURLResponse, (200...399).contains(httpResponse.statusCode) {
                            return (nil, true)
                        } else {
                            return (snapshot, false)
                        }
                    } catch {
                        return (snapshot, false)
                    }
                }
            }
            
            for await (snapshot, isAlive) in group {
                if isAlive {
                    activeCount += 1
                } else if let snapshot = snapshot {
                    brokenLinksList.append(snapshot)
                }
            }
        }
        
        let broken = brokenLinksList.count
        
        // Update UI
        self.brokenLinks = brokenLinksList
        self.linkHealth = LinkHealthStats(active: activeCount, broken: broken, checking: 0)
    }
}
