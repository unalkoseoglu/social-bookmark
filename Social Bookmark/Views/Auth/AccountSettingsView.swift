//
//  AccountSettingsView.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//


//
//  AccountSettingsView.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
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
            
            // Hesap İşlemleri
            if sessionStore.isAuthenticated {
                accountActionsSection
            }
            
            // Tehlikeli İşlemler
            if sessionStore.isAuthenticated {
                dangerZoneSection
            }
        }
        .navigationTitle("settings.account")
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
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(sessionStore.isAnonymous ? Color.gray : Color.blue)
                        .frame(width: 60, height: 60)
                    
                    if sessionStore.isAuthenticated {
                        Text(sessionStore.avatarInitial)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    if sessionStore.isAuthenticated {
                        Text(sessionStore.displayName)
                            .font(.headline)
                        
                        if let email = sessionStore.userEmail {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if sessionStore.isAnonymous {
                            Label("auth.anonymous_account", systemImage: "person.crop.circle.badge.questionmark")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("auth.not_signed_in")
                            .font(.headline)
                        
                        Text("auth.sign_in_to_sync")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Status Badge
                if sessionStore.isAuthenticated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("settings.account_info")
        }
    }
    
    // MARK: - Account Actions Section
    
    private var accountActionsSection: some View {
        Section {
            // Anonim kullanıcı için hesap bağlama
            if sessionStore.isAnonymous {
                Button {
                    prepareNonce()
                    showingLinkAccountSheet = true
                } label: {
                    Label("settings.link_account", systemImage: "link.circle")
                }
                
                Text("settings.link_account_description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
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
        } header: {
            Text("settings.danger_zone")
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
                VStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
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
                
                // Apple Sign In Button
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.email, .fullName]
                    request.nonce = currentHashedNonce
                } onCompletion: { result in
                    handleLinkApple(result)
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
        .presentationDetents([.medium])
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
                                .fill(sessionStore.isAnonymous ? Color.gray : Color.blue)
                                .frame(width: 40, height: 40)
                            
                            Text(sessionStore.avatarInitial)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sessionStore.displayName)
                                .font(.subheadline)
                            
                            if sessionStore.isAnonymous {
                                Text("auth.anonymous_account")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else if let email = sessionStore.userEmail {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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

#Preview("Account Settings") {
    NavigationStack {
        AccountSettingsView()
            .environmentObject(SessionStore())
    }
}

#Preview("Settings Section - Authenticated") {
    NavigationStack {
        List {
            AccountSettingsSection()
        }
    }
    .environmentObject(SessionStore())
}
