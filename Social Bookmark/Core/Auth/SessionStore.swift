// Core/Auth/SessionStore.swift

import Foundation
import SwiftUI
import Supabase
import OSLog

/// Observable session state for SwiftUI views
@MainActor
final class SessionStore: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var userId: String?
    @Published private(set) var isAnonymous = false
    @Published private(set) var isLoading = true
    @Published private(set) var error: AuthError?
    
    // MARK: - Dependencies
    
    private let authService: AuthService
    private var authStateTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(authService: AuthService = AuthService()) {
        self.authService = authService
        startListeningToAuthChanges()
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Attempts to restore an existing session
    func initialize() async {
        isLoading = true
        error = nil
        
        let restored = await authService.restoreSessionIfPossible()
        
        if restored {
            userId = await authService.getCurrentUserId()
            isAuthenticated = true
            checkIfAnonymous()
        }
        
        isLoading = false
        Logger.auth.info("Session initialization complete, authenticated: \(self.isAuthenticated)")
    }
    
    /// Signs in anonymously
    func signInAnonymously() async {
        isLoading = true
        error = nil
        
        do {
            let id = try await authService.signInAnonymously()
            userId = id
            isAuthenticated = true
            isAnonymous = true
            Logger.auth.info("Anonymous sign in successful")
        } catch let authError as AuthError {
            error = authError
            Logger.auth.error("Anonymous sign in failed: \(authError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
            Logger.auth.error("Anonymous sign in failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Prepares Apple Sign In request
    func prepareAppleSignIn() -> (nonce: String, hashedNonce: String) {
        return authService.prepareAppleSignIn()
    }
    
    /// Completes Apple Sign In
    func completeAppleSignIn(authorization: ASAuthorization) async {
        isLoading = true
        error = nil
        
        do {
            let id = try await authService.completeAppleSignIn(authorization: authorization)
            userId = id
            isAuthenticated = true
            isAnonymous = false
            Logger.auth.info("Apple sign in successful")
        } catch let authError as AuthError {
            error = authError
            Logger.auth.error("Apple sign in failed: \(authError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
            Logger.auth.error("Apple sign in failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Links anonymous account to Apple
    func linkToApple() async {
        isLoading = true
        error = nil
        
        do {
            try await authService.linkToApple()
            isAnonymous = false
            Logger.auth.info("Account linked to Apple successfully")
        } catch let authError as AuthError {
            error = authError
            Logger.auth.error("Account linking failed: \(authError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    /// Signs out the current user
    func signOut() async {
        isLoading = true
        error = nil
        
        do {
            try await authService.signOut()
            userId = nil
            isAuthenticated = false
            isAnonymous = false
            Logger.auth.info("Sign out successful")
        } catch let authError as AuthError {
            error = authError
            Logger.auth.error("Sign out failed: \(authError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    /// Clears current error
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Methods
    
    private func startListeningToAuthChanges() {
        authStateTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await event in await authService.authStateChanges {
                await self.handleAuthEvent(event)
            }
        }
    }
    
    private func handleAuthEvent(_ event: AuthChangeEvent) async {
        Logger.auth.debug("Auth event received: \(String(describing: event))")
        
        switch event {
        case .signedIn:
            userId = await authService.getCurrentUserId()
            isAuthenticated = true
            checkIfAnonymous()
            
        case .signedOut:
            userId = nil
            isAuthenticated = false
            isAnonymous = false
            
        case .tokenRefreshed:
            Logger.auth.debug("Token refreshed")
            
        case .userUpdated:
            checkIfAnonymous()
            
        default:
            break
        }
    }
    
    private func checkIfAnonymous() {
        // Check if user has any linked identities
        Task {
            // In Supabase, anonymous users typically don't have identities
            // You can check user.identities or user.isAnonymous if available
            // For now, we track this via our own state
        }
    }
}