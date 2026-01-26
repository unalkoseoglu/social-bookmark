//
//  SignInView.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingError = false
    
    /// Ayarlardan mı açıldı?
    var isPresented: Bool = false
    
    /// Paywall'dan mı açıldı? (Özel içerik için)
    var isFromPaywall: Bool = false
    
    /// Paywall nedeni (örn: "Sınır doldu")
    var reason: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Logo/Header
                headerSection
                
                Spacer()
                
                // Sign In Buttons
                signInButtonsSection
                
                // Footer
                footerSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isPresented {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if sessionStore.isLoading {
                    loadingOverlay
                }
            }
            .alert(
                Text("auth.error_title"),
                isPresented: $showingError,
                presenting: sessionStore.error
            ) { _ in
                Button(String(localized: "common.ok")) {
                    sessionStore.clearError()
                }
            } message: { error in
                Text(error.errorDescription ?? String(localized: "auth.error.unknown"))
            }
            .onChange(of: sessionStore.error) { _, newError in
                showingError = newError != nil
            }
            .onChange(of: sessionStore.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated && isPresented {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            if isFromPaywall {
                // Paywall'a özel içerik
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                
                Text("paywall.unauthenticated_title")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let reason = reason {
                    Text(reason)
                        .font(.headline)
                        .foregroundStyle(.yellow)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Text("paywall.unauthenticated_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Pro Özellikleri Listesi
                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "star.fill", text: "paywall.feature.unlimited_bookmarks")
                    featureRow(icon: "folder.fill", text: "paywall.feature.custom_categories")
                    featureRow(icon: "text.viewfinder", text: "paywall.feature.ocr")
                    featureRow(icon: "photo.stack.fill", text: "paywall.feature.multi_image")
                    featureRow(icon: "cloud.fill", text: "paywall.feature.cloud_sync")
                    featureRow(icon: "nosign", text: "paywall.feature.ad_free")
                }
                .padding(.top, 8)
            } else {
                // Normal karşılama
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("auth.welcome_title")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("auth.welcome_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.yellow)
                .font(.system(size: 16, weight: .semibold))
            
            Text(LocalizedStringKey(text))
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Sign In Buttons
    
    private var signInButtonsSection: some View {
        VStack(spacing: 16) {
            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                sessionStore.configureAppleRequest(request)
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .cornerRadius(12)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        Text("auth.terms_notice")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
        }
    }
    
    // MARK: - Private Methods
    
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                await sessionStore.signInWithApple(credential: authorization)
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                // User cancelled, don't show error
                return
            }
            sessionStore.setError(.appleSignInFailed(error.localizedDescription))
            showingError = true
        }
    }
}

// MARK: - Preview

#Preview("Sign In") {
    SignInView()
        .environmentObject(SessionStore())
}

#Preview("Sign In - Presented") {
    SignInView(isPresented: true)
        .environmentObject(SessionStore())
}
