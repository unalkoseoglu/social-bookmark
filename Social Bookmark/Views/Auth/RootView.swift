//
//  Social_BookmarkApp+Supabase.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//
//  Supabase entegrasyonu - Sync ve Auth
//

import SwiftUI
import SwiftData
import OSLog

// MARK: - App Initialization Extension

extension Social_BookmarkApp {
    
    /// Uygulama servislerini başlat
    func initializeApp() {
        // 1. SyncService'i configure et
        SyncService.shared.configure(modelContext: modelContainer.mainContext)
        
        // 2. Network değişikliklerini dinle
        setupNetworkObserver()
    }
    
    /// Network durumu değişikliklerini dinle
    private func setupNetworkObserver() {
        // TODO: Re-enable when NetworkMonitor is implemented
        // NotificationCenter.default.addObserver(
        //     forName: .networkDidConnect,
        //     object: nil,
        //     queue: .main
        // ) { _ in
        //     print("📡 [APP] Network connected")
        // }
    }
}

// MARK: - Root View with Supabase

struct RootView: View {
    // MARK: - Properties
    @Environment(\.colorScheme) private var colorScheme
    
    @StateObject private var sessionStore = SessionStore.shared
    // @StateObject private var networkMonitor = NetworkMonitor.shared // TODO: Re-enable when NetworkMonitor is implemented
    @StateObject private var syncService = SyncService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    
    @Environment(\.scenePhase) private var scenePhase
    
    let homeViewModel: HomeViewModel
    var requireExplicitSignIn: Bool = false
    
    /// İlk açılışta sync yapıldı mı?
    @State private var hasPerformedInitialSync = false
    @State private var showSplash = false
    
    // Onboarding
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showOnboarding = false
    @State private var showPaywall = false
    @State private var justFinishedOnboarding = false

    // MARK: - Body
    
