//
//  AccountSettingsView.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//
//  ⚠️ GÜNCELLEME: Anonim kullanıcı için hesap bağlama iyileştirildi
//

import SwiftUI
import AuthenticationServices

/// Ayarlar sayfasında kullanılan hesap yönetim view'ı
struct AccountSettingsView: View {
    
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingSignIn = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingLinkAccountSheet = false
    @State private var showingError = false
    
    @StateObject private var syncService = SyncService.shared
    
    var body: some View {
        List {
            userInfoSection
            
            if sessionStore.isAuthenticated && sessionStore.isAnonymous {
                linkAccountSection
            }
            
            if sessionStore.isAuthenticated && !sessionStore.isAnonymous {
                accountActionsSection
                dangerZoneSection
            }
        }
        .navigationTitle(LanguageManager.shared.localized("settings.account"))
        .navigationBarTitleDisplayMode(.inline)
        .accountSettingsSheets(
            showingSignIn: $showingSignIn,
            showingLinkAccountSheet: $showingLinkAccountSheet,
            sessionStore: sessionStore,
            linkAccountSheet: AnyView(linkAccountSheet)
        )
        .accountSettingsAlerts(
            showingSignOutAlert: $showingSignOutAlert,
            showingDeleteAccountAlert: $showingDeleteAccountAlert,
            sessionStore: sessionStore
        )
        .accountSettingsErrorAndSync(
            showingError: $showingError,
            sessionStore: sessionStore
        )
    }
    
    // MARK: - User Info Section
    
    private var userInfoSection: some View {
        Section {
            HStack(spacing: 12) {
                // Avatar
                HStack(spacing: 12) {
                    // Avatar
                    
                        if  sessionStore.isAnonymous {
                            Image(systemName: "person.crop.circle.badge.exclamationmark.fill").font(.largeTitle).foregroundStyle(.orange)
                        }else{
                            Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(.gray)
                        }
                            
                    Text(sessionStore.nameForDisplay)
                        .font(.body)
                        .fontWeight(.medium)
                    
                }
                
            }

        } header: {
            Text(LanguageManager.shared.localized("settings.account_info"))
        }
    }
    
    // MARK: - Link Account Section (Anonim kullanıcılar için)
    
