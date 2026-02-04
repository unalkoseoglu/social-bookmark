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
    
    var isPresented: Bool = false
    var isFromPaywall: Bool = false
    var reason: String?
    
    var body: some View {
        NavigationStack {
            contentView
        }
    }
    
    private var contentView: some View {
        mainStack
            .modifier(SignInToolbarModifier(isPresented: isPresented, dismiss: dismiss))
            .modifier(SignInLoadingModifier(isLoading: sessionStore.isLoading))
            .modifier(SignInAlertModifier(showingError: $showingError, error: sessionStore.error, sessionStore: sessionStore))
            .modifier(SignInLogicModifier(isPresented: isPresented, sessionStore: sessionStore, dismiss: dismiss, showingError: $showingError))
    }

    private var mainStack: some View {
        VStack(spacing: 32) {
            Spacer()
            SignInHeader(isFromPaywall: isFromPaywall, reason: reason)
            Spacer()
            SignInButtons(sessionStore: sessionStore, onCompletion: handleAppleSignIn)
            footerSection
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subviews

struct SignInHeader: View {
    let isFromPaywall: Bool
    let reason: String?

    var body: some View {
        VStack(spacing: 16) {
            if isFromPaywall {
                paywallHeader
            } else {
                normalHeader
            }
        }
    }

    private var paywallHeader: some View {
        VStack(spacing: 16) {
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
            featuresList
        }
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "star.fill", text: "paywall.feature.unlimited_bookmarks")
            featureRow(icon: "folder.fill", text: "paywall.feature.custom_categories")
            featureRow(icon: "text.viewfinder", text: "paywall.feature.ocr")
            featureRow(icon: "photo.stack.fill", text: "paywall.feature.multi_image")
            featureRow(icon: "cloud.fill", text: "paywall.feature.cloud_sync")
            featureRow(icon: "nosign", text: "paywall.feature.ad_free")
        }
        .padding(.top, 8)
    }

    private var normalHeader: some View {
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
}

struct SignInButtons: View {
    @ObservedObject var sessionStore: SessionStore
    @Environment(\.colorScheme) private var colorScheme
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        VStack(spacing: 16) {
            SignInWithAppleButton(.signIn) { request in
                sessionStore.configureAppleRequest(request)
            } onCompletion: { result in
                onCompletion(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .cornerRadius(12)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Modifiers

struct SignInToolbarModifier: ViewModifier {
    let isPresented: Bool
    let dismiss: DismissAction

    func body(content: Content) -> some View {
        content.toolbar {
            if isPresented {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct SignInLoadingModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView().tint(.white).scaleEffect(1.5)
                }
            }
        }
    }
}

struct SignInAlertModifier: ViewModifier {
    @Binding var showingError: Bool
    let error: AuthError?
    @ObservedObject var sessionStore: SessionStore

    func body(content: Content) -> some View {
        content.alert(
            Text("auth.error_title"),
            isPresented: $showingError,
            presenting: error
        ) { _ in
            Button(String(localized: "common.ok")) {
                // sessionStore.clearError() // TODO: Implement if needed
            }
        } message: { error in
            Text(error.errorDescription ?? String(localized: "auth.error.unknown"))
        }
    }
}

struct SignInLogicModifier: ViewModifier {
    let isPresented: Bool
    @ObservedObject var sessionStore: SessionStore
    let dismiss: DismissAction
    @Binding var showingError: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionStore.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated && isPresented {
                    dismiss()
                }
            }
            .onChange(of: sessionStore.error) { _, error in
                if error != nil {
                    showingError = true
                }
            }
    }
}

// MARK: - Logic Extension

extension SignInView {
    private var footerSection: some View {
        Text("auth.terms_notice")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
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
                return
            }
            print("❌ Apple Sign In failed: \(error.localizedDescription)")
            showingError = true
        }
    }
}

// MARK: - Previews

#Preview("Sign In") {
    SignInView()
        .environmentObject(SessionStore())
}

#Preview("Sign In - Presented") {
    SignInView(isPresented: true)
        .environmentObject(SessionStore())
}
