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
    @StateObject private var syncService = SyncService.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @AppStorage(AppLanguage.storageKey)
    private var selectedLanguageRawValue = AppLanguage.system.rawValue
    
    @State private var showingLanguagePicker = false
    
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
            .navigationTitle("settings.title")
            .toolbarTitleDisplayMode(.inline)

        }
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
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(sessionStore.isAnonymous ? Color.gray : Color.blue)
                                .frame(width: 44, height: 44)
                            
                            Text(sessionStore.avatarInitial)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        Text(sessionStore.displayName)
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        // Sync durumu badge
                        SyncStatusBadge()
                    }
                }
            } else {
                Button {
                    // SignIn sheet aç
                } label: {
                    Label("auth.sign_in", systemImage: "person.crop.circle")
                }
            }
        } header: {
            Text("settings.account")
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
                    Label("settings.sync", systemImage: "arrow.triangle.2.circlepath")
                    
                    Spacer()
                    
                    // Durum göstergesi
                    HStack(spacing: 4) {
                        if syncService.syncState == .syncing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        
                        Text(syncStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Hızlı sync butonu
            if sessionStore.isAuthenticated && networkMonitor.isConnected {
                Button {
                    Task {
                        await syncService.syncChanges()
                    }
                } label: {
                    HStack {
                        Label("sync.sync_now", systemImage: "arrow.clockwise")
                        
                        Spacer()
                        
                        if syncService.syncState == .syncing {
                            ProgressView()
                        }
                    }
                }
                .disabled(syncService.syncState == .syncing)
            }
        } header: {
            Text("settings.sync_section")
        } footer: {
            if let lastSync = syncService.lastSyncDate {
                Text("sync.last_sync_footer \(lastSync, style: .relative)")
            }
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        Section {
            // Dil seçimi - mevcut AppLanguage yapısına uygun
            Picker("settings.language", selection: selectedLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.titleKey)
                        .tag(language)
                }
            }
            
        } header: {
            Text("settings.appearance")
        }
    }
    
    /// Binding for AppLanguage
    private var selectedLanguage: Binding<AppLanguage> {
        Binding {
            AppLanguage(rawValue: selectedLanguageRawValue) ?? .system
        } set: { newValue in
            selectedLanguageRawValue = newValue.rawValue
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            HStack {
                Text("settings.version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("settings.build")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(.secondary)
            }
            
            Link(destination: URL(string: "https://github.com")!) {
                Label("settings.source_code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            
            Link(destination: URL(string: "mailto:support@example.com")!) {
                Label("settings.contact", systemImage: "envelope")
            }
        } header: {
            Text("settings.about")
        }
    }
    
    // MARK: - Helpers
    
    private var syncStatusText: String {
        switch syncService.syncState {
        case .idle: return String(localized: "sync.state.idle")
        case .syncing: return String(localized: "sync.state.syncing")
        case .offline: return String(localized: "sync.state.offline")
        case .error: return String(localized: "sync.state.error")
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
