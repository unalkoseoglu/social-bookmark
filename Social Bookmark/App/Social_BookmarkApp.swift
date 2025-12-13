import SwiftUI
import SwiftData

@main
struct Social_BookmarkApp: App {
    // MARK: - Properties
    
    /// SwiftData container - veritabanı yöneticisi
    let modelContainer: ModelContainer
    
    /// Bookmark repository - app genelinde paylaşılan
    let bookmarkRepository: BookmarkRepositoryProtocol
    
    /// App Group ID - Extension ile paylaşım için
    static let appGroupID = "group.com.unal.socialbookmark" // DEĞIŞTIR!
    
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
            
            modelContainer = try ModelContainer(
                for: Bookmark.self,
                configurations: configuration
            )
        } catch {
            // Veritabanı oluşturulamazsa uygulama başlatılamaz
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
        
        // 2. Repository'yi başlat
        // mainContext: ana thread'de çalışan context
        bookmarkRepository = BookmarkRepository(
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
            // Ana ekran: Bookmark listesi
            BookmarkListView(
                viewModel: BookmarkListViewModel(repository: bookmarkRepository)
            )
        }
        // Model container'ı tüm view hierarchy'e enjekte et
        .modelContainer(modelContainer)
    }
    
    // MARK: - Sample Data (Development)
    
    /// İlk açılışta örnek data ekle
    private func addSampleDataIfNeeded() {
        let context = modelContainer.mainContext
        let repository = BookmarkRepository(modelContext: context)
        
        // Eğer hiç bookmark yoksa örnek ekle
        guard repository.count == 0 else { return }
        
        let samples = [
            Bookmark(
                title: "SwiftUI Documentation",
                url: "https://developer.apple.com/documentation/swiftui",
                note: "Official SwiftUI docs - read before starting project",
                source: .article,
                tags: ["Swift", "iOS", "Documentation"]
            ),
            Bookmark(
                title: "Thread: Async/Await Best Practices",
                url: "https://twitter.com/johnsundell/status/123456",
                note: "Great explanation of structured concurrency",
                source: .twitter,
                tags: ["Swift", "Concurrency"]
            ),
            Bookmark(
                title: "Building a Bookmark App",
                url: "https://medium.com/@developer/bookmark-app",
                note: "Similar project, good UI ideas",
                source: .medium,
                tags: ["iOS", "Tutorial"]
            )
        ]
        
        for sample in samples {
            repository.create(sample)
        }
        
        print("✅ Sample data added: \(samples.count) bookmarks")
    }
}
