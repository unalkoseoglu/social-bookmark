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
    
    // Apple Sign In için
    @State private var currentNonce: String?
    @State private var currentHashedNonce: String?
    
    var body: some View {
        List {
            // Kullanıcı Bilgileri
            userInfoSection
            
            // Anonim kullanıcı için hesap bağlama (ayrı section - daha belirgin)
            if sessionStore.isAuthenticated && sessionStore.isAnonymous {
                linkAccountSection
            }
            
            // Hesap İşlemleri
            if sessionStore.isAuthenticated {
                accountActionsSection
                
                dangerZoneSection
            }
            
          
        }
        .navigationTitle("settings.account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSignIn) {
            SignInView(isPresented: true)
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showingLinkAccountSheet) {
            linkAccountSheet
        }
        .alert("settings.sign_out_title", isPresented: $showingSignOutAlert) {
            Button("common.cancel", role: .cancel) { }
            Button("settings.sign_out", role: .destructive) {
                Task {
                    await sessionStore.signOut()
                }
            }
        } message: {
            Text("settings.sign_out_message")
        }
        .alert("settings.delete_account_title", isPresented: $showingDeleteAccountAlert) {
            Button("common.cancel", role: .cancel) { }
            Button("settings.delete_account", role: .destructive) {
                Task {
                    await sessionStore.deleteAccount()
                }
            }
        } message: {
            Text("settings.delete_account_message")
        }
        .alert(
            Text("auth.error_title"),
            isPresented: $showingError,
            presenting: sessionStore.error
        ) { _ in
            Button("common.ok") {
                sessionStore.clearError()
            }
        } message: { error in
            Text(error.errorDescription ?? "")
        }
        .onChange(of: sessionStore.error) { _, newError in
            showingError = newError != nil
        }
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
            Text("settings.account_info")
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
                    Text("settings.anonymous_warning_title")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("settings.anonymous_warning_message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            
            // Apple ile Bağla Butonu
            Button {
                prepareNonce()
                showingLinkAccountSheet = true
            } label: {
                HStack {
                    
                    Label("settings.link_with_apple", systemImage: "apple.logo")
                   
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            
        } header: {
            Text("settings.secure_your_account")
        } footer: {
            Text("settings.link_account_footer")
        }
    }
    
    // MARK: - Account Actions Section
    
    private var accountActionsSection: some View {
        Section {
            // Sync durumu
            HStack {
                Label("settings.sync_status", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                Text("settings.synced")
                    .foregroundStyle(.secondary)
            }
            
        } header: {
            Text("settings.account_actions")
        }
    }
    
    // MARK: - Danger Zone Section
    
    private var dangerZoneSection: some View {
        Section {
            // Çıkış Yap
            Button(role: .destructive) {
                showingSignOutAlert = true
            } label: {
                Label("settings.sign_out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            
            // Hesabı Sil
            Button(role: .destructive) {
                showingDeleteAccountAlert = true
            } label: {
                Label("settings.delete_account", systemImage: "trash")
            }
        
        } footer: {
            Text("settings.delete_account_warning")
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
                    
                    Text("settings.link_account_title")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("settings.link_account_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Faydalar listesi
                VStack(alignment: .leading, spacing: 12) {
                    benefitRow(icon: "checkmark.shield.fill", text: "settings.benefit_secure", color: .green)
                    benefitRow(icon: "arrow.triangle.2.circlepath", text: "settings.benefit_sync", color: .blue)
                    benefitRow(icon: "macbook.and.iphone", text: "settings.benefit_devices", color: .purple)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Apple Sign In Button
                SignInWithAppleButton(.signIn) { request in
                    AuthService.shared.configureAppleRequest(request)
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
                Text("settings.link_keeps_data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                    .frame(height: 20)
            }
            .navigationTitle("settings.link_account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel") {
                        showingLinkAccountSheet = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Helper Views
    
    private func benefitRow(icon: String, text: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Private Methods
    
    private func prepareNonce() {
        let prepared = sessionStore.prepareAppleSignIn()
        currentNonce = prepared.nonce
        currentHashedNonce = prepared.hashedNonce
    }
    
    private func handleLinkApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }
            Task {
                await sessionStore.linkToApple(credential: credential)
                showingLinkAccountSheet = false
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                return
            }
            sessionStore.setError(.appleSignInFailed(error.localizedDescription))
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
                                    Text("auth.tap_to_secure")
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
                    Label("auth.sign_in", systemImage: "person.crop.circle")
                }
            }
        } header: {
            Text("settings.account")
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
