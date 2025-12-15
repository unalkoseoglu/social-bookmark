//
//  SupabaseManager.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//
//  ⚠️ Session Persistence Fix:
//  - Özel KeychainSessionStorage implementasyonu
//  - Detaylı debug logları
//  - Session restore kontrolü
//

import Foundation
import Supabase
import Security
internal import Combine

/// Supabase client singleton yöneticisi
@MainActor
final class SupabaseManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SupabaseManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var authState: AuthState = .initializing
    @Published private(set) var currentUser: User?
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastError: SupabaseError?
    @Published private(set) var isSessionRestored = false
    
    // MARK: - Properties
    
    let client: SupabaseClient
    private var authStateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    /// Özel session storage - Keychain'e persist eder
    private static let sessionStorage = KeychainSessionStorage()
    
    // MARK: - Computed Properties
    
    var isAuthenticated: Bool { currentUser != nil }
    var userId: UUID? { currentUser?.id }
    
    func hasValidSession() async -> Bool {
        do {
            let session = try await client.auth.session
            let isValid = !session.isExpired
            print("🔍 [SESSION] Valid: \(isValid), Expires: \(session.expiresAt)")
            return isValid
        } catch {
            print("🔍 [SESSION] No session: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        print("🟢 ═══════════════════════════════════════")
        print("🟢 SupabaseManager Initializing...")
        print("🟢 ═══════════════════════════════════════")
        
        // Config doğrula
        let status = SupabaseConfig.validate()
        if case .invalid(let issues) = status {
            print("⚠️ Config Issues: \(issues.joined(separator: ", "))")
        }
        
        // Keychain'deki mevcut session'ı kontrol et
        Self.sessionStorage.debugPrintStoredKeys()
        
        // Client oluştur - ÖZEL KEYCHAIN STORAGE
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: Self.sessionStorage,  // ✅ Özel Keychain storage
                    autoRefreshToken: true,
                ),
               
            )
        )
        
        print("🟢 SupabaseClient created with custom Keychain storage")
        
        // Auth state listener başlat
        setupAuthStateListener()
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Auth State Management
    
    private func setupAuthStateListener() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            
            print("🔄 [AUTH] State listener started, waiting for events...")
            
            for await (event, session) in client.auth.authStateChanges {
                await MainActor.run {
                    self.handleAuthStateChange(event: event, session: session)
                }
            }
        }
    }
    
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) {
        print("═══════════════════════════════════════")
        print("🔐 [AUTH EVENT] \(event)")
        print("═══════════════════════════════════════")
        
        switch event {
        case .initialSession:
            isSessionRestored = true
            
            if let session {
                currentUser = session.user
                authState = .authenticated(session.user)
                print("✅ [RESTORE] Session found in Keychain!")
                print("   User ID: \(session.user.id)")
                print("   Email: \(session.user.email ?? "anonymous")")
                print("   Is Anonymous: \(session.user.isAnonymous)")
                print("   Access Token: \(String(session.accessToken.prefix(30)))...")
                print("   Expires At: \(session.expiresAt)")
            } else {
                currentUser = nil
                authState = .unauthenticated
                print("ℹ️ [RESTORE] No session in Keychain - need to sign in")
            }
            
        case .signedIn:
            if let session {
                currentUser = session.user
                authState = .authenticated(session.user)
                print("✅ [SIGN IN] New session created")
                print("   User ID: \(session.user.id)")
                print("   Is Anonymous: \(session.user.isAnonymous)")
                
                // Keychain'e yazıldığını doğrula
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Self.sessionStorage.debugPrintStoredKeys()
                }
                
                NotificationCenter.default.post(name: .userDidSignIn, object: session.user)
            }
            
        case .signedOut:
            currentUser = nil
            authState = .unauthenticated
            print("👋 [SIGN OUT] Session cleared")
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
            
        case .tokenRefreshed:
            if let session {
                currentUser = session.user
                print("🔄 [REFRESH] Token refreshed, new expiry: \(session.expiresAt)")
            }
            
        case .userUpdated:
            if let session {
                currentUser = session.user
                print("👤 [UPDATE] User updated")
            }
            
        case .userDeleted:
            currentUser = nil
            authState = .unauthenticated
            print("🗑️ [DELETE] User deleted")
            
        default:
            print("ℹ️ [OTHER] Event: \(event)")
        }
    }
    
    // MARK: - Public Methods
    
    func waitForSessionRestore() async {
        guard !isSessionRestored else {
            print("✅ [WAIT] Session already restored")
            return
        }
        
        print("⏳ [WAIT] Waiting for session restore...")
        
        for await restored in $isSessionRestored.values {
            if restored {
                print("✅ [WAIT] Session restore complete")
                break
            }
        }
    }
    
    func refreshSession() async throws {
        print("🔄 [REFRESH] Refreshing session...")
        let session = try await client.auth.refreshSession()
        currentUser = session.user
        authState = .authenticated(session.user)
        print("✅ [REFRESH] New expiry: \(session.expiresAt)")
    }
    
    func signOut() async throws {
        print("👋 [SIGNOUT] Signing out...")
        try await client.auth.signOut()
        currentUser = nil
        authState = .unauthenticated
        lastError = nil
        print("✅ [SIGNOUT] Complete")
    }
    
    func getCurrentSession()async -> Session? {
        try? await client.auth.session
    }
    
    func printSessionDebugInfo()async {
        print("═══════════════════════════════════════")
        print("📊 SESSION DEBUG INFO")
        print("═══════════════════════════════════════")
        print("Auth State: \(authState)")
        print("Is Authenticated: \(isAuthenticated)")
        print("Is Session Restored: \(isSessionRestored)")
        print("Current User ID: \(currentUser?.id.uuidString ?? "nil")")
        print("Current User Email: \(currentUser?.email ?? "nil")")
        print("Is Anonymous: \(currentUser?.isAnonymous ?? false)")
        
        if let session = await getCurrentSession() {
            print("Session Expires: \(session.expiresAt)")
            print("Session Is Expired: \(session.isExpired)")
            print("Access Token (first 30): \(String(session.accessToken.prefix(30)))...")
        } else {
            print("Session: nil")
        }
        
        print("═══════════════════════════════════════")
        print("📦 KEYCHAIN CONTENTS:")
        Self.sessionStorage.debugPrintStoredKeys()
        print("═══════════════════════════════════════")
    }
    
    func recordError(_ error: Error, context: String? = nil) {
        let supabaseError = SupabaseError(
            underlyingError: error,
            context: context,
            timestamp: Date()
        )
        lastError = supabaseError
        print("❌ [ERROR] [\(context ?? "unknown")]: \(error.localizedDescription)")
    }
    
    func clearError() {
        lastError = nil
    }
}