    private var linkAccountSection: some View {
        Section {
            // Uyarı Banner
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LanguageManager.shared.localized("settings.anonymous_warning_title"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(LanguageManager.shared.localized("settings.anonymous_warning_message"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            
            // Apple ile Bağla Butonu
            Button {
                showingLinkAccountSheet = true
            } label: {
                HStack {
                    
                    Label(LanguageManager.shared.localized("settings.link_with_apple"), systemImage: "apple.logo")
                   
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            
        } header: {
            Text(LanguageManager.shared.localized("settings.secure_your_account"))
        } footer: {
            Text(LanguageManager.shared.localized("settings.link_account_footer"))
        }
    }
    
    // MARK: - Account Actions Section
    
    private var accountActionsSection: some View {
        Section {
            // Sync durumu
            HStack {
                Label(LanguageManager.shared.localized("settings.sync_status"), systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                Text(LanguageManager.shared.localized("settings.synced"))
                    .foregroundStyle(.secondary)
            }
            
        } header: {
            Text(LanguageManager.shared.localized("settings.account_actions"))
        }
    }
    
    // MARK: - Danger Zone Section
    
    private var dangerZoneSection: some View {
        Section {
            // Çıkış Yap
            Button(role: .destructive) {
                showingSignOutAlert = true
            } label: {
                Label(LanguageManager.shared.localized("settings.sign_out"), systemImage: "rectangle.portrait.and.arrow.right")
            }
            
            // Hesabı Sil
            Button(role: .destructive) {
                showingDeleteAccountAlert = true
            } label: {
                Label(LanguageManager.shared.localized("settings.delete_account"), systemImage: "trash")
            }
        
        } footer: {
            Text(LanguageManager.shared.localized("settings.delete_account_warning"))
        }
    }
    
    // MARK: - Link Account Sheet
    
    private var linkAccountSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)
                    }
                    
                    Text(LanguageManager.shared.localized("settings.link_account_title"))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(LanguageManager.shared.localized("settings.link_account_subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Faydalar listesi
                VStack(alignment: .leading, spacing: 12) {
                    benefitRow(icon: "checkmark.shield.fill", textId: "settings.benefit_secure", color: .green)
                    benefitRow(icon: "arrow.triangle.2.circlepath", textId: "settings.benefit_sync", color: .blue)
                    benefitRow(icon: "macbook.and.iphone", textId: "settings.benefit_devices", color: .purple)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Apple Sign In Button
                SignInWithAppleButton(.signIn) { request in
                    sessionStore.configureAppleRequest(request)
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        if let cred = auth.credential as? ASAuthorizationAppleIDCredential {
                            handleLinkApple(result)
                        }
                    case .failure(let error):
                        print(error)
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .cornerRadius(12)
                .padding(.horizontal, 24)
                
                // Info
                Text(LanguageManager.shared.localized("settings.link_keeps_data"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                    .frame(height: 20)
            }
            .navigationTitle(LanguageManager.shared.localized("settings.link_account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LanguageManager.shared.localized("common.cancel")) {
                        showingLinkAccountSheet = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Helper Views
    
    private func benefitRow(icon: String, textId: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(LanguageManager.shared.localized(textId))
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Private Methods
    
    
    private func handleLinkApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }
            Task {
                await sessionStore.linkToApple(credential: credential)
                showingLinkAccountSheet = false
                await syncService.syncChanges()
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                return
            }
            // sessionStore.setError(.appleSignInFailed(error.localizedDescription)) // TODO: Re-enable when error handling is implemented
            print("❌ Apple Sign In failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - View Modifiers Extension

extension View {
    func accountSettingsSheets(
        showingSignIn: Binding<Bool>,
        showingLinkAccountSheet: Binding<Bool>,
        sessionStore: SessionStore,
        linkAccountSheet: AnyView
    ) -> some View {
        self
            .sheet(isPresented: showingSignIn) {
                SignInView(isPresented: true)
                    .environmentObject(sessionStore)
            }
            .sheet(isPresented: showingLinkAccountSheet) {
                linkAccountSheet
            }
    }

    func accountSettingsAlerts(
        showingSignOutAlert: Binding<Bool>,
        showingDeleteAccountAlert: Binding<Bool>,
        sessionStore: SessionStore
    ) -> some View {
        self
            .alert(LanguageManager.shared.localized("settings.sign_out_title"), isPresented: showingSignOutAlert) {
                Button(LanguageManager.shared.localized("common.cancel"), role: .cancel) { }
                Button(LanguageManager.shared.localized("settings.sign_out"), role: .destructive) {
                    Task { await sessionStore.signOutAndClearData() }
                }
            } message: {
                Text(LanguageManager.shared.localized("settings.sign_out_message"))
            }
            .alert(LanguageManager.shared.localized("settings.delete_account_title"), isPresented: showingDeleteAccountAlert) {
                Button(LanguageManager.shared.localized("common.cancel"), role: .cancel) { }
                Button(LanguageManager.shared.localized("settings.delete_account"), role: .destructive) {
                    Task { await sessionStore.deleteAccount() }
                }
            } message: {
                Text(LanguageManager.shared.localized("settings.delete_account_message"))
            }
    }

    func accountSettingsErrorAndSync(
        showingError: Binding<Bool>,
        sessionStore: SessionStore
    ) -> some View {
        self
            .alert(
                Text(LanguageManager.shared.localized("auth.error_title")),
                isPresented: showingError,
                presenting: sessionStore.error
            ) { _ in
                Button(LanguageManager.shared.localized("common.ok")) {
                    sessionStore.clearError()
                }
            } message: { error in
                Text(error.errorDescription ?? "")
            }
            .onChange(of: sessionStore.error) { _, newError in
                showingError.wrappedValue = newError != nil
            }
    }
}

// MARK: - Settings Integration

/// Ayarlar sayfasında kullanmak için Section
struct AccountSettingsSection: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var showingSignIn = false
    
    var body: some View {
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
                                .fill(sessionStore.isAnonymous ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                                .frame(width: 44, height: 44)
                            
                            if sessionStore.isAnonymous {
                                Image(systemName: "person.crop.circle.badge.questionmark")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                            } else {
                                Text(sessionStore.avatarInitial)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sessionStore.nameForDisplay)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if sessionStore.isAnonymous {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                    Text(LanguageManager.shared.localized("auth.tap_to_secure"))
                                        .font(.caption)
                                }
                                .foregroundStyle(.orange)
                            } else if let email = sessionStore.userEmail {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Anonim için uyarı badge
                        if sessionStore.isAnonymous {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } else {
                Button {
                    showingSignIn = true
                } label: {
                    Label(LanguageManager.shared.localized("auth.sign_in"), systemImage: "person.crop.circle")
                }
            }
        } header: {
            Text(LanguageManager.shared.localized("settings.account"))
        }
        .sheet(isPresented: $showingSignIn) {
            SignInView(isPresented: true)
                .environmentObject(sessionStore)
        }
    }
}

// MARK: - Previews

#Preview("Account Settings - Anonymous") {
    NavigationStack {
        AccountSettingsView()
            .environmentObject(SessionStore())
    }
}

#Preview("Settings Section") {
    NavigationStack {
        List {
            AccountSettingsSection()
        }
    }
    .environmentObject(SessionStore())
}
