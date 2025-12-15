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
        do {
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Social_BookmarkApp.appGroupID
            ) else { fatalError("App Group container bulunamadı") }

            let storeURL = containerURL.appendingPathComponent("bookmark.sqlite")

            let configuration = ModelConfiguration(
                url: storeURL,
                allowsSave: true
            )

            modelContainer = try ModelContainer(
                for: Bookmark.self, Category.self,
                configurations: configuration
            )
        } catch {
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }

        // 1) Önce repository’ler
        bookmarkRepository = BookmarkRepository(modelContext: modelContainer.mainContext)
        categoryRepository = CategoryRepository(modelContext: modelContainer.mainContext)

        // 2) Sonra supabase
        initializeSupabase()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
                   // ✨ RootView ile wrap et
                   RootView(
                       homeViewModel: HomeViewModel(
                           bookmarkRepository: bookmarkRepository,
                           categoryRepository: categoryRepository
                       )
                   )
                   .environment(\.locale, appLanguage.locale)
               }
               .modelContainer(modelContainer)
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguageRawValue) ?? .system
    }
    
    
}
