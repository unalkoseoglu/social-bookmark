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
import SwiftData

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
            os.Logger.auth.info("Session restored for user: \(user.id)")
        } else {
            resetUserState()
        }
        
        isLoading = false
        os.Logger.auth.info("Session initialization complete, authenticated: \(self.isAuthenticated)")
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
    
    /// Apple Sign In için request'i konfigüre et
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        authService.configureAppleRequest(request)
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
            // ✅ Session varsa sign out yap
            if isAuthenticated {
                try await authService.signOut()
            }
            
            // Local state'i temizle
            resetUserState()
            Logger.auth.info("✅ [SessionStore] Sign out successful")
            
        } catch {
            // ⚠️ Hata olsa bile local state'i temizle
            Logger.auth.warning("⚠️ [SessionStore] Sign out warning: \(error.localizedDescription)")
            resetUserState()
        }
        
        isLoading = false
    }
    /// Deletes user account
    @MainActor
    func deleteAccount() async {
        isLoading = true
        error = nil
        do {
            try await authService.deleteAccount()
            Logger.auth.info("Account deleted successfully")
            await AccountMigrationService.shared.clearAllLocalData()
            ImageUploadService.shared.clearCache()
            resetUserState()
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
            try await Task.sleep(nanoseconds: 500_000_000)
            await signInAnonymously()
            NotificationCenter.default.post(name: .appShouldRestart, object: nil)
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
    
}

extension SessionStore {
    
    /// Anonim hesabı Apple'a bağla VE verileri taşı
    /// Bu metod mevcut `linkToApple` metodunu değiştirir
    func linkAnonymousToApple(credential: ASAuthorizationAppleIDCredential) async {
        guard isAnonymous else {
            Logger.auth.warning("linkAnonymousToApple called but user is not anonymous")
            return
        }
        
        guard let currentUserId = SupabaseManager.shared.userId else {
            error = .notAuthenticated
            return
        }
        
        isLoading = true
        error = nil
        
        // Anonim user ID'yi sakla (migration için)
        let anonymousUserId = currentUserId
        
        Logger.auth.info("🔄 [SessionStore] Starting anonymous -> Apple migration")
        
        do {
            // 1. Apple ile giriş yap (yeni hesap oluşturulacak veya mevcut hesaba bağlanacak)
            let newUser = try await authService.signInWithApple(credential: credential)
            
            // 2. Yeni kullanıcı farklı mı kontrol et
            guard newUser.id != anonymousUserId else {
                // Aynı kullanıcı, sadece identity link olmuş
                updateUserState(from: newUser)
                await loadUserProfile()
                Logger.auth.info("✅ [SessionStore] Identity linked to existing account")
                isLoading = false
                return
            }
            
            // 3. Verileri yeni hesaba taşı
            Logger.auth.info("🔄 [SessionStore] Migrating data from \(anonymousUserId) to \(newUser.id)")
            
            let result = try await AccountMigrationService.shared.migrateAnonymousDataToAppleAccount(
                from: anonymousUserId,
                to: newUser.id
            )
            
            // 4. Kullanıcı state'ini güncelle
            updateUserState(from: newUser)
            await loadUserProfile()
            
            Logger.auth.info("✅ [SessionStore] Migration completed! Categories: \(result.categoriesMigrated), Bookmarks: \(result.bookmarksMigrated)")
            
            // 5. Bildirim gönder
            NotificationCenter.default.post(
                name: .accountMigrationCompleted,
                object: result
            )
            
        } catch let migrationError as MigrationError {
            Logger.auth.error("❌ [SessionStore] Migration failed: \(migrationError.localizedDescription)")
            error = .unknown(migrationError.localizedDescription)
        } catch let authError as AuthError {
            error = authError
            Logger.auth.error("❌ [SessionStore] Apple sign in failed: \(authError.localizedDescription)")
        } catch {
            self.error = .unknown(error.localizedDescription)
            Logger.auth.error("❌ [SessionStore] Unknown error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Çıkış yap - Local verileri temizle ve app'i yeniden başlat
    func signOutAndClearData() async {
        isLoading = true
        error = nil
        
        Logger.auth.info("🚪 [SessionStore] Signing out and clearing local data...")
        
        do {
            // 1. Auto sync'i durdur
            SyncService.shared.stopAutoSync()
            
            // 2. Supabase'den çıkış
            try await authService.signOut()
            
            // 3. Local SwiftData verilerini temizle
            await AccountMigrationService.shared.clearAllLocalData()
            
            // 4. Cache'leri temizle
            ImageUploadService.shared.clearCache()
            
            // 5. State'i sıfırla
            resetUserState()
            
            Logger.auth.info("✅ [SessionStore] Signed out and data cleared")
            
            // 6. Bildirim gönder - UI'ın splash'e dönmesi için
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
            
            // 7. Kısa bir bekleme
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 saniye
            
            // 8. Yeni anonim kullanıcı oluştur
            Logger.auth.info("🔄 [SessionStore] Creating new anonymous user...")
            await signInAnonymously()
            
            // 9. App'i splash'ten yeniden başlat
            Logger.auth.info("🔄 [SessionStore] Triggering app restart...")
            NotificationCenter.default.post(name: .appShouldRestart, object: nil)
            
        } catch {
            self.error = .unknown(error.localizedDescription)
            Logger.auth.error("❌ [SessionStore] Sign out failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Local verileri temizle - AccountMigrationService kullan
    private func clearLocalDataOnSignOut() async {
        await AccountMigrationService.shared.clearAllLocalData()
    }
    
    /// ModelContext'i al (SyncService üzerinden)
    @MainActor
    private func getModelContext() async -> ModelContext? {
        // Bu metod uygulamanın yapısına göre düzenlenmeli
        // Örneğin App'ten veya SyncService'ten alınabilir
        return nil // Placeholder - gerçek implementasyonda düzeltilmeli
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Hesap migrasyonu tamamlandı
    static let accountMigrationCompleted = Notification.Name("accountMigrationCompleted")
    
    /// App yeniden başlatılmalı (splash'ten)
    static let appShouldRestart = Notification.Name("appShouldRestart")
    
    // userDidSignOut zaten SupabaseManager.swift'te tanımlı
}
