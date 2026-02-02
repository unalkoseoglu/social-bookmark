//
//  AuthService.swift
//  Social Bookmark
//
//  Core/Auth/AuthService.swift
//
import Foundation
import AuthenticationServices
import CryptoKit
import Combine
import OSLog

/// Business logic layer for authentication
/// Handles Apple Sign In flow and coordinates with AuthRepository
@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()

    private let repository: AuthRepositoryProtocol
    private var ensureTask: Task<AuthUser, Error>?

    /// Apple Sign-In için nonce
    private var currentNonce: String?

    /// İşlem devam ediyor mu?
    @Published private(set) var isLoading = false

    /// Son hata mesajı (localization key)
    @Published var errorMessage: String?

    init(repository: AuthRepositoryProtocol = AuthRepository()) {
        self.repository = repository
    }

    // MARK: - Properties

    /// Mevcut kullanıcıyı repository'den alır
    func getCurrentUser() async -> AuthUser? {
        await repository.getCurrentUser()
    }

    // MARK: - Ensure authenticated (anon fallback)

    func ensureAuthenticated() async throws -> AuthUser {
        if let user = await getCurrentUser() { return user }
        if let task = ensureTask { return try await task.value }

        let task = Task<AuthUser, Error> {
            if let user = await getCurrentUser() { return user }
            return try await repository.signInAnonymously()
        }

        ensureTask = task
        defer { ensureTask = nil }

        return try await task.value
    }

    // MARK: - Anonymous Auth

    @discardableResult
    func signInAnonymously() async throws -> AuthUser {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            return try await repository.signInAnonymously()
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    // MARK: - Email/Password Auth

    func signUp(email: String, password: String, fullName: String? = nil) async throws -> AuthUser {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            return try await repository.signUp(email: email, password: password, fullName: fullName)
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            return try await repository.signIn(email: email, password: password)
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }
    
    /// Anonim hesabı email ile upgrade et (Laravel tarafında aynı login/register mantığı kullanılabilir)
    func linkEmail(_ email: String, password: String) async throws -> AuthUser {
        return try await signUp(email: email, password: password)
    }

    // MARK: - Apple Sign-In

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce

        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> AuthUser {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                throw AuthError.appleSignInFailed("auth.error.apple_token_missing")
            }

            let nonce = currentNonce ?? ""
            let user = try await repository.signInWithApple(idToken: tokenString, nonce: nonce)

            currentNonce = nil
            return user
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    // MARK: - Profile Management

    func getCurrentUserProfile() async throws -> UserProfile? {
        return try await NetworkManager.shared.request(endpoint: APIConstants.Endpoints.profile)
    }

    func updateDisplayName(_ newName: String) async throws {
        _ = try await NetworkManager.shared.request(
            endpoint: APIConstants.Endpoints.profile,
            method: "PATCH",
            body: try JSONEncoder().encode(["display_name": newName])
        ) as UserProfile?
    }
    
    func updateProStatus(isPro: Bool) async throws {
        _ = try await NetworkManager.shared.request(
            endpoint: APIConstants.Endpoints.profile,
            method: "PATCH",
            body: try JSONEncoder().encode(["is_pro": isPro])
        ) as UserProfile?
    }

    // MARK: - Sign Out

    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        try await repository.signOut()
    }

    // MARK: - Account Deletion

    func deleteAccount() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        _ = try await NetworkManager.shared.request(endpoint: APIConstants.Endpoints.profile, method: "DELETE") as EmptyResponse?
        try await signOut()
    }

    // MARK: - Error Mapping

    private func mapAuthError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            return authError.localizationKey
        }
        return "auth.error.unknown"
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }

            for r in randoms {
                if remaining == 0 { break }
                if r < charset.count {
                    result.append(charset[Int(r)])
                    remaining -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
