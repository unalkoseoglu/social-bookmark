import Foundation
import SwiftUI
import OSLog
import Combine
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
    
    // MARK: - Constants
    
    private let lastUserIdKey = "session_last_user_id"
    // MARK: - Dependencies
    
    private let authService: AuthService
    private let repository: AuthRepositoryProtocol
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
    
    /// Shared singleton instance
    static let shared = SessionStore()
    
    init(authService: AuthService? = nil, repository: AuthRepositoryProtocol = AuthRepository()) {
        self.authService = authService ?? AuthService.shared
        self.repository = repository
        startListeningToAuthChanges()
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Hata durumunu temizle
    func clearError() {
        self.error = nil
    }
    
    /// Attempts to restore an existing session
    func initialize() async {
        isLoading = true
        error = nil
        
        Logger.auth.info("🔄 [SessionStore] Starting initialization...")
        
        let lastId = UserDefaults.standard.string(forKey: lastUserIdKey)
        let hasToken = UserDefaults.standard.string(forKey: APIConstants.Keys.token) != nil
        Logger.auth.info("🔑 [SessionStore] Token exists: \(hasToken), Last user ID: \(lastId ?? "none")")
        
        // Mevcut kullanıcıyı kontrol et
        if let user = await authService.getCurrentUser() {
            Logger.auth.info("✅ [SessionStore] User found: \(user.id.uuidString), isAnonymous: \(user.isAnonymous)")
            
            // Kullanıcı değişmiş mi kontrol et (Migration durumu hariç)
            if let lastId = lastId, lastId != user.id.uuidString {
                Logger.auth.warning("⚠️ [SessionStore] User ID mismatch (\(lastId) -> \(user.id.uuidString)). Wiping local data.")
                await AccountMigrationService.shared.clearAllLocalData()
            }
            
            updateUserState(from: user)
            Logger.auth.info("📝 [SessionStore] User state updated, isAuthenticated: \(self.isAuthenticated)")
            
            // Only load profile if we haven't loaded it for this user yet
            let shouldLoadProfile = userProfile == nil || userProfile?.id != user.id
            if shouldLoadProfile {
                Logger.auth.info("📥 Loading profile for user: \(user.id.uuidString)")
                await loadUserProfile()
            } else {
                Logger.auth.debug("✓ Profile already loaded for user: \(user.id.uuidString), skipping")
            }
            
            os.Logger.auth.info("Session restored for user: \(user.id.uuidString)")
            
            // Son başarılı ID'yi kaydet
            UserDefaults.standard.set(user.id.uuidString, forKey: lastUserIdKey)
        } else {
            Logger.auth.warning("❌ [SessionStore] No user found from getCurrentUser()")
            
            // Hiçbir kullanıcı bulunamadı ve token yok
            // Eğer lastId nil ise ve içeride veri kalmışsa (ghost data), temizle
            if lastId == nil {
                Logger.auth.warning("⚠️ [SessionStore] No session found and no lastUserId. Ensuring local data is wiped.")
                await AccountMigrationService.shared.clearAllLocalData()
            }
            
            resetUserState()
        }
        
        isLoading = false
        os.Logger.auth.info("Session initialization complete, authenticated: \(self.isAuthenticated)")
        
        // ✅ PROD-READY: Otomatik geçiş kontrolü
        if isAuthenticated {
            Task {
                await AccountMigrationService.shared.performMigrationIfNeeded()
            }
        }
    }
    
    /// Initialize session and perform migration if needed
    /// Should be called from app launch with modelContext
    func initializeWithMigration(modelContext: ModelContext) async {
        // First initialize session
        await initialize()
        
        // Then perform migration if needed (only for authenticated users)
        if isAuthenticated {
            await AccountMigrationService.shared.performMigrationIfNeeded(modelContext: modelContext)
        }
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
            Logger.auth.info("Authentication ensured for user: \(user.id.uuidString)")
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
            // Laravel tarafında apple token ile register/login aynı
            _ = try await authService.signInWithApple(credential: credential)
            await initialize()
            Logger.auth.info("Account linked to Apple successfully")
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
            _ = try await authService.linkEmail(email, password: password)
            await initialize()
            Logger.auth.info("Account linked to email successfully")
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
            _ = try await authService.signUp(email: email, password: password, fullName: fullName)
            await initialize()
            Logger.auth.info("Sign up successful")
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
            _ = try await authService.signIn(email: email, password: password)
            await initialize()
            Logger.auth.info("Sign in successful")
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
            Logger.auth.info("✅ [SessionStore] Sign out successful")
        } catch {
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
            resetUserState()
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        } catch {
            self.error = .unknown(error.localizedDescription)
            Logger.auth.error("Account deletion failed: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    // MARK: - User Profile Management
    
    func loadUserProfile() async {
        // Guard: Don't attempt to load profile if we don't have a token
        guard UserDefaults.standard.string(forKey: APIConstants.Keys.token) != nil else {
            Logger.auth.warning("⚠️ [SessionStore] Skipping profile load - no auth token available")
            return
        }
        
        // Guard: Don't load if we're not authenticated
        guard isAuthenticated else {
            Logger.auth.warning("⚠️ [SessionStore] Skipping profile load - user not authenticated")
            return
        }
        
        // Fetch profile from cache or API
        if let profile = await authService.getCurrentUserProfile() {
            // Force UI update by triggering objectWillChange
            await MainActor.run {
                self.objectWillChange.send()
                self.userProfile = profile
                self.displayName = profile.displayName
            }
            Logger.auth.info("✅ User profile loaded: \(profile.displayName)")
        } else {
            Logger.auth.warning("⚠️ Failed to load user profile")
            if let userId = userId, let uuid = UUID(uuidString: userId) {
                await MainActor.run {
                    self.displayName = RandomNameGenerator.generate(from: uuid)
                }
            }
        }
    }
    
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
    
    private func updateUserState(from user: AuthUser) {
        let lastId = UserDefaults.standard.string(forKey: lastUserIdKey)
        
        // GİZLİLİK KORUMASI:
        // Eğer bir ID değişimi varsa VEYA ilk defa ID set ediliyorsa ve içeride veri varsa sil.
        if let lastId = lastId, lastId != user.id.uuidString {
            Logger.auth.warning("⚠️ [SessionStore] User ID mismatch (\(lastId) -> \(user.id.uuidString)). Wiping data.")
            Task { await AccountMigrationService.shared.clearAllLocalData() }
        } else if lastId == nil {
            // İlk kez ID set ediliyor (taze kurulum değilse, yani içeride veri kalmışsa silinmeli)
            // Bu senaryo genellikle "sign out olmuş ama veri temizlenmemiş" durumunda olur.
            Logger.auth.info("ℹ️ [SessionStore] Connecting first user. Ensuring clean state.")
            Task { await AccountMigrationService.shared.clearAllLocalData() }
        }
        
        // CRITICAL: Explicitly trigger UI update
        self.objectWillChange.send()
        self.userId = user.id.uuidString
        self.isAuthenticated = true
        self.isAnonymous = user.isAnonymous
        
        Logger.auth.info("✅ [updateUserState] Set isAuthenticated=\(self.isAuthenticated), isAnonymous=\(self.isAnonymous)")
        
        // ID'yi kaydet
        UserDefaults.standard.set(user.id.uuidString, forKey: lastUserIdKey)
        
        if displayName == nil {
            displayName = user.email ?? RandomNameGenerator.generate(from: user.id)
        }
        
        // NotificationManager.shared.setExternalUserId(user.id.uuidString) // TODO: Re-enable when NotificationManager is available
    }
    
    private func resetUserState() {
        userId = nil
        userEmail = nil
        displayName = nil
        userProfile = nil
        isAuthenticated = false
        isAnonymous = false
        
        UserDefaults.standard.removeObject(forKey: lastUserIdKey)
        // NotificationManager.shared.logout() // TODO: Re-enable when NotificationManager is available
    }
    
    private func startListeningToAuthChanges() {
        authStateTask = Task { [weak self] in
            guard let self = self else { return }
            for await event in repository.authStateChanges {
                await self.handleAuthEvent(event)
            }
        }
    }
    
    private func handleAuthEvent(_ event: AuthEvent) async {
        Logger.auth.debug("Auth event received: \(String(describing: event))")
        
        switch event {
        case .initialSession:
            // Only initialize on initial session
            await initialize()
        case .signedIn:
            // User just signed in - update state and load profile WITHOUT full re-initialization
            Logger.auth.info("🔑 [SessionStore] User signed in, updating state...")
            if let user = await authService.getCurrentUser() {
                updateUserState(from: user)
                
                // Only load profile if we don't have one yet
                if userProfile == nil || userProfile?.id != user.id {
                    Logger.auth.info("📥 Loading profile for newly signed in user: \(user.id.uuidString)")
                    await loadUserProfile()
                } else {
                    Logger.auth.debug("✓ Profile already loaded for user, skipping fetch")
                }
            }
        case .userUpdated:
            // User data updated, but don't re-initialize (profile already loaded)
            // Just refresh the current user state
            if let user = await authService.getCurrentUser() {
                updateUserState(from: user)
                Logger.auth.debug("✓ User state updated without re-initializing")
            }
        case .signedOut:
            resetUserState()
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
        
        guard let currentUserId = self.userId else {
            error = .notAuthenticated
            return
        }
        
        isLoading = true
        error = nil
        
        // Anonim user ID'yi sakla (migration için)
        guard let anonymousUserId = UUID(uuidString: currentUserId) else {
            error = .notAuthenticated
            return
        }
        
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
            // 2. Auth servisinden çıkış
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
    /// Kullanıcı çıkış yaptı
    static let userDidSignOut = Notification.Name("userDidSignOut")
    
    /// Kullanıcı giriş yaptı
    static let userDidSignIn = Notification.Name("userDidSignIn")

    /// Hesap migrasyonu tamamlandı
    static let accountMigrationCompleted = Notification.Name("accountMigrationCompleted")
    
    /// App yeniden başlatılmalı (splash'ten)
    static let appShouldRestart = Notification.Name("appShouldRestart")
}
