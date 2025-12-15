// Core/Auth/AuthService.swift

import Foundation
import AuthenticationServices
import CryptoKit
import OSLog
import Auth
internal import Combine
import Supabase

/// Business logic layer for authentication
/// Handles Apple Sign In flow and coordinates with AuthRepository
final class AuthService: ObservableObject {

    
    
    static let shared = AuthService()
    private let repository: AuthRepositoryProtocol
    private var currentNonce: String?
    
    /// İşlem devam ediyor mu?
    @Published private(set) var isLoading = false
        
    /// Son hata mesajı
    @Published var errorMessage: String?
    
    init(repository: AuthRepositoryProtocol = AuthRepository()) {
        self.repository = repository
        
    }
    
    /// Mevcut kullanıcı
    var currentUser: User? {
        SupabaseManager.shared.currentUser
    }
        
    /// Kullanıcı anonim mi?
    var isAnonymous: Bool {
        currentUser?.isAnonymous ?? false
    }
        
    /// Kullanıcı giriş yapmış mı?
    var isAuthenticated: Bool {
        SupabaseManager.shared.isAuthenticated
    }
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    private var ensureTask: Task<User, Error>?

        func ensureAuthenticated() async throws -> User {
            if let user = SupabaseManager.shared.currentUser { return user }

            if let task = ensureTask { return try await task.value }

            let task = Task<User, Error> {
                await SupabaseManager.shared.waitForSessionRestore()

                if let user = SupabaseManager.shared.currentUser { return user }

                let session = try await SupabaseManager.shared.client.auth.signInAnonymously()
                return session.user
            }

            ensureTask = task
            defer { ensureTask = nil }

            return try await task.value
        }
        
        // MARK: - Anonymous Auth
        
        /// Anonim giriş yap
        /// ⚠️ Direkt çağırmak yerine ensureAuthenticated() kullanın
        /// Bu metod her zaman YENİ bir anonim kullanıcı oluşturur
        @discardableResult
        func signInAnonymously() async throws -> User {
            // ✅ Önce mevcut session kontrol et
            if let existingUser = SupabaseManager.shared.currentUser,
              await SupabaseManager.shared.hasValidSession() {
                print("⚠️ [AUTH] Already authenticated, returning existing user")
                print("   User ID: \(existingUser.id)")
                return existingUser
            }
            
            isLoading = true
            errorMessage = nil
            
            defer { isLoading = false }
            
            do {
                print("🔐 [AUTH] Creating new anonymous user...")
                
                let session = try await client.auth.signInAnonymously()
                
                print("✅ [AUTH] Anonymous sign in successful!")
                print("   New User ID: \(session.user.id)")
                print("   Session Expires: \(session.expiresAt)")
                
                // User profile oluştur (opsiyonel)
                try? await createUserProfileIfNeeded(for: session.user)
                
                return session.user
            } catch {
                errorMessage = mapAuthError(error)
                print("❌ [AUTH] Anonymous sign in failed: \(error)")
                throw error
            }
        }
        
        /// Anonim hesabı email ile upgrade et
        /// Mevcut verileri koruyarak kalıcı hesaba dönüştürür
        func linkEmail(_ email: String, password: String) async throws -> User {
            guard isAnonymous else {
                throw AuthError.notAnonymous
            }
            
            isLoading = true
            errorMessage = nil
            
            defer { isLoading = false }
            
            do {
                print("🔄 Linking email to anonymous account...")
                
                let response = try await client.auth.update(user: .init(
                    email: email,
                    password: password
                ))
                
                print("✅ Email linked successfully")
                return response
            } catch {
                errorMessage = mapAuthError(error)
                throw error
            }
        }
        
        // MARK: - Email/Password Auth
        
        /// Email ve şifre ile kayıt ol
        func signUp(email: String, password: String, fullName: String? = nil) async throws -> User {
            isLoading = true
            errorMessage = nil
            
            defer { isLoading = false }
            
            do {
                print("📧 Sign up starting for: \(email)")
                
                var metadata: [String: AnyJSON] = [:]
                if let fullName {
                    metadata["full_name"] = .string(fullName)
                }
                
                let response = try await client.auth.signUp(
                    email: email,
                    password: password,
                    data: metadata
                )
                
                 let user = response.user
                print("✅ Sign up successful: \(user.id)")
                
                // User profile oluştur
                try? await createUserProfileIfNeeded(for: user, fullName: fullName)
                
                return user
            } catch {
                errorMessage = mapAuthError(error)
                throw error
            }
        }
        
