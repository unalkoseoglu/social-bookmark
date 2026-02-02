
import Foundation
import OSLog
import Combine

/// Auth event types (mirrors Supabase for compatibility)
enum AuthEvent {
    case initialSession
    case signedIn
    case signedOut
    case tokenRefreshed
    case userUpdated
}

/// Protocol for authentication operations (enables testing)
protocol AuthRepositoryProtocol: Sendable {
    func signInAnonymously() async throws -> AuthUser
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthUser
    func signUp(email: String, password: String, fullName: String?) async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    func signOut() async throws
    func getCurrentUser() async -> AuthUser?
    
    /// Stream of auth state changes
    var authStateChanges: AsyncStream<AuthEvent> { get }
}

/// Laravel implementation of AuthRepository
final class AuthRepository: AuthRepositoryProtocol, @unchecked Sendable {
    
    private let network = NetworkManager.shared
    private let authSubject = PassthroughSubject<AuthEvent, Never>()
    
    init() {}
    
    // MARK: - Anonymous Sign In
    
    func signInAnonymously() async throws -> AuthUser {
        Logger.auth.info("Attempting anonymous sign in with Laravel API")
        
        let response: AuthResponse = try await network.request(
            endpoint: APIConstants.Endpoints.register,
            method: "POST",
            body: try JSONEncoder().encode(["is_anonymous": true])
        )
        
        saveToken(response.accessToken)
        authSubject.send(.signedIn)
        return response.user
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthUser {
        Logger.auth.info("Attempting Apple sign in with Laravel API")
        
        let response: AuthResponse = try await network.request(
            endpoint: APIConstants.Endpoints.login,
            method: "POST",
            body: try JSONEncoder().encode([
                "provider": "apple",
                "id_token": idToken,
                "nonce": nonce
            ])
        )
        
        saveToken(response.accessToken)
        authSubject.send(.signedIn)
        return response.user
    }
    
    // MARK: - Email Auth
    
    func signUp(email: String, password: String, fullName: String?) async throws -> AuthUser {
        let response: AuthResponse = try await network.request(
            endpoint: APIConstants.Endpoints.register,
            method: "POST",
            body: try JSONEncoder().encode([
                "email": email,
                "password": password,
                "full_name": fullName
            ])
        )
        
        saveToken(response.accessToken)
        authSubject.send(.signedIn)
        return response.user
    }
    
    func signIn(email: String, password: String) async throws -> AuthUser {
        let response: AuthResponse = try await network.request(
            endpoint: APIConstants.Endpoints.login,
            method: "POST",
            body: try JSONEncoder().encode([
                "email": email,
                "password": password
            ])
        )
        
        saveToken(response.accessToken)
        authSubject.send(.signedIn)
        return response.user
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        _ = try? await network.request(endpoint: "/auth/logout", method: "POST") as EmptyResponse?
        UserDefaults.standard.removeObject(forKey: APIConstants.Keys.token)
        authSubject.send(.signedOut)
    }
    
    // MARK: - User Management
    
    func getCurrentUser() async -> AuthUser? {
        let profile: UserProfile? = try? await network.request(endpoint: APIConstants.Endpoints.profile)
        if let profile {
            return AuthUser(id: profile.id, email: profile.email, isAnonymous: profile.isAnonymous)
        }
        return nil
    }
    
    // MARK: - Auth State Stream
    
    var authStateChanges: AsyncStream<AuthEvent> {
        AsyncStream { continuation in
            let cancellable = authSubject.sink { event in
                continuation.yield(event)
            }
            
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: APIConstants.Keys.token)
    }
}

