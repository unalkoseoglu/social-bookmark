
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
    func getCurrentUserProfile() async -> UserProfile?
    
    /// Stream of auth state changes
    var authStateChanges: AsyncStream<AuthEvent> { get }
}

/// Laravel implementation of AuthRepository
final class AuthRepository: AuthRepositoryProtocol, @unchecked Sendable {
    
    private let network = NetworkManager.shared
    private let authSubject = PassthroughSubject<AuthEvent, Never>()
    
    private var defaults: UserDefaults {
        UserDefaults(suiteName: APIConstants.appGroupId) ?? .standard
    }
    
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
        clearUserCache() // Clear cache for fresh user data
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
        
        // Small delay to ensure UserDefaults has persisted the token
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        clearUserCache() // Clear cache for fresh user data
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
        clearUserCache() // Clear cache for fresh user data
        authSubject.send(.signedIn)
        return response.user
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        _ = try? await network.request(endpoint: APIConstants.Endpoints.logout, method: "POST") as EmptyResponse?
        defaults.removeObject(forKey: APIConstants.Keys.token)
        clearUserCache() // Clear cached user on sign out
        authSubject.send(.signedOut)
    }
    
    // MARK: - User Management
    
    private var cachedUser: AuthUser?
    private var cachedProfile: UserProfile?
    private var lastUserFetch: Date?
    private let cacheValidityDuration: TimeInterval = 60 // 60 seconds
    
    func getCurrentUser() async -> AuthUser? {
        // Check if we have a valid token first
        guard defaults.string(forKey: APIConstants.Keys.token) != nil else {
            Logger.auth.debug("🔒 No token found, user not authenticated")
            cachedUser = nil
            cachedProfile = nil
            return nil
        }
        
        // Return cached user if still valid
        if let cached = cachedUser,
           let lastFetch = lastUserFetch,
           Date().timeIntervalSince(lastFetch) < cacheValidityDuration {
            Logger.auth.debug("✓ Returning cached user: \(cached.id.uuidString)")
            return cached
        }
        
        // Fetch fresh user data (Skip in extension to speed up startup)
        let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
        if isExtension {
             Logger.auth.info("⏭️ [AuthRepo] Extension mode: Skipping fresh profile fetch, returning nil user (will use SessionStore cache)")
             return nil
        }
        
        Logger.auth.debug("📡 Fetching user profile from API...")
        let profile: UserProfile? = try? await network.request(endpoint: APIConstants.Endpoints.profile)
        if let profile {
            let user = AuthUser(id: profile.id, email: profile.email, isAnonymous: profile.isAnonymous)
            cachedUser = user
            cachedProfile = profile // Cache the full profile too
            lastUserFetch = Date()
            Logger.auth.info("✅ User and profile fetched and cached: \(user.id.uuidString)")
            return user
        }
        
        // No user found, clear cache
        cachedUser = nil
        cachedProfile = nil
        lastUserFetch = nil
        Logger.auth.warning("⚠️ Failed to fetch user profile")
        return nil
    }
    
    func getCurrentUserProfile() async -> UserProfile? {
        // Check if we have a valid token first
        guard defaults.string(forKey: APIConstants.Keys.token) != nil else {
            Logger.auth.debug("🔒 No token found, clearing profile cache")
            clearUserCache()
            return nil
        }
        
        // Return cached profile if available and valid
        if let cached = cachedProfile,
           let lastFetch = lastUserFetch,
           Date().timeIntervalSince(lastFetch) < cacheValidityDuration {
            Logger.auth.debug("✓ Returning cached profile: \(cached.displayName)")
            return cached
        }
        
        // Fetch fresh profile from API with error handling
        Logger.auth.debug("📡 Fetching user profile from API...")
        do {
            let profile: UserProfile = try await network.request(endpoint: APIConstants.Endpoints.profile)
            cachedProfile = profile
            lastUserFetch = Date()
            Logger.auth.info("✅ Profile fetched and cached: \(profile.displayName)")
            return profile
        } catch let error as NetworkError {
            Logger.auth.error("❌ Failed to fetch profile (NetworkError): \(error.localizedDescription)")
            // Don't clear cache on transient errors - return stale data if available
            return cachedProfile
        } catch {
            Logger.auth.error("❌ Failed to fetch profile (Unknown): \(error.localizedDescription)")
            return cachedProfile
        }
    }
    
    func clearUserCache() {
        cachedUser = nil
        cachedProfile = nil
        lastUserFetch = nil
        Logger.auth.debug("🧹 User and profile cache cleared")
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
        Logger.auth.info("Saving auth token to UserDefaults, token: \(token)")
        defaults.set(token, forKey: APIConstants.Keys.token)
    }
}