        /// Email ve şifre ile giriş yap
        func signIn(email: String, password: String) async throws -> User {
            isLoading = true
            errorMessage = nil
            
            defer { isLoading = false }
            
            do {
                print("📧 Sign in starting for: \(email)")
                
                let session = try await client.auth.signIn(
                    email: email,
                    password: password
                )
                
                print("✅ Sign in successful: \(session.user.id)")
                return session.user
            } catch {
                errorMessage = mapAuthError(error)
                throw error
            }
        }
        
        // MARK: - Magic Link
        
        /// Magic link gönder (şifresiz giriş)
        func sendMagicLink(to email: String) async throws {
            isLoading = true
            errorMessage = nil
            
            defer { isLoading = false }
            
            do {
                print("✉️ Sending magic link to: \(email)")
                
                try await client.auth.signInWithOTP(
                    email: email,
                    redirectTo: URL(string: "socialbookmark://auth/callback")
                )
                
                print("✅ Magic link sent")
            } catch {
                errorMessage = mapAuthError(error)
                throw error
            }
        }
        
        /// OTP ile doğrula (magic link callback)
        func verifyOTP(email: String, token: String) async throws -> User {
            isLoading = true
            errorMessage = nil
            
            defer { isLoading = false }
            
            do {
                let session = try await client.auth.verifyOTP(
                    email: email,
                    token: token,
                    type: .magiclink
                )
                
                print("✅ OTP verified: \(session.user.id)")
                return session.user
            } catch {
                errorMessage = mapAuthError(error)
                throw error
            }
        }
        
        // MARK: - Apple Sign-In
        
        /// Apple ile giriş yap
        func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> User {
            isLoading = true
            errorMessage = nil
            
            defer { isLoading = false }
            
            do {
                print("🍎 Apple sign in starting...")
                
                guard let identityToken = credential.identityToken,
                      let tokenString = String(data: identityToken, encoding: .utf8) else {
                    throw AuthError.appleSignInFailed(errorMessage ??  "")
                }
                
                let session = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: tokenString
                    )
                )
                
                print("✅ Apple sign in successful: \(session.user.id)")
                
                // Apple'dan gelen isim bilgisini kaydet
                if let fullName = credential.fullName {
                    let name = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    
                    if !name.isEmpty {
                        try? await updateProfile(fullName: name)
                    }
                }
                
