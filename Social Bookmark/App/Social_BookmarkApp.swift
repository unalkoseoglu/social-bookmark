//
//  Social_BookmarkApp.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//
//  ✅ DÜZELTME: SyncableRepository'ler kullanılıyor

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
@main
struct Social_BookmarkApp: App {
    // MARK: - Properties

    /// SwiftData container - veritabanı yöneticisi
    let modelContainer: ModelContainer

    /// Bookmark repository - app genelinde paylaşılan
    /// ✅ DÜZELTME: SyncableBookmarkRepository kullanılıyor
    let bookmarkRepository: BookmarkRepositoryProtocol
    
    /// Category repository - kategori yönetimi
    /// ✅ DÜZELTME: SyncableCategoryRepository kullanılıyor
    let categoryRepository: CategoryRepositoryProtocol

    /// App Group ID - Extension ile paylaşım için
    static let appGroupID = "group.com.unal.socialbookmark"
    
    // MARK: - Initialization
    
    @available(iOS 17.6, *)
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

        // ✅ DÜZELTME: Base repository'leri oluştur
        let baseBookmarkRepo = BookmarkRepository(modelContext: modelContainer.mainContext)
        let baseCategoryRepo = CategoryRepository(modelContext: modelContainer.mainContext)
        
        // ✅ DÜZELTME: Syncable wrapper'larla wrap et
        // Bu sayede her CRUD işleminden sonra otomatik sync tetiklenir
        bookmarkRepository = SyncableBookmarkRepository(baseRepository: baseBookmarkRepo)
        categoryRepository = SyncableCategoryRepository(baseRepository: baseCategoryRepo)

        // ✅ AccountMigrationService'i ModelContext ile configure et
        AccountMigrationService.shared.configure(modelContext: modelContainer.mainContext)

        // Supabase başlat
        initializeSupabase()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            RootView(
                homeViewModel: HomeViewModel(
                    bookmarkRepository: bookmarkRepository,
                    categoryRepository: categoryRepository
                )
            )
            .environment(\.locale, LanguageManager.shared.currentLanguage.locale)
        }
        .modelContainer(modelContainer)
    }
}
