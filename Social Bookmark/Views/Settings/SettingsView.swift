//
//  SettingsView.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//
//  Ana ayarlar sayfası
//

import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject private var languageManager = LanguageManager.shared
    @StateObject private var syncService = SyncService.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var showingRestartAlert = false
    @State private var pendingLanguage: AppLanguage?
    
    var body: some View {
        NavigationStack {
            List {
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
    }
    
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
                Text("sync.last_sync_footer \(lastSync, style: .relative)")
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
            
            Link(destination: URL(string: "https://github.com")!) {
                Label(languageManager.localized("settings.source_code"), systemImage: "chevron.left.forwardslash.chevron.right")
            }
            
            Link(destination: URL(string: "mailto:support@example.com")!) {
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
