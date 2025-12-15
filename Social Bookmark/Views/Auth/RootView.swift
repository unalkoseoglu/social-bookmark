//
//  Social_BookmarkApp+Supabase.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//
//  ⚠️ GÜNCELLEME: Session persistence sorunu düzeltildi
//  - ensureAuthenticated() kullanılıyor
//  - Mevcut session varsa yeni giriş yapılmıyor
//

import SwiftUI
import SwiftData

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
            // Config eksikse crash etme, offline çalışabilir
        }
        
        // 2. SyncService'i configure et
        SyncService.shared.configure(modelContext: modelContainer.mainContext)
        
        // 3. Auth başlat - ✅ ensureAuthenticated kullan
        Task { @MainActor in
            await ensureUserAuthenticated()
        }
        
        // 4. Network değişikliklerini dinle
        setupNetworkObserver()
    }
    
    /// ✅ Kullanıcının authenticate olduğundan emin ol
    /// Mevcut session varsa kullanır, yoksa anonim giriş yapar
    @MainActor
    private func ensureUserAuthenticated() async {
        // İnternet yoksa çık
        guard NetworkMonitor.shared.isConnected else {
            print("⚠️ [APP] No internet, skipping authentication")
            return
        }
        
        do {
            // ✅ ensureAuthenticated mevcut session'ı kontrol eder
            // Eğer varsa yeni giriş yapmaz!
            let user = try await AuthService.shared.ensureAuthenticated()
        
            
            // Debug bilgisi (async)
            await SupabaseManager.shared.printSessionDebugInfo()
            
        } catch {
            print("⚠️ [APP] Authentication failed: \(error.localizedDescription)")
            // Hata olursa offline çalış, kritik değil
        }
    }
    
    /// Network durumu değişikliklerini dinle
    private func setupNetworkObserver() {
        NotificationCenter.default.addObserver(
            forName: .networkDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            print("📡 [APP] Network connected - checking auth...")
            Task { @MainActor in
                // Bağlantı geldiğinde auth kontrol et
                await self.ensureUserAuthenticated()
                // TODO: SyncManager.shared.syncPendingChanges()
            }
        }
    }
}

// MARK: - Root View with Supabase

/// Ana view'ı Supabase ile wrap et
/// body içinde HomeView yerine bunu kullan
struct RootView: View {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    // ViewModel'ler
    let homeViewModel: HomeViewModel
    
    /// İlk açılışta SignIn gösterilsin mi?
    /// true = her zaman SignIn göster (kullanıcı seçsin)
    /// false = otomatik anonim giriş yap
    var requireExplicitSignIn: Bool = false
    
    var body: some View {
        Group {
            if sessionStore.isLoading {
                // Yükleniyor
                loadingView
            } else if !sessionStore.isAuthenticated && requireExplicitSignIn {
                // Giriş gerekli
                SignInView()
                    .environmentObject(sessionStore)
            } else {
                // Ana uygulama
                HomeView(viewModel: homeViewModel)
                    .environmentObject(sessionStore)
                    .withSupabase()
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
                
                Text("common.loading")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeAuth() async {
        // Session'ı initialize et
        await sessionStore.initialize()
        
        // Eğer explicit sign-in gerekmiyorsa ve kullanıcı yoksa, anonim giriş yap
        if !requireExplicitSignIn && !sessionStore.isAuthenticated && networkMonitor.isConnected {
            await sessionStore.ensureAuthenticated()
        }
        
        // Authenticated ise auto-sync başlat
        if sessionStore.isAuthenticated {
            SyncService.shared.startAutoSync()
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        Text("RootView Preview")
            .withSupabase()
            .offlineBanner()
    }
}
#endif
