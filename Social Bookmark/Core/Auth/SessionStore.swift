//
//  SessionStore.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//
//  ⚠️ GÜNCELLEME: UserProfile display_name desteği eklendi
//  - Anonim kullanıcılar için "user_XXXXXX" formatında isim
//  - Apple Sign In desteği
//

import Foundation
import SwiftUI
import Supabase
import OSLog
internal import Combine
import AuthenticationServices
import CryptoKit

/// Observable session state for SwiftUI views
@MainActor
final class SessionStore: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var userId: String?
    @Published private(set) var userEmail: String?
    @Published private(set) var displayName: String?
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var isAnonymous = false
    @Published private(set) var isLoading = true
    @Published private(set) var error: AuthError?
    
    // MARK: - Apple Sign In State
    
    private var currentNonce: String?
    
    // MARK: - Dependencies
    
    private let authService: AuthService
    private var authStateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var didInitialize = false
    
    // MARK: - Computed Properties
    
    /// Kullanıcı avatar (ilk harf veya initials)
    var avatarInitial: String {
        if let profile = userProfile {
            return profile.initials
        }
        return String((displayName ?? userEmail ?? "U").prefix(1)).uppercased()
    }
    
    /// Gösterilecek isim
    var nameForDisplay: String {
        userProfile?.nameForDisplay ?? displayName ?? userEmail ?? "Kullanıcı"
    }
    
    // MARK: - Initialization
    
    init(authService: AuthService = .shared) {
        self.authService = authService
        startListeningToAuthChanges()
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Error Handling
    
    func setError(_ error: AuthError?) {
        self.error = error
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Public Methods
    
    /// Attempts to restore an existing session
    func initialize() async {
        isLoading = true
        error = nil
        
        // SupabaseManager'ın session restore'unu bekle
        await SupabaseManager.shared.waitForSessionRestore()
        
        // Mevcut kullanıcıyı kontrol et
        if let user = SupabaseManager.shared.currentUser {
            updateUserState(from: user)
            // UserProfile'ı yükle
            await loadUserProfile()
            Logger.auth.info("Session restored for user: \(user.id)")
        } else {
            resetUserState()
        }
        
        isLoading = false
        Logger.auth.info("Session initialization complete, authenticated: \(self.isAuthenticated)")
    }
    
    func initializeOnce() async {
        guard !didInitialize else { return }
        didInitialize = true
        await initialize()
    }

    func ensureAuthenticatedOnce() async {
        // initializeOnce sonrası çalıştır
        await ensureAuthenticated()
    }
    
    /// Ensures user is authenticated (restores session or signs in anonymously)
    func ensureAuthenticated() async {
        isLoading = true
        error = nil
        
        do {
            let user = try await authService.ensureAuthenticated()
            updateUserState(from: user)
            // UserProfile'ı yükle
            await loadUserProfile()
            Logger.auth.info("Authentication ensured for user: \(user.id)")
        } catch let authError as AuthError {
            error = authError
            Logger.auth.error("ensureAuthenticated failed: \(authError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
            Logger.auth.error("ensureAuthenticated failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Signs in anonymously
    func signInAnonymously() async {
        isLoading = true
        error = nil
        
        do {
            let user = try await authService.signInAnonymously()
            updateUserState(from: user)
            // UserProfile'ı yükle
            await loadUserProfile()
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
    
    // MARK: - Apple Sign In
    
    /// Apple Sign In için nonce hazırla
    func prepareAppleSignIn() -> (nonce: String, hashedNonce: String) {
        let nonce = randomNonceString()
        currentNonce = nonce
        let hashedNonce = sha256(nonce)
        return (nonce, hashedNonce)
    }
    
    /// Apple Sign In tamamla (ASAuthorization ile)
    func signInWithApple(credential authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            error = .appleSignInFailed("Invalid credential type")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let user = try await authService.signInWithApple(credential: appleIDCredential)
            updateUserState(from: user)
            await loadUserProfile()
            Logger.auth.info("Apple sign in successful")
        } catch let authError as AuthError {
            error = authError
            Logger.auth.error("Apple sign in failed: \(authError.localizedDescription)")
        } catch {
            self.error = .appleSignInFailed(error.localizedDescription)
            Logger.auth.error("Apple sign in failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Anonim hesabı Apple'a bağla
    func linkToApple(credential: ASAuthorizationAppleIDCredential) async {
        isLoading = true
        error = nil
        
        do {
            // Önce Apple ile giriş yap, hesap otomatik link olacak
            let user = try await authService.signInWithApple(credential: credential)
            updateUserState(from: user)
            await loadUserProfile()
            Logger.auth.info("Account linked to Apple successfully")
        } catch let authError as AuthError {
            error = authError
            Logger.auth.error("Account linking failed: \(authError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    /// Links anonymous account to email
    func linkEmail(_ email: String, password: String) async {
        isLoading = true
        error = nil
        
        do {
            let user = try await authService.linkEmail(email, password: password)
            updateUserState(from: user)
            await loadUserProfile()
            Logger.auth.info("Account linked to email successfully")
        } catch let authError as AuthError {
            error = authError
            Logger.auth.error("Account linking failed: \(authError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - Email/Password Auth
    
    /// Email ile kayıt ol
    func signUp(email: String, password: String, fullName: String? = nil) async {
        isLoading = true
        error = nil
        
        do {
            let user = try await authService.signUp(email: email, password: password, fullName: fullName)
            updateUserState(from: user)
            await loadUserProfile()
            Logger.auth.info("Sign up successful")
        } catch let authError as AuthError {
            error = authError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    /// Email ile giriş yap
    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil
        
        do {
            let user = try await authService.signIn(email: email, password: password)
            updateUserState(from: user)
            await loadUserProfile()
            Logger.auth.info("Sign in successful")
        } catch let authError as AuthError {
            error = authError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out & Delete
    
    /// Signs out the current user
    func signOut() async {
        isLoading = true
        error = nil
        
        do {
            try await authService.signOut()
            resetUserState()
            Logger.auth.info("Sign out successful")
        } catch let authError as AuthError {
            error = authError
            Logger.auth.error("Sign out failed: \(authError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    /// Deletes user account
    func deleteAccount() async {
        isLoading = true
        error = nil
        
        do {
            try await authService.deleteAccount()
            resetUserState()
            Logger.auth.info("Account deleted successfully")
        } catch let authError as AuthError {
            error = authError
            Logger.auth.error("Account deletion failed: \(authError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - User Profile Management
    
    /// UserProfile'ı Supabase'den yükle
    func loadUserProfile() async {
        do {
            if let profile = try await authService.getCurrentUserProfile() {
                self.userProfile = profile
                self.displayName = profile.displayName
                Logger.auth.info("User profile loaded: \(profile.displayName)")
            }
        } catch {
            Logger.auth.error("Failed to load user profile: \(error.localizedDescription)")
            // Hata olursa fallback olarak UUID'den isim oluştur
            if let userId = userId, let uuid = UUID(uuidString: userId) {
                self.displayName = RandomNameGenerator.generate(from: uuid)
            }
        }
    }
    
    /// Display name güncelle
    func updateDisplayName(_ newName: String) async {
        do {
            try await authService.updateDisplayName(newName)
            self.displayName = newName
            self.userProfile?.displayName = newName
            Logger.auth.info("Display name updated to: \(newName)")
        } catch {
            Logger.auth.error("Failed to update display name: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateUserState(from user: User) {
        userId = user.id.uuidString
        userEmail = user.email
        isAuthenticated = true
        isAnonymous = user.isAnonymous
        
        // Geçici displayName (UserProfile yüklenene kadar)
        if displayName == nil {
            if let email = user.email {
                displayName = email
            } else {
                displayName = RandomNameGenerator.generate(from: user.id)
            }
        }
    }
    
    private func resetUserState() {
        userId = nil
        userEmail = nil
        displayName = nil
        userProfile = nil
        isAuthenticated = false
        isAnonymous = false
    }
    
    private func startListeningToAuthChanges() {
        authStateTask = Task { [weak self] in
            guard let self = self else { return }
            
            // SupabaseManager'ın auth state değişikliklerini dinle
            for await (event, session) in SupabaseManager.shared.client.auth.authStateChanges {
                await self.handleAuthEvent(event, session: session)
            }
        }
    }
    
    private func handleAuthEvent(_ event: AuthChangeEvent, session: Session?) async {
        Logger.auth.debug("Auth event received: \(String(describing: event))")
        
        switch event {
        case .initialSession:
            if let session {
                updateUserState(from: session.user)
                await loadUserProfile()
            } else {
                resetUserState()
            }
            isLoading = false
            
        case .signedIn:
            if let session {
                updateUserState(from: session.user)
                await loadUserProfile()
            }
            
        case .signedOut:
            resetUserState()
            
        case .tokenRefreshed:
            Logger.auth.debug("Token refreshed")
            
        case .userUpdated:
            if let session {
                updateUserState(from: session.user)
                await loadUserProfile()
            }
            
        default:
            break
        }
    }
    
    // MARK: - Crypto Helpers (Apple Sign In)
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}