                return session.user
            } catch {
                errorMessage = mapAuthError(error)
                throw error
            }
        }
        
        // MARK: - Password Management
        
        /// Şifre sıfırlama emaili gönder
        func sendPasswordReset(to email: String) async throws {
            isLoading = true
            errorMessage = nil
            
            defer { isLoading = false }
            
            do {
                print("🔑 Sending password reset to: \(email)")
                
                try await client.auth.resetPasswordForEmail(
                    email,
                    redirectTo: URL(string: "socialbookmark://auth/reset-password")
                )
                
                print("✅ Password reset email sent")
            } catch {
                errorMessage = mapAuthError(error)
                throw error
            }
        }
        
        /// Şifreyi güncelle
        func updatePassword(_ newPassword: String) async throws {
            isLoading = true
            errorMessage = nil
            
            defer { isLoading = false }
            
            do {
                try await client.auth.update(user: .init(password: newPassword))
                print("✅ Password updated")
            } catch {
                errorMessage = mapAuthError(error)
                throw error
            }
        }
        
        // MARK: - Profile Management
        
        /// Profil bilgilerini güncelle
        func updateProfile(fullName: String? = nil, avatarURL: String? = nil) async throws {
            var data: [String: AnyJSON] = [:]
            
            if let fullName {
                data["full_name"] = .string(fullName)
            }
            if let avatarURL {
                data["avatar_url"] = .string(avatarURL)
            }
            
            guard !data.isEmpty else { return }
            
            try await client.auth.update(user: .init(data: data))
            print("✅ Profile updated")
        }
        
        /// User profiles tablosuna kayıt oluştur
        private func createUserProfileIfNeeded(for user: User, fullName: String? = nil) async throws {
            let profile = UserProfile(
                id: user.id,
                email: user.email,
                fullName: fullName ?? user.userMetadata["full_name"]?.stringValue,
                isAnonymous: user.isAnonymous,
                createdAt: Date()
            )
            
            try await client
                .from(SupabaseConfig.Tables.userProfiles)
                .upsert(profile, onConflict: "id")
                .execute()
            
            print("✅ User profile created/updated")
        }
        
        // MARK: - Sign Out
        
        /// Çıkış yap
        func signOut() async throws {
            isLoading = true
            errorMessage = nil
            
            defer { isLoading = false }
            
            try await SupabaseManager.shared.signOut()
        }
        
        // MARK: - Account Deletion
        
        /// Hesabı sil (GDPR uyumlu)
        func deleteAccount() async throws {
            guard let userId = currentUser?.id else {
                throw AuthError.notAuthenticated
            }
            
            isLoading = true
            errorMessage = nil
            
            defer { isLoading = false }
            
            do {
                print("🗑️ Deleting account: \(userId)")
                
                // 1. Kullanıcı verilerini sil (cascade ile otomatik silinmeli)
                // Eğer cascade yoksa manuel sil:
                try await client.from(SupabaseConfig.Tables.bookmarks)
                    .delete()
                    .eq("user_id", value: userId)
                    .execute()
                
                try await client.from(SupabaseConfig.Tables.categories)
                    .delete()
                    .eq("user_id", value: userId)
                    .execute()
                
                // 2. Storage'daki dosyaları sil
                try? await deleteUserStorage(userId: userId)
                
                // 3. Profili sil
                try await client.from(SupabaseConfig.Tables.userProfiles)
                    .delete()
                    .eq("id", value: userId)
                    .execute()
                
                // 4. Çıkış yap (Auth user deletion admin API gerektirir)
                try await signOut()
                
                print("✅ Account deleted")
            } catch {
                errorMessage = "Hesap silinemedi: \(error.localizedDescription)"
                throw error
            }
        }
        
        /// Kullanıcı storage dosyalarını sil
        private func deleteUserStorage(userId: UUID) async throws {
            let bucket = SupabaseConfig.Storage.bookmarkImagesBucket
            let path = "\(userId.uuidString)/"
            
            // Kullanıcı klasöründeki tüm dosyaları listele ve sil
            let files = try await client.storage.from(bucket).list(path: path)
            
            if !files.isEmpty {
                let filePaths = files.map { "\(path)\($0.name)" }
                try await client.storage.from(bucket).remove(paths: filePaths)
                print("✅ Deleted \(files.count) storage files")
            }
        }
        
        // MARK: - Error Mapping
        
        /// Auth hatalarını kullanıcı dostu mesajlara çevir
    /// Auth hatalarını localization key'e çevirir
    private func mapAuthError(_ error: Error) -> String {
        
        // Bizim typed error'larımız
        if let authError = error as? AuthError {
            return authError.localizationKey
        }
        
        let nsError = error as NSError
        
        // Supabase Auth error_code mapping
        if let errorCode = nsError.userInfo["error_code"] as? String {
            switch errorCode {
            case "invalid_credentials":
                return "auth.error.invalid_credentials"
            case "email_not_confirmed":
                return "auth.error.email_not_confirmed"
            case "user_already_exists":
                return "auth.error.user_already_exists"
            case "weak_password":
                return "auth.error.weak_password"
            case "invalid_email":
                return "auth.error.invalid_email"
            case "over_request_rate_limit":
                return "auth.error.rate_limit"
            case "user_not_found":
                return "auth.error.user_not_found"
            default:
                break
            }
        }
        
        // Network hataları
        if nsError.domain == NSURLErrorDomain {
            return "auth.error.network"
        }
        
        // Fallback
        return "auth.error.unknown"
    }

}