    var body: some View {
        Group {
            if showSplash || sessionStore.isLoading || languageManager.languageJustChanged {
                loadingView
            } else if !sessionStore.isAuthenticated && requireExplicitSignIn {
                NavigationStack {
                    SignInView()
                        .environmentObject(sessionStore)
                }
            } else {
                // Ana uygulama
                AdaptiveMainTabView(viewModel: homeViewModel)
                    .id(languageManager.refreshID)
                    .environment(\.locale, languageManager.currentLanguage.locale)
                    .environmentObject(sessionStore)
                    // .offlineBanner() // TODO: Re-enable when NetworkMonitor is implemented
                    .fullScreenCover(isPresented: $showOnboarding) {
                        OnboardingView(isPresented: $showOnboarding)
                            .environmentObject(sessionStore)
                            .onDisappear {
                                // Onboarding kapandığında eğer yeni tamamlandıysa ve PRO değilse paywall göster
                                if justFinishedOnboarding && !subscriptionManager.isPro {
                                    showPaywall = true
                                    justFinishedOnboarding = false
                                } else if justFinishedOnboarding {
                                    // Pro ise sadece flag'i sıfırla, paywall gösterme
                                    justFinishedOnboarding = false
                                }
                            }
                    }
                    .sheet(isPresented: $showPaywall) {
                        PaywallView()
                            .environmentObject(sessionStore)
                    }
            }
        }
        .task {
            // Onboarding kontrolü
            if !hasCompletedOnboarding {
                showOnboarding = true
                hasCompletedOnboarding = true
                justFinishedOnboarding = true
            }
            await initializeAuth()
            
            // Dil değişimi sonrası splash gösteriliyorsa kapat
            if languageManager.languageJustChanged {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                languageManager.languageJustChanged = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appShouldRestart)) { _ in
            showSplash = true
            hasPerformedInitialSync = false
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await initializeAuth()
                showSplash = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            showSplash = true
            hasPerformedInitialSync = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { _ in
            print("🔐 [RootView] User signed in - triggering initial sync")
            hasPerformedInitialSync = false
            Task {
                await initializeAuth()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onChange(of: showPaywall) { oldVal, newVal in
            // Paywall kapandığında (yeni kullanıcı akışı)
            if oldVal == true && newVal == false {
                requestNotificationPermissionIfNeeded()
            }
        }
        .environment(\.locale, languageManager.currentLanguage.locale)
    }

    private func requestNotificationPermissionIfNeeded() {
        // Zaten izin verilmişse tekrar sorma
        guard !NotificationManager.shared.isAuthorized else { return }
        
        // Bir saniye bekle ki UI kendine gelsin (sheet kapandıktan hemen sonra çıkmasın)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationManager.shared.requestAuthorization()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(colorScheme == .dark ? "logo_light_app_icon" : "logo_dark_app_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120)
                
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(languageManager.localized("common.loading"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Sync Status Button
    
    private var syncStatusButton: some View {
        Button {
            Task {
                await syncService.performFullSync()
            }
        } label: {
            Group {
                switch syncService.syncState {
                case .idle:
                    Image(systemName: "checkmark.icloud")
                        .foregroundStyle(.green)
                case .syncing, .uploading, .downloading:
                    ProgressView()
                        .scaleEffect(0.8)
                case .offline:
                    Image(systemName: "icloud.slash")
                        .foregroundStyle(.orange)
                case .error:
                    Image(systemName: "exclamationmark.icloud")
                        .foregroundStyle(.red)
                }
            }
        }
        .disabled(syncService.syncState == .syncing)
    }
    
    // MARK: - Auth Initialization
    
    private func initializeAuth() async {
        Logger.sync.info("🔄 [RootView] Initializing auth...")
        
        // SubscriptionManager'ı SessionStore ile bağla
        SubscriptionManager.shared.setupObservers(sessionStore: sessionStore)
        
        await sessionStore.initialize()
        
        Logger.sync.info("🔐 [RootView] Auth initialized. isAuthenticated: \(sessionStore.isAuthenticated)")
        
        if !requireExplicitSignIn && !sessionStore.isAuthenticated {
            Logger.sync.info("🔑 [RootView] Ensuring authentication...")
            await sessionStore.ensureAuthenticated()
            Logger.sync.info("🔐 [RootView] After ensureAuthenticated. isAuthenticated: \(sessionStore.isAuthenticated)")
        }
        
        // 3. Ensure encryption key is loaded before sync
        if sessionStore.isAuthenticated {
            Logger.sync.info("🔐 [RootView] Ensuring encryption key is loaded...")
            do {
                _ = try await EncryptionService.shared.getOrCreateKey()
                Logger.sync.info("✅ [RootView] Encryption key loaded successfully")
            } catch {
                Logger.sync.error("❌ [RootView] Failed to load encryption key: \(error.localizedDescription)")
                // If it failed, maybe the keychain is locked. Sync will proceed but might not decrypt.
            }
            
            Logger.sync.info("✅ [RootView] User authenticated - triggering sync")
            await performInitialSync()
            
            // Mevcut kullanıcılar için (Splash sonrası)
            requestNotificationPermissionIfNeeded()
        } else {
            Logger.sync.warning("⚠️ [RootView] User not authenticated - skipping sync")
        }
    }
    
    // MARK: - Scene Phase Handling
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // Uygulama aktif olduğunda (açılış veya arka plandan dönüş)
            Logger.app.info("Scene became active")
            
            // Only sync if we've already done initial sync (prevents duplicate on first launch)
            // .task handles the very first sync
            if sessionStore.isAuthenticated && hasPerformedInitialSync {
                Logger.sync.info("✅ [RootView] App became active (from background) - triggering sync")
                Task {
                    // Reset flag to allow sync
                    hasPerformedInitialSync = false
                    await performInitialSync()
                }
            }
            
        case .inactive:
            Logger.app.debug("Scene became inactive")
            
        case .background:
            // Arka plana geçerken son değişiklikleri kaydet
            Logger.app.debug("Scene went to background")
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Sync Methods
    
    /// İlk açılışta tam sync
    private func performInitialSync() async {
        // Don't guard on hasPerformedInitialSync - we want sync on every app launch
        Logger.sync.info("🔄 [RootView] Performing initial sync...")
        
        // Mark as performed to prevent duplicate syncs during this session
        hasPerformedInitialSync = true
        
        // Tam sync yap (önce download, sonra upload)
        await syncService.performFullSync()
        
        Logger.sync.info("✅ [RootView] Initial sync complete - refreshing UI")
        
        // ViewModel'i yenile
        await homeViewModel.refresh()
        
        Logger.sync.info("✅ [RootView] UI refresh complete")
    }
    
}

// MARK: - Preview

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(
            homeViewModel: HomeViewModel(
                bookmarkRepository: PreviewMockRepository.shared,
                categoryRepository: PreviewMockCategoryRepository.shared
            )
        )
    }
}
#endif
