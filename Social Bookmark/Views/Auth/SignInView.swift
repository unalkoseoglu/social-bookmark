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
    @State private var currentNonce: String?
    @State private var currentHashedNonce: String?
    
    /// Ayarlardan mı açıldı?
    var isPresented: Bool = false
    
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
    
    // MARK: - Sign In Buttons
    
    private var signInButtonsSection: some View {
        VStack(spacing: 16) {
            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
                request.nonce = currentHashedNonce
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .cornerRadius(12)
            
            // Divider
            dividerSection
            
            // Anonymous Sign In
            Button {
                Task {
                        await sessionStore.signInAnonymously()
                    }
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                    Text("auth.continue_anonymously")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(.systemGray5))
                .foregroundStyle(.primary)
                .cornerRadius(12)
            }
            .disabled(sessionStore.isLoading)
        }
        .padding(.horizontal, 24)
    }
    
    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
            
            Text("auth.or_divider")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
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
    
    private func prepareNonce() {
        let prepared = sessionStore.prepareAppleSignIn()
        currentNonce = prepared.nonce
        currentHashedNonce = prepared.hashedNonce
    }
    
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
