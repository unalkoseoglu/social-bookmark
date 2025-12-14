import SwiftUI
import SwiftData

@main
struct Social_BookmarkApp: App {
    // MARK: - Properties

    /// SwiftData container - veritabanı yöneticisi
    let modelContainer: ModelContainer

    /// Bookmark repository - app genelinde paylaşılan
    let bookmarkRepository: BookmarkRepositoryProtocol
    
    /// Category repository - kategori yönetimi
    let categoryRepository: CategoryRepositoryProtocol

    /// Seçilen uygulama dili - Mevcut AppLanguage enum'unu kullanıyor
    @AppStorage(AppLanguage.storageKey)
    private var selectedLanguageRawValue = AppLanguage.system.rawValue

    /// App Group ID - Extension ile paylaşım için
    static let appGroupID = "group.com.unal.socialbookmark"
    
    // MARK: - Initialization
    
    init() {
        // 1. Model container oluştur (App Group ile)
        do {
            // Shared container URL'i al
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Social_BookmarkApp.appGroupID
            ) else {
                fatalError("App Group container bulunamadı")
            }
            
            // Database dosya path'i
            let storeURL = containerURL.appendingPathComponent("bookmark.sqlite")
            
            // ModelConfiguration ile shared container kullan
            let configuration = ModelConfiguration(
                url: storeURL,
                allowsSave: true
            )
            
            // Hem Bookmark hem Category modellerini kaydet
            modelContainer = try ModelContainer(
                for: Bookmark.self, Category.self,
                configurations: configuration
            )
        } catch {
            // Veritabanı oluşturulamazsa uygulama başlatılamaz
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
        
        // 2. Repository'leri başlat
        bookmarkRepository = BookmarkRepository(
            modelContext: modelContainer.mainContext
        )
        
        categoryRepository = CategoryRepository(
            modelContext: modelContainer.mainContext
        )
        
        // 3. İlk açılışta test datası ekle (geliştirme için)
        #if DEBUG
        addSampleDataIfNeeded()
        #endif
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            // Yeni ana ekran: Dashboard style HomeView
            HomeView(
                viewModel: HomeViewModel(
                    bookmarkRepository: bookmarkRepository,
                    categoryRepository: categoryRepository
                )
            )
            .environment(\.locale, appLanguage.locale)
        }
        // Model container'ı tüm view hierarchy'e enjekte et
        .modelContainer(modelContainer)
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguageRawValue) ?? .system
    }
    
    // MARK: - Sample Data (Debug)
    
    #if DEBUG
    private func addSampleDataIfNeeded() {
        // Bookmark var mı kontrol et
        guard bookmarkRepository.count == 0 else { return }
        
        // Örnek bookmarklar ekle
        let sampleBookmarks = [
            Bookmark(
                title: "SwiftUI ile Modern iOS Geliştirme",
                url: "https://developer.apple.com/swiftui",
                note: "Apple'ın resmi SwiftUI dokümantasyonu",
                source: .article,
                tags: ["swift", "ios", "swiftui"],
                
            ),
            Bookmark(
                title: "iOS 18'deki yenilikler hakkında thread",
                url: "https://twitter.com/example/status/123456",
                note: "WWDC 2024 özeti",
                source: .twitter,
                tags: ["ios", "wwdc"]
            ),
            Bookmark(
                title: "SwiftData vs Core Data karşılaştırması",
                url: "https://reddit.com/r/swift/comments/example",
                source: .reddit,
                tags: ["swift", "swiftdata", "coredata"]
            ),
            Bookmark(
                title: "Clean Architecture in Swift",
                url: "https://medium.com/@example/clean-architecture",
                source: .medium,
                tags: ["architecture", "swift"]
            ),
            Bookmark(
                title: "GitHub Copilot ile Kod Yazımı",
                url: "https://github.com/features/copilot",
                source: .github,
                tags: ["ai", "coding"]
            )
        ]
        
        for bookmark in sampleBookmarks {
            bookmarkRepository.create(bookmark)
        }
        
        print("✅ \(sampleBookmarks.count) örnek bookmark eklendi")
    }
    #endif
}
