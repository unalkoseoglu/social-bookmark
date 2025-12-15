//
//  AuthRepositoryProtocol.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//


// Core/Auth/AuthRepository.swift

import Foundation
import OSLog
import Auth
import Supabase

/// Protocol for authentication operations (enables testing)
protocol AuthRepositoryProtocol: Sendable {
    func signInAnonymously() async throws -> User
    func signInWithApple(idToken: String, nonce: String) async throws -> User
    func linkIdentity(provider: Auth.Provider) async throws
    func signOut() async throws
    func getCurrentSession() async throws -> Session?
    func getCurrentUser() async -> User?
    func refreshSession() async throws -> Session
    
    /// Stream of auth state changes
    var authStateChanges: AsyncStream<AuthChangeEvent> { get }
}

/// Supabase implementation of AuthRepository
final class AuthRepository: AuthRepositoryProtocol, @unchecked Sendable {
    
    private let client: SupabaseClient
    
    init(client: SupabaseClient = SupabaseClientFactory.shared) {
        self.client = client
    }
    
    // MARK: - Anonymous Sign In
    
    func signInAnonymously() async throws -> User {
        Logger.auth.info("Attempting anonymous sign in")
        
        do {
            let response = try await client.auth.signInAnonymously()
            Logger.auth.info("Anonymous sign in successful, user: \(response.user.id)")
            return response.user
        } catch let error as Auth.AuthError {
            Logger.auth.error("Anonymous sign in failed: \(error.localizedDescription)")
            throw mapSupabaseAuthError(error)
        } catch {
            Logger.auth.error("Anonymous sign in failed: \(error.localizedDescription)")
            throw AuthError.unknown(error.localizedDescription)
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        Logger.auth.info("Attempting Apple sign in")
        
        do {
            let response = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            Logger.auth.info("Apple sign in successful, user: \(response.user.id)")
            return response.user
        } catch let error as AuthError {
            Logger.auth.error("Apple sign in failed: \(error.localizedDescription)")
            throw AuthError.appleSignInFailed(error.localizedDescription)
        } catch {
            Logger.auth.error("Apple sign in failed: \(error.localizedDescription)")
            throw AuthError.appleSignInFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Link Identity (Upgrade Anonymous to Apple)
    
    func linkIdentity(provider: Auth.Provider) async throws {
        Logger.auth.info("Attempting to link identity with provider: \(String(describing: provider))")
        
        do {
            // This opens a browser/ASWebAuthenticationSession for OAuth
            try await client.auth.linkIdentity(provider: provider)
            Logger.auth.info("Identity linking initiated")
        } catch let error as AuthError {
            Logger.auth.error("Identity linking failed: \(error.localizedDescription)")
            throw AuthError.appleSignInFailed(error.localizedDescription)
        } catch {
            Logger.auth.error("Identity linking failed: \(error.localizedDescription)")
            throw AuthError.appleSignInFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        Logger.auth.info("Attempting sign out")
        
        do {
            try await client.auth.signOut()
            Logger.auth.info("Sign out successful")
        } catch {
            Logger.auth.error("Sign out failed: \(error.localizedDescription)")
            throw AuthError.unknown(error.localizedDescription)
        }
    }
    
    // MARK: - Session Management
    
    func getCurrentSession() async throws -> Session? {
        do {
            let session = try await client.auth.session
            Logger.auth.debug("Current session retrieved, expires: \(session.expiresAt)")
            return session
        } catch {
            Logger.auth.debug("No current session: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getCurrentUser() async -> User? {
        do {
            return try await client.auth.session.user
        } catch {
            return nil
        }
    }
    
    func refreshSession() async throws -> Session {
        Logger.auth.info("Refreshing session")
        
        do {
            let session = try await client.auth.refreshSession()
            Logger.auth.info("Session refreshed successfully")
            return session
        } catch {
            Logger.auth.error("Session refresh failed: \(error.localizedDescription)")
            throw AuthError.signUpFailed
        }
    }
    
    // MARK: - Auth State Stream
    
    var authStateChanges: AsyncStream<AuthChangeEvent> {
        AsyncStream { continuation in
            let task = Task {
                for await (event, _) in client.auth.authStateChanges {
                    continuation.yield(event)
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - Error Mapping
    
    private func mapSupabaseAuthError(_ error: Auth.AuthError) -> AuthError {

        // Map Supabase AuthError to our typed AuthError
        switch error {
        case .sessionMissing:
            return .notAuthenticated
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
