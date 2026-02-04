//
//  SyncSettingsView.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//
//  Ayarlar sayfasında sync durumu ve kontrolleri
//

import SwiftUI

/// Sync ayarları ve durumu view'ı
struct SyncSettingsView: View {
    
    @StateObject private var syncService = SyncService.shared
    // @StateObject private var networkMonitor = NetworkMonitor.shared // TODO: Re-enable when NetworkMonitor is implemented
    @EnvironmentObject private var sessionStore: SessionStore
    
    @State private var showingSyncConfirmation = false
    @State private var showingClearCacheConfirmation = false
    @State private var showingPaywall = false
    @State private var cacheSize: String = String(localized: "sync.calculating")
    
    var body: some View {
        List {
            // Sync Durumu
            syncStatusSection
            
            // Sync Aksiyonları
            if sessionStore.isAuthenticated {
                syncActionsSection
            }
            
            // Cache Yönetimi
            cacheManagementSection
            
            // Bilgi
            infoSection
        }
        .navigationTitle(String(localized: "sync.settings.title"))
        .onAppear {
            calculateCacheSize()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Sync Status Section
    
    private var syncStatusSection: some View {
        Section {
            // Bağlantı durumu
            HStack {
                Label {
                    Text(String(localized: "sync.network_status"))
                } icon: {
                    Image(systemName: "wifi") // networkMonitor.isConnected ? "wifi" : "wifi.slash" // TODO: Re-enable
                        .foregroundStyle(.green) // networkMonitor.isConnected ? .green : .red // TODO: Re-enable
                }
                
                Spacer()
                
                Text(String(localized: "sync.connected")) // networkMonitor.isConnected ? ... : ... // TODO: Re-enable
                    .foregroundStyle(.secondary)
            }
            
            // Sync durumu
            HStack {
                Label {
                    Text(String(localized: "sync.status"))
                } icon: {
                    syncStatusIcon
                }
                
                Spacer()
                
                Text(syncStatusText)
                    .foregroundStyle(.secondary)
            }
            
            // Son sync zamanı
            if let lastSync = syncService.lastSyncDate {
                HStack {
                    Label(String(localized: "sync.last_sync"), systemImage: "clock")
                    
                    Spacer()
                    
                    Text(lastSync, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Hata varsa göster
            if let error = syncService.syncError {
                HStack {
                    Label {
                        Text(error)
                            .foregroundStyle(.red)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            
        } header: {
            Text(String(localized: "sync.status_section"))
        }
    }
    
    // MARK: - Sync Actions Section
    
    private var syncActionsSection: some View {
        Section {
            // Manuel sync
            Button {
                if SubscriptionManager.shared.isPro {
                    Task {
                        await syncService.performFullSync()
                    }
                } else {
                    showingPaywall = true
                }
            } label: {
                HStack {
                    Label(String(localized: "sync.sync_now"), systemImage: "arrow.triangle.2.circlepath")
                    
                    Spacer()
                    
                    if syncService.syncState == .syncing {
                        ProgressView()
                    }
                }
            }
            .disabled(syncService.syncState == .syncing) // || !networkMonitor.isConnected) // TODO: Re-enable
            
            // Cloud'dan indir
            Button {
                if SubscriptionManager.shared.isPro {
                    showingSyncConfirmation = true
                } else {
                    showingPaywall = true
                }
            } label: {
                Label(String(localized: "sync.download_from_cloud"), systemImage: "icloud.and.arrow.down")
            }
            .disabled(syncService.syncState == .syncing) // || !networkMonitor.isConnected) // TODO: Re-enable
            
        } header: {
            Text(String(localized: "sync.actions_section"))
        } footer: {
            Text(String(localized: "sync.actions_footer"))
        }
        .alert(String(localized: "sync.download_confirmation_title"), isPresented: $showingSyncConfirmation) {
            Button(String(localized: "sync.download_confirm"), role: .destructive) {
                Task {
                    try? await syncService.downloadFromCloud()
                }
            }
            Button(String(localized: "common.cancel"), role: .cancel) { }
        } message: {
            Text(String(localized: "sync.download_confirmation_message"))
        }
    }
    
    // MARK: - Cache Management Section
    
    private var cacheManagementSection: some View {
        Section {
            // Cache boyutu
            HStack {
                Label(String(localized: "sync.cache_size"), systemImage: "internaldrive")
                
                Spacer()
                
                Text(cacheSize)
                    .foregroundStyle(.secondary)
            }
            
            // Cache temizle
            Button(role: .destructive) {
                showingClearCacheConfirmation = true
            } label: {
                Label(String(localized: "sync.clear_cache"), systemImage: "trash")
            }
            
        } header: {
            Text(String(localized: "sync.cache_section"))
        } footer: {
            Text(String(localized: "sync.cache_footer"))
        }
        .alert(String(localized: "sync.clear_cache_title"), isPresented: $showingClearCacheConfirmation) {
            Button(String(localized: "sync.clear_cache"), role: .destructive) {
                ImageUploadService.shared.clearCache()
                calculateCacheSize()
            }
            Button(String(localized: "common.cancel"), role: .cancel) { }
        } message: {
            Text(String(localized: "sync.clear_cache_confirm"))
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        Section {
            if sessionStore.isAuthenticated {
                HStack {
                    Label(String(localized: "sync.user_id"), systemImage: "person.circle")
                    
                    Spacer()
                    
                    Text(sessionStore.userId?.prefix(8) ?? "-")
                        .foregroundStyle(.secondary)
                        .font(.caption.monospaced())
                }
            }
        } header: {
            Text(String(localized: "settings.account_info"))
        }
    }

    // MARK: - Helpers
    
    private var syncStatusIcon: some View {
        Group {
            switch syncService.syncState {
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .syncing, .uploading, .downloading:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
            case .offline:
                Image(systemName: "icloud.slash")
                    .foregroundStyle(.orange)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var syncStatusText: String {
        switch syncService.syncState {
        case .idle:
            return String(localized: "sync.state.idle")
        case .syncing:
            return String(localized: "sync.state.syncing")
        case .uploading:
            return String(localized: "sync.state.uploading")
        case .downloading:
            return String(localized: "sync.state.downloading")
        case .offline:
            return String(localized: "sync.state.offline")
        case .error:
            return String(localized: "sync.state.error")
        }
    }
    
    private func calculateCacheSize() {
        let bytes = ImageUploadService.shared.getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        cacheSize = formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Sync Status Badge (Diğer view'larda kullanmak için)

/// Küçük sync durumu göstergesi
struct SyncStatusBadge: View {
    @StateObject private var syncService = SyncService.shared
    
    var body: some View {
        HStack(spacing: 4) {
            switch syncService.syncState {
            case .idle:
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.green)
            case .syncing, .uploading, .downloading:
                ProgressView()
                    .scaleEffect(0.7)
            case .offline:
                Image(systemName: "icloud.slash")
                    .foregroundStyle(.orange)
            case .error:
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SyncSettingsView()
            .environmentObject(SessionStore())
    }
}
