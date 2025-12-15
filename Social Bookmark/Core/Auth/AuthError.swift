// Core/Auth/AuthError.swift

import Foundation

/// Typed authentication errors
enum AuthError: Error, LocalizedError, Equatable {
    case notAuthenticated
    case sessionExpired
    case invalidCredentials
    case networkError(String)
    case appleSignInFailed(String)
    case linkingFailed(String)
    case userCancelled
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "auth.error.not_authenticated")
        case .sessionExpired:
            return String(localized: "auth.error.session_expired")
        case .invalidCredentials:
            return String(localized: "auth.error.invalid_credentials")
        case .networkError(let message):
            return String(localized: "auth.error.network \(message)")
        case .appleSignInFailed(let message):
            return String(localized: "auth.error.apple_sign_in \(message)")
        case .linkingFailed(let message):
            return String(localized: "auth.error.linking \(message)")
        case .userCancelled:
            return String(localized: "auth.error.user_cancelled")
        case .unknown(let message):
            return String(localized: "auth.error.unknown \(message)")
        }
    }
    
    /// User-facing localization key
    var localizationKey: String {
        switch self {
        case .notAuthenticated: return "auth.error.not_authenticated"
        case .sessionExpired: return "auth.error.session_expired"
        case .invalidCredentials: return "auth.error.invalid_credentials"
        case .networkError: return "auth.error.network"
        case .appleSignInFailed: return "auth.error.apple_sign_in"
        case .linkingFailed: return "auth.error.linking"
        case .userCancelled: return "auth.error.user_cancelled"
        case .unknown: return "auth.error.unknown"
        }
    }
    
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated),
             (.sessionExpired, .sessionExpired),
             (.invalidCredentials, .invalidCredentials),
             (.userCancelled, .userCancelled):
            return true
        case (.networkError(let l), .networkError(let r)),
             (.appleSignInFailed(let l), .appleSignInFailed(let r)),
             (.linkingFailed(let l), .linkingFailed(let r)),
             (.unknown(let l), .unknown(let r)):
            return l == r
        default:
            return false
        }
    }
}