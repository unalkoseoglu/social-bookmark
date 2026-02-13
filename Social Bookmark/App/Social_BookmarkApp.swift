//
//  Social_BookmarkApp.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//
//  ✅ DÜZELTME: SyncableRepository'ler kullanılıyor

import SwiftUI
import SwiftData
import OneSignalFramework

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // UNUserNotificationCenterDelegate set et
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        // Sadece teknik kayıt (Authorized ise token döner)
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationManager.shared.handleDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationManager.shared.handleRegistrationError(error)
    }
}

@available(iOS 17.0, *)
@main
struct Social_BookmarkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    /// SwiftData container
    let modelContainer: ModelContainer
    
    @ObservedObject private var languageManager = LanguageManager.shared
    
    // MARK: - Initialization
    
    @available(iOS 17.0, *)
    init() {
        do {
            let appGroupID = "group.com.unal.socialbookmark"
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID
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

        // Services initialization
        AccountMigrationService.shared.configure(modelContext: modelContainer.mainContext)
        initializeOneSignal(launchOptions: nil)
        SubscriptionManager.shared.configure()
        ReviewManager.shared.logLaunch()
    }
    
    var body: some Scene {
        WindowGroup {
            LanguageWrapperView(modelContainer: modelContainer)
                .environment(\.locale, languageManager.currentLanguage.locale)
                .id(languageManager.refreshID)
        }
        .modelContainer(modelContainer)
    }
}

/// A wrapper view that handles the lifecycle of the Main ViewModel and reacts to language changes.
@available(iOS 17.0, *)
struct LanguageWrapperView: View {
    let modelContainer: ModelContainer
    
    @State private var homeViewModel: HomeViewModel
    let bookmarkRepository: BookmarkRepositoryProtocol
    let categoryRepository: CategoryRepositoryProtocol
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        
        let baseBookmarkRepo = BookmarkRepository(modelContext: modelContainer.mainContext)
        let baseCategoryRepo = CategoryRepository(modelContext: modelContainer.mainContext)
        
        let bRepo = SyncableBookmarkRepository(baseRepository: baseBookmarkRepo)
        let cRepo = SyncableCategoryRepository(baseRepository: baseCategoryRepo)
        
        self.bookmarkRepository = bRepo
        self.categoryRepository = cRepo
        
        let vm = HomeViewModel(
            bookmarkRepository: bRepo,
            categoryRepository: cRepo
        )
        _homeViewModel = State(initialValue: vm)
    }
    
    var body: some View {
        RootView(homeViewModel: homeViewModel)
            .onAppear {
                SyncService.shared.configure(modelContext: modelContainer.mainContext)
                
                // Process any pending inbox payloads from Share Extension
                Task {
                    let inboxService = InboxProcessingService(modelContext: modelContainer.mainContext)
                    await inboxService.processPendingPayloads()
                }
            }
    }
}
