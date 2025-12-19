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
        
        // 3. Auth başlat
        Task { @MainActor in
            await ensureUserAuthenticated()
        }
        
        // 4. Network değişikliklerini dinle
        setupNetworkObserver()
    }
    
    /// Kullanıcının authenticate olduğundan emin ol
    @MainActor
    private func ensureUserAuthenticated() async {
        guard NetworkMonitor.shared.isConnected else {
            print("⚠️ [APP] No internet, skipping authentication")
            return
        }
        
        do {
            let user = try await AuthService.shared.ensureAuthenticated()
            print("✅ [APP] User authenticated: \(user.id)")
            
            // İlk sync'i başlat
            await performInitialSync()
            
        } catch {
            print("⚠️ [APP] Authentication failed: \(error.localizedDescription)")
        }
    }
    
    /// İlk sync'i yap
    @MainActor
    private func performInitialSync() async {
        print("🔄 [APP] Starting initial sync...")
        SyncService.shared.startAutoSync()
        await SyncService.shared.performFullSync()
    }
    
    /// Network durumu değişikliklerini dinle
    private func setupNetworkObserver() {
        NotificationCenter.default.addObserver(
            forName: .networkDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            print("📡 [APP] Network connected - syncing...")
            Task { @MainActor in
                await self.ensureUserAuthenticated()
            }
        }
    }
}

// MARK: - Root View with Supabase

struct RootView: View {
    // MARK: - Properties
    
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var syncService = SyncService.shared
    
    let homeViewModel: HomeViewModel
    var requireExplicitSignIn: Bool = false
    
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
                
                Text("Yükleniyor...")
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
        
        if sessionStore.isAuthenticated {
            SyncService.shared.startAutoSync()
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
