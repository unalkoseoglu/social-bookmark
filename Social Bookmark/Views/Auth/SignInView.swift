// Features/Auth/SignInView.swift

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Logo/Header
                VStack(spacing: 16) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("auth.welcome_title", bundle: .main)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("auth.welcome_subtitle", bundle: .main)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Sign In Buttons
                VStack(spacing: 16) {
                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        let (_, hashedNonce) = sessionStore.prepareAppleSignIn()
                        request.requestedScopes = [.email, .fullName]
                        request.nonce = hashedNonce
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("auth.or_divider", bundle: .main)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 8)
                    
                    // Anonymous Sign In
                    Button {
                        Task {
                            await sessionStore.signInAnonymously()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                            Text("auth.continue_anonymously", bundle: .main)
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
                
                // Footer
                Text("auth.terms_notice", bundle: .main)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }
            .navigationBarHidden(true)
            .overlay {
                if sessionStore.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
            .alert(
                Text("auth.error_title", bundle: .main),
                isPresented: $showingError,
                presenting: sessionStore.error
            ) { _ in
                Button(String(localized: "common.ok")) {
                    sessionStore.clearError()
                }
            } message: { error in
                Text(error.errorDescription ?? "")
            }
            .onChange(of: sessionStore.error) { _, newError in
                showingError = newError != nil
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                await sessionStore.completeAppleSignIn(authorization: authorization)
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                // User cancelled, don't show error
                return
            }
            sessionStore.error = .appleSignInFailed(error.localizedDescription)
            showingError = true
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(SessionStore())
}