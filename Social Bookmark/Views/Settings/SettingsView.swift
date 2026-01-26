//
//  SettingsView.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//
//  Ana ayarlar sayfası
//

import SwiftUI
import SwiftData
internal import PostgREST
import Supabase
import RevenueCat

struct SettingsView: View {
    
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject private var languageManager = LanguageManager.shared
    @StateObject private var syncService = SyncService.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.modelContext) private var modelContext  // ✅ BU SATIRI EKLE
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    
    @State private var showingRestartAlert = false
    @State private var pendingLanguage: AppLanguage?
    
    var body: some View {
        NavigationStack {
            List {
                // Pro Banner (Eğer Pro değilse)
                if !subscriptionManager.isPro {
                    proBannerSection
                }
                
                // Hesap bölümü
                accountSection
                
                // Senkronizasyon
                syncSection
                
                // Görünüm
                appearanceSection
                
                // Uygulama hakkında
                aboutSection
            }
            .navigationTitle(languageManager.localized("settings.title"))
            .toolbarTitleDisplayMode(.inline)
            .alert(languageManager.localized("settings.language_change_title"), isPresented: $showingRestartAlert) {
                Button(languageManager.localized("settings.restart_now")) {
                    if let language = pendingLanguage {
                        languageManager.currentLanguage = language
                        languageManager.restartApp()
                    }
                }
                Button(languageManager.localized("settings.restart_later"), role: .cancel) {
                    if let language = pendingLanguage {
                        languageManager.currentLanguage = language
                    }
                    pendingLanguage = nil
                }
            } message: {
                Text(languageManager.localized("settings.language_change_message"))
            }
        }
        .id(languageManager.refreshID)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
    
    // Fonksiyonlar:

    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            if sessionStore.isAuthenticated {
                NavigationLink {
                    AccountSettingsView()
                        .environmentObject(sessionStore)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            if sessionStore.isAnonymous {
                                Image(systemName: "person.crop.circle.badge.exclamationmark.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.orange)
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray)
                            }
                        }
                        
                        Text(sessionStore.nameForDisplay)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if subscriptionManager.isPro {
                            ProBadge()
                        }
                        
                        Spacer()
                        
                        
                    }
                }
            } else {
                NavigationLink {
                    SignInView()
                } label: {
                    Label(languageManager.localized("auth.sign_in"), systemImage: "person.crop.circle")
                }
            }
        } header: {
            Text(languageManager.localized("settings.account"))
        }
    }
    
    // MARK: - Pro Banner
    
    private var proBannerSection: some View {
        Section {
            Button {
                showingPaywall = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.white)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(languageManager.localized("settings.pro_banner_title"))
                            .font(.headline)
                        
                        Text(languageManager.localized("settings.pro_banner_subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Sync Section
    
    private var syncSection: some View {
        Section {
            NavigationLink {
                SyncSettingsView()
                    .environmentObject(sessionStore)
            } label: {
                HStack {
                    Label(languageManager.localized("settings.sync"), systemImage: "arrow.triangle.2.circlepath")
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if syncService.syncState == .syncing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        
                        SyncStatusBadge()
                    }
                }
            }
            
            if sessionStore.isAuthenticated && networkMonitor.isConnected {
                Button {
                    Task {
                        await syncService.syncChanges()
                    }
                } label: {
                    HStack {
                        Label(languageManager.localized("sync.sync_now"), systemImage: "arrow.clockwise")
                        
                        Spacer()
                        
                        if syncService.syncState == .syncing {
                            ProgressView()
                        }
                    }
                }
                .disabled(syncService.syncState == .syncing)
            }
        } header: {
            Text(languageManager.localized("settings.sync_section"))
        } footer: {
            if let lastSync = syncService.lastSyncDate {
                HStack(spacing: 4) {
                    Text(String(localized: "sync.last_sync_footer"))
                    Text(lastSync, style: .relative)
                }
            }
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        Section {
            // Dil seçimi - Picker yerine manuel liste
            ForEach(AppLanguage.allCases) { language in
                Button {
                    if language != languageManager.currentLanguage {
                        pendingLanguage = language
                        showingRestartAlert = true
                    }
                } label: {
                    HStack {
                        Text(language.displayName)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if language == languageManager.currentLanguage {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            
        } header: {
            Text(languageManager.localized("settings.language"))
        } footer: {
            Text(languageManager.localized("settings.language_footer"))
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            Button {
                ReviewManager.shared.requestReviewManually()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(languageManager.localized("settings.rate_app"))
                        Text(languageManager.localized("settings.rate_app_desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }
            
            HStack {
                Text(languageManager.localized("settings.version"))
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text(languageManager.localized("settings.build"))
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                let url = URL(string: "mailto:softaideveloper@gmail.com")!
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else {
                    print("❌ Error: Mail app not available (common in simulator)")
                }
            } label: {
                Label(languageManager.localized("settings.contact"), systemImage: "envelope")
            }
        } header: {
            Text(languageManager.localized("settings.about"))
        }
    }
    
    // MARK: - Helpers
    
    private var syncStatusText: String {
        switch syncService.syncState {
        case .idle: return languageManager.localized("settings.synced")
        case .syncing: return languageManager.localized("sync.state.syncing")
        case .offline: return languageManager.localized("sync.state.offline")
        case .error: return languageManager.localized("sync.state.error")
        default: return ""
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(SessionStore())
}
