//
//  AuthService.swift
//  Social Bookmark
//
//  Core/Auth/AuthService.swift
//

import Foundation
import AuthenticationServices
import CryptoKit
internal import Combine
import Supabase
import OSLog

/// Business logic layer for authentication
/// Handles Apple Sign In flow and coordinates with AuthRepository
@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()

    private let repository: AuthRepositoryProtocol
    private var ensureTask: Task<User, Error>?

    /// Apple Sign-In için nonce (orijinal nonce - Supabase'e gönderilecek)
    private var currentNonce: String?

    /// İşlem devam ediyor mu?
    @Published private(set) var isLoading = false

    /// Son hata mesajı (localization key)
    @Published var errorMessage: String?

    init(repository: AuthRepositoryProtocol = AuthRepository()) {
        self.repository = repository
    }

    // MARK: - Dependencies

    private var client: SupabaseClient {
        SupabaseManager.shared.client
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

    // MARK: - Ensure authenticated (anon fallback)

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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await client.auth.signInAnonymously()
            try? await createUserProfileIfNeeded(for: session.user)
            return session.user
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    /// Anonim hesabı email ile upgrade et
    /// Mevcut verileri koruyarak kalıcı hesaba dönüştürür
    func linkEmail(_ email: String, password: String) async throws -> User {
        guard isAnonymous else { throw AuthError.notAnonymous }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await client.auth.update(user: .init(email: email, password: password))
            return response
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    // MARK: - Email/Password Auth

    func signUp(email: String, password: String, fullName: String? = nil) async throws -> User {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var metadata: [String: AnyJSON] = [:]
            if let fullName { metadata["full_name"] = .string(fullName) }

            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: metadata
            )

            let user = response.user
            try? await createUserProfileIfNeeded(for: user, fullName: fullName)
            return user
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    func signIn(email: String, password: String) async throws -> User {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return session.user
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    // MARK: - Magic Link

    func sendMagicLink(to email: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: URL(string: "socialbookmark://auth/callback")
            )
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

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
            return session.user
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    // MARK: - Apple Sign-In (Nonce fix)

    /// SwiftUI `SignInWithAppleButton` içindeki `onRequest` closure'da çağır.
    ///
    /// Ör:
    /// SignInWithAppleButton(.signIn) { request in
    ///   AuthService.shared.configureAppleRequest(request)
    /// } onCompletion: { result in ... }
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce

        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce) // ✅ Apple token'a nonce claim'i girer
    }

    /// Apple credential geldikten sonra Supabase'e giriş yap.
    /// `configureAppleRequest(_:)` ile oluşturulan nonce burada Supabase'e ORİJİNAL haliyle verilir.
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> User {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                throw AuthError.appleSignInFailed("auth.error.apple_token_missing")
            }

            // ✅ Nonce tutarlılığı: Supabase'e orijinal nonce
            let nonce = currentNonce

            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: tokenString,
                    nonce: nonce
                )
            )

            // Temizlik
            currentNonce = nil
            
            

            // Apple'dan gelen isim (sadece ilk sefer gelebilir)
            if let fullName = credential.fullName {
                let name = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")

                if !name.isEmpty {
                    try? await updateProfile(fullName: name)
                }
            }

            // Profil kaydı
            try? await createUserProfileIfNeeded(for: session.user)

            return session.user
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    // MARK: - Password Management

    func sendPasswordReset(to email: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "socialbookmark://auth/reset-password")
            )
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    func updatePassword(_ newPassword: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await client.auth.update(user: .init(password: newPassword))
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    // MARK: - Profile Management

    func updateProfile(fullName: String? = nil, avatarURL: String? = nil) async throws {
        var data: [String: AnyJSON] = [:]
        if let fullName { data["full_name"] = .string(fullName) }
        if let avatarURL { data["avatar_url"] = .string(avatarURL) }
        guard !data.isEmpty else { return }

        try await client.auth.update(user: .init(data: data))
    }

    /// User profiles tablosuna kayıt oluştur
    func createUserProfileIfNeeded(for user: User, fullName: String? = nil) async throws {
        let existingProfile: UserProfile? = try? await client
            .from(SupabaseConfig.Tables.userProfiles)
            .select()
            .eq("id", value: user.id)
            .single()
            .execute()
            .value

        let profile: UserProfile

        if let existing = existingProfile {
            profile = UserProfile(
                id: existing.id,
                email: user.email ?? existing.email,
                fullName: fullName ?? existing.fullName,
                displayName: existing.displayName,
                isAnonymous: user.isAnonymous,
                createdAt: existing.createdAt,
                avatarUrl: existing.avatarUrl,
                lastSyncAt: Date(),
                deviceId: UIDevice.current.identifierForVendor?.uuidString,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            )
        } else {
            if user.isAnonymous {
                profile = UserProfile.createAnonymous(userId: user.id)
            } else {
                let name = fullName ?? user.userMetadata["full_name"]?.stringValue
                profile = UserProfile.create(userId: user.id, email: user.email, fullName: name)
            }
        }

        do {
            try await client
                .from(SupabaseConfig.Tables.userProfiles)
                .upsert(profile, onConflict: "id")
                .execute()
            print("✅ [AuthService] UserProfile upsert succeeded for user: \(user.id)")
        } catch {
            print("❌ [AuthService] UserProfile upsert failed: \(error.localizedDescription)")
            throw error
        }
    }

    func getCurrentUserProfile() async throws -> UserProfile? {
        guard let userId = currentUser?.id else { return nil }

        let profile: UserProfile = try await client
            .from(SupabaseConfig.Tables.userProfiles)
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        return profile
    }

    func updateDisplayName(_ newName: String) async throws {
        guard let userId = currentUser?.id else { throw AuthError.notAuthenticated }

        try await client
            .from(SupabaseConfig.Tables.userProfiles)
            .update([
                "display_name": newName,
                "last_sync_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: userId)
            .execute()
    }

    func updateAvatarUrl(_ url: String?) async throws {
        guard let userId = currentUser?.id else { throw AuthError.notAuthenticated }

        let updateData: [String: String?] = [
            "avatar_url": url,
            "last_sync_at": ISO8601DateFormatter().string(from: Date())
        ]

        try await client
            .from(SupabaseConfig.Tables.userProfiles)
            .update(updateData)
            .eq("id", value: userId)
            .execute()
    }

    // MARK: - Sign Out

    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        try await SupabaseManager.shared.signOut()
    }

    // MARK: - Account Deletion

    func deleteAccount() async throws {
        guard let userId = currentUser?.id else { throw AuthError.notAuthenticated }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await client.from(SupabaseConfig.Tables.bookmarks)
                .delete()
                .eq("user_id", value: userId)
                .execute()

            try await client.from(SupabaseConfig.Tables.categories)
                .delete()
                .eq("user_id", value: userId)
                .execute()

            try? await deleteUserStorage(userId: userId)

            try await client.from(SupabaseConfig.Tables.userProfiles)
                .delete()
                .eq("id", value: userId)
                .execute()

            try await signOut()
        } catch {
            errorMessage = "auth.error.account_delete_failed"
            throw error
        }
    }

    private func deleteUserStorage(userId: UUID) async throws {
        let bucket = SupabaseConfig.Storage.bookmarkImagesBucket
        let path = "\(userId.uuidString)/"

        let files = try await client.storage.from(bucket).list(path: path)
        if !files.isEmpty {
            let filePaths = files.map { "\(path)\($0.name)" }
            try await client.storage.from(bucket).remove(paths: filePaths)
        }
    }

    // MARK: - Error Mapping

    private func mapAuthError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            return authError.localizationKey
        }

        let nsError = error as NSError

        if let errorCode = nsError.userInfo["error_code"] as? String {
            switch errorCode {
            case "invalid_credentials": return "auth.error.invalid_credentials"
            case "email_not_confirmed": return "auth.error.email_not_confirmed"
            case "user_already_exists": return "auth.error.user_already_exists"
            case "weak_password": return "auth.error.weak_password"
            case "invalid_email": return "auth.error.invalid_email"
            case "over_request_rate_limit": return "auth.error.rate_limit"
            case "user_not_found": return "auth.error.user_not_found"
            default: break
            }
        }

        if nsError.domain == NSURLErrorDomain {
            return "auth.error.network"
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
