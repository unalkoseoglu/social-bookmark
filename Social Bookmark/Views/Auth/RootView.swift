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
import Supabase

// MARK: - App Initialization Extension

extension Social_BookmarkApp {
    
    /// Supabase servislerini başlat
    /// init() içinde çağrılmalı
    func initializeSupabase() {
        // 1. Config doğrula
        let configStatus = SupabaseConfig.validate()
        
        switch configStatus {
        case .valid:
            print("✅ Supabase config valid")
        case .invalid(let issues):
            print("⚠️ Supabase config issues: \(issues)")
        }
        
        // 2. SyncService'i configure et
        SyncService.shared.configure(modelContext: modelContainer.mainContext)
        
        // 3. Network değişikliklerini dinle
        setupNetworkObserver()
    }
    
    /// Network durumu değişikliklerini dinle
    private func setupNetworkObserver() {
        NotificationCenter.default.addObserver(
            forName: .networkDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            print("📡 [APP] Network connected - will sync on next app active")
        }
    }
}

// MARK: - Root View with Supabase

struct RootView: View {
    // MARK: - Properties
    
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var syncService = SyncService.shared
    
    @Environment(\.scenePhase) private var scenePhase
    
    let homeViewModel: HomeViewModel
    var requireExplicitSignIn: Bool = false
    
    /// İlk açılışta sync yapıldı mı?
    @State private var hasPerformedInitialSync = false
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sessionStore.isLoading {
                loadingView
            } else if !sessionStore.isAuthenticated && requireExplicitSignIn {
                NavigationStack {
                    SignInView()
                        .environmentObject(sessionStore)
                }
            } else {
                // Ana uygulama - NavigationStack YOK, her tab kendi yönetiyor
                AdaptiveMainTabView(viewModel: homeViewModel)
                    .environmentObject(sessionStore)
                    .offlineBanner()
            }
        }
        .task {
            await initializeAuth()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(String(localized: "common.loading"))
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
        await sessionStore.initialize()
        
        if !requireExplicitSignIn && !sessionStore.isAuthenticated && networkMonitor.isConnected {
            await sessionStore.ensureAuthenticated()
        }
        
        // İlk açılışta sync yap
        if sessionStore.isAuthenticated && !hasPerformedInitialSync {
            await performInitialSync()
        }
    }
    
    // MARK: - Scene Phase Handling
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // Uygulama aktif olduğunda (açılış veya arka plandan dönüş)
            print("📱 [APP] Scene became active")
            
            if sessionStore.isAuthenticated && networkMonitor.isConnected {
                Task {
                    await performSyncOnAppActive()
                }
            }
            
        case .inactive:
            print("📱 [APP] Scene became inactive")
            
        case .background:
            // Arka plana geçerken son değişiklikleri kaydet
            print("📱 [APP] Scene went to background")
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Sync Methods
    
    /// İlk açılışta tam sync
    private func performInitialSync() async {
        guard !hasPerformedInitialSync else { return }
        
        print("🔄 [APP] Performing initial sync...")
        hasPerformedInitialSync = true
        
        // Auto-sync'i başlat
        SyncService.shared.startAutoSync()
        
        // Tam sync yap (önce download, sonra upload)
        await syncService.performFullSync()
        
        // ViewModel'i yenile
        homeViewModel.refresh()
    }
    
    /// Uygulama aktif olduğunda sync
    private func performSyncOnAppActive() async {
        // Zaten sync yapılıyorsa atla
        guard syncService.syncState != .syncing else {
            print("⏭️ [APP] Sync already in progress, skipping")
            return
        }
        
        // Son sync'ten bu yana 1 dakika geçtiyse sync yap
        if let lastSync = syncService.lastSyncDate {
            let timeSinceLastSync = Date().timeIntervalSince(lastSync)
            
            if timeSinceLastSync < 60 {
                print("⏭️ [APP] Last sync was \(Int(timeSinceLastSync))s ago, skipping")
                return
            }
        }
        
        print("🔄 [APP] Syncing on app active...")
        await syncService.performFullSync()
        
        // ViewModel'i yenile
        await MainActor.run {
            homeViewModel.refresh()
        }
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