// MARK: - Types

extension SupabaseManager {
    
    enum AuthState: Equatable {
        case initializing
        case unauthenticated
        case authenticated(User)
        case error(String)
        
        static func == (lhs: AuthState, rhs: AuthState) -> Bool {
            switch (lhs, rhs) {
            case (.initializing, .initializing),
                 (.unauthenticated, .unauthenticated):
                return true
            case (.authenticated(let l), .authenticated(let r)):
                return l.id == r.id
            case (.error(let l), .error(let r)):
                return l == r
            default:
                return false
            }
        }
    }
    
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    struct SupabaseError: Identifiable {
        let id = UUID()
        let underlyingError: Error
        let context: String?
        let timestamp: Date
        
        var localizedDescription: String {
            underlyingError.localizedDescription
        }
    }
    
    private struct TestConnection: Decodable {
        let id: UUID?
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userDidSignIn = Notification.Name("userDidSignIn")
    static let userDidSignOut = Notification.Name("userDidSignOut")
    static let syncDidStart = Notification.Name("syncDidStart")
    static let syncDidComplete = Notification.Name("syncDidComplete")
    static let syncDidFail = Notification.Name("syncDidFail")
}

// MARK: - User Extension

extension User {
    var isAnonymous: Bool {
        email == nil && (identities?.isEmpty ?? true)
    }
}

// MARK: - SupabaseClient Extension

extension SupabaseClient {
    var bookmarks: PostgrestQueryBuilder {
        from(SupabaseConfig.Tables.bookmarks)
    }
    
    var categories: PostgrestQueryBuilder {
        from(SupabaseConfig.Tables.categories)
    }
}
