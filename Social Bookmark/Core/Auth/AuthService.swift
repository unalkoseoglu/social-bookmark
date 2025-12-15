// Core/Auth/AuthService.swift

import Foundation
import AuthenticationServices
import CryptoKit
import OSLog

/// Business logic layer for authentication
/// Handles Apple Sign In flow and coordinates with AuthRepository
actor AuthService {
    
    private let repository: AuthRepositoryProtocol
    private var currentNonce: String?
    
    init(repository: AuthRepositoryProtocol = AuthRepository()) {
        self.repository = repository
    }
    
    // MARK: - Anonymous Sign In
    
    func signInAnonymously() async throws -> String {
        let user = try await repository.signInAnonymously()
        return user.id.uuidString
    }
    
    // MARK: - Apple Sign In
    
    /// Prepares and returns a nonce for Apple Sign In
    func prepareAppleSignIn() -> (nonce: String, hashedNonce: String) {
        let nonce = generateNonce()
        let hashedNonce = sha256(nonce)
        currentNonce = nonce
        return (nonce, hashedNonce)
    }
    
    /// Completes Apple Sign In with the authorization
    func completeAppleSignIn(authorization: ASAuthorization) async throws -> String {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.appleSignInFailed("Invalid Apple credential")
        }
        
        guard let nonce = currentNonce else {
            throw AuthError.appleSignInFailed("Missing nonce")
        }
        
        let user = try await repository.signInWithApple(idToken: idToken, nonce: nonce)
        currentNonce = nil
        
        return user.id.uuidString
    }
    
    // MARK: - Link Anonymous to Apple
    
    func linkToApple() async throws {
        try await repository.linkIdentity(provider: .apple)
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        try await repository.signOut()
    }
    
    // MARK: - Session
    
    func restoreSessionIfPossible() async -> Bool {
        do {
            if let session = try await repository.getCurrentSession() {
                Logger.auth.info("Session restored, user: \(session.user.id)")
                return true
            }
        } catch {
            Logger.auth.debug("No session to restore: \(error.localizedDescription)")
        }
        return false
    }
    
    func getCurrentUserId() async -> String? {
        await repository.getCurrentUser()?.id.uuidString
    }
    
    var authStateChanges: AsyncStream<AuthChangeEvent> {
        repository.authStateChanges
    }
    
    // MARK: - Nonce Generation
    
    private func generateNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            
            if status != errSecSuccess {
                fatalError("Unable to generate random bytes")
            }
            
            for random in randoms {
                if remainingLength == 0 { break }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}