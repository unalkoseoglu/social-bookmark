//
//  AuthError.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//

import Foundation

/// Auth işlemlerinde oluşabilecek hatalar
enum AuthError: LocalizedError, Equatable {
    case notAuthenticated
    case notAnonymous
    case signUpFailed
    case appleSignInFailed(String)
    case invalidCredentials
    case emailNotConfirmed
    case userAlreadyExists
    case weakPassword
    case invalidEmail
    case rateLimited
    case userNotFound
    case networkError
    case unknown(String)
    
    // MARK: - LocalizedError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Oturum açmanız gerekiyor"
        case .notAnonymous:
            return "Bu işlem sadece anonim hesaplar için geçerli"
        case .signUpFailed:
            return "Kayıt oluşturulamadı"
        case .appleSignInFailed(let reason):
            return "Apple ile giriş başarısız: \(reason)"
        case .invalidCredentials:
            return "Email veya şifre hatalı"
        case .emailNotConfirmed:
            return "Lütfen emailinizi onaylayın"
        case .userAlreadyExists:
            return "Bu email zaten kayıtlı"
        case .weakPassword:
            return "Şifre en az 6 karakter olmalı"
        case .invalidEmail:
            return "Geçersiz email adresi"
        case .rateLimited:
            return "Çok fazla deneme. Lütfen bekleyin"
        case .userNotFound:
            return "Kullanıcı bulunamadı"
        case .networkError:
            return "İnternet bağlantısı yok"
        case .unknown(let message):
            return message
        }
    }
    
    // MARK: - Localization Key
    
    var localizationKey: String {
        switch self {
        case .notAuthenticated:
            return "auth.error.not_authenticated"
        case .notAnonymous:
            return "auth.error.not_anonymous"
        case .signUpFailed:
            return "auth.error.sign_up_failed"
        case .appleSignInFailed:
            return "auth.error.apple_sign_in_failed"
        case .invalidCredentials:
            return "auth.error.invalid_credentials"
        case .emailNotConfirmed:
            return "auth.error.email_not_confirmed"
        case .userAlreadyExists:
            return "auth.error.user_already_exists"
        case .weakPassword:
            return "auth.error.weak_password"
        case .invalidEmail:
            return "auth.error.invalid_email"
        case .rateLimited:
            return "auth.error.rate_limit"
        case .userNotFound:
            return "auth.error.user_not_found"
        case .networkError:
            return "auth.error.network"
        case .unknown:
            return "auth.error.unknown"
        }
    }
    
    // MARK: - Equatable
    
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        lhs.localizationKey == rhs.localizationKey
    }
}
