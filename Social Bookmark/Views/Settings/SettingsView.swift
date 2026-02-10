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
import RevenueCat

struct SettingsView: View {
    
    @ObservedObject private var sessionStore = SessionStore.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @StateObject private var syncService = SyncService.shared
    // @StateObject private var networkMonitor = NetworkMonitor.shared // TODO: Re-enable when NetworkMonitor is implemented
    @Environment(\.modelContext) private var modelContext  // ✅ BU SATIRI EKLE
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingPaywall = false
    @State private var showingAnalytics = false
    @Bindable var homeViewModel: HomeViewModel
    
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
                
                // Bildirimler
                notificationSection
                
                // Uygulama hakkında
                aboutSection
            }
            .navigationTitle(languageManager.localized("settings.title"))
            .toolbarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingAnalytics) {
            AnalyticsView(modelContext: modelContext, homeViewModel: homeViewModel)
        }
        .onAppear {
            syncService.configure(modelContext: modelContext)
        }
    }
    
    // Fonksiyonlar:

    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            // DEBUG: Print state
            let _ = print("🔍 [SettingsView] isAuthenticated: \(sessionStore.isAuthenticated), userId: \(sessionStore.userId ?? "nil"), displayName: \(sessionStore.displayName ?? "nil")")
            
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
            
          
        } header: {
            Text(languageManager.localized("settings.sync_section"))
        } footer: {
            if let lastSync = syncService.lastSyncDate {
                HStack(spacing: 4) {
                    Text(LanguageManager.shared.localized("sync.last_sync_footer"))
                    Text(lastSync, style: .relative)
                }
            }
        }
    }
    
    
    // MARK: - Developer Section
    
    @Query private var allBookmarks: [Bookmark]
    @Query private var allCategories: [Category]
    
    @State private var isForcingSyncTask = false
    
    private var developerSection: some View {
        Section {
            // Force Full Sync Button
            Button {
                Task {
                    isForcingSyncTask = true
                    await syncService.forceFullSync()
                    isForcingSyncTask = false
                }
            } label: {
                HStack {
                    Label(languageManager.localized("settings.developer.force_sync"), systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    
                    if isForcingSyncTask {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            .disabled(isForcingSyncTask || syncService.syncState == .syncing)
            
            // Reset Sync Button
            Button(role: .destructive) {
                Task {
                    do {
                        try await syncService.resetSync()
                        await homeViewModel.refresh()
                    } catch {
                        print("❌ Reset sync failed: \(error)")
                    }
                }
            } label: {
                Label(LanguageManager.shared.localized("settings.developer.reset_sync"), systemImage: "trash.circle.fill")
            }
            .disabled(syncService.syncState == .syncing)
            
            // Local Data Stats
            VStack(alignment: .leading, spacing: 8) {
                Text(languageManager.localized("settings.developer.local_data"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text(languageManager.localized("settings.developer.bookmarks"))
                    Spacer()
                    Text("\(allBookmarks.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text(languageManager.localized("settings.developer.categories"))
                    Spacer()
                    Text("\(allCategories.count)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            
            // User Info
            if let userId = sessionStore.userId {
                VStack(alignment: .leading, spacing: 4) {
                    Text(languageManager.localized("settings.developer.user_id"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(userId)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }
            
            // Network Logs
            NavigationLink {
                NetworkLogsView()
            } label: {
                Label(languageManager.localized("debug.logs.title"), systemImage: "network")
            }
        } header: {
            Text(languageManager.localized("settings.developer.title"))
        } footer: {
            Text(languageManager.localized("settings.developer.force_sync_footer"))
                .font(.caption)
        }
    }
    
    // MARK: - Analytics Section
    
    private var analyticsSection: some View {
        Section {
            Button {
                showingAnalytics = true
            } label: {
                Label(LanguageManager.shared.localized("settings.analytics"), systemImage: "chart.bar.fill")
            }
        } header: {
            Text(LanguageManager.shared.localized("settings.analytics_header"))
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        Section {
            Picker(selection: Binding(
                get: { languageManager.currentLanguage },
                set: { newValue in
                    languageManager.currentLanguage = newValue
                }
            )) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            } label: {
                Label(languageManager.localized("settings.language"), systemImage: "globe")
            }
            .pickerStyle(.menu)
            
        } header: {
            Text(languageManager.localized("settings.language"))
        } footer: {
            Text(languageManager.localized("settings.language_footer"))
        }
    }
    
    // MARK: - Notification Section
    
    private var notificationSection: some View {
        Section {
            Toggle(languageManager.localized("settings.notifications"), isOn: Binding(
                get: { notificationManager.isAuthorized },
                set: { newValue in
                    if newValue {
                        notificationManager.requestAuthorization()
                    } else {
                        // Kullanıcıyı sistem ayarlarına yönlendir
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            ))
        } header: {
            Text(languageManager.localized("settings.notifications_header"))
        } footer: {
            Text(languageManager.localized("settings.notifications_footer"))
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            Button {
                ReviewManager.shared.requestReviewManually()
            } label: {
                Label {
                    Text(languageManager.localized("settings.rate_app"))
                } icon: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
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
            
            HStack {
                Text(languageManager.localized("settings.version"))
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
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
    SettingsView(
        homeViewModel: HomeViewModel(
            bookmarkRepository: PreviewMockRepository.shared,
            categoryRepository: PreviewMockCategoryRepository.shared
        )
    )
    .environmentObject(SessionStore())
}
