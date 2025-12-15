//
//  SupabaseErrors.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//

import Foundation

/// Supabase işlemlerinde oluşabilecek hatalar
enum SupabaseServiceError: LocalizedError {
    // MARK: - Auth Errors
    case notAuthenticated
    case sessionExpired
    case invalidCredentials
    case emailNotVerified
    case accountDisabled
    
    // MARK: - Network Errors
    case noConnection
    case timeout
    case serverError(Int)
    case rateLimited
    
    // MARK: - Database Errors
    case recordNotFound
    case duplicateRecord
    case foreignKeyViolation
    case validationFailed(String)
    case permissionDenied
    
    // MARK: - Storage Errors
    case uploadFailed(String)
    case downloadFailed(String)
    case fileTooLarge(Int)
    case invalidFileType(String)
    case bucketNotFound
    
    // MARK: - Sync Errors
    case conflictDetected
    case syncInProgress
    case mergeConflict(local: Any, remote: Any)
    case versionMismatch
    
    // MARK: - General Errors
    case unknown(Error)
    case decodingFailed(String)
    case encodingFailed(String)
    
    // MARK: - Error Description
    
    var errorDescription: String? {
        switch self {
        // Auth
        case .notAuthenticated:
            return "Oturum açmanız gerekiyor"
        case .sessionExpired:
            return "Oturumunuz sona erdi, lütfen tekrar giriş yapın"
        case .invalidCredentials:
            return "Email veya şifre hatalı"
        case .emailNotVerified:
            return "Lütfen email adresinizi doğrulayın"
        case .accountDisabled:
            return "Hesabınız devre dışı bırakılmış"
            
        // Network
        case .noConnection:
            return "İnternet bağlantısı yok"
        case .timeout:
            return "Bağlantı zaman aşımına uğradı"
        case .serverError(let code):
            return "Sunucu hatası (\(code))"
        case .rateLimited:
            return "Çok fazla istek. Lütfen bekleyin"
            
        // Database
        case .recordNotFound:
            return "Kayıt bulunamadı"
        case .duplicateRecord:
            return "Bu kayıt zaten mevcut"
        case .foreignKeyViolation:
            return "İlişkili kayıt bulunamadı"
        case .validationFailed(let field):
            return "Doğrulama hatası: \(field)"
        case .permissionDenied:
            return "Bu işlem için yetkiniz yok"
            
        // Storage
        case .uploadFailed(let reason):
            return "Yükleme başarısız: \(reason)"
        case .downloadFailed(let reason):
            return "İndirme başarısız: \(reason)"
        case .fileTooLarge(let maxMB):
            return "Dosya çok büyük (max \(maxMB)MB)"
        case .invalidFileType(let type):
            return "Geçersiz dosya türü: \(type)"
        case .bucketNotFound:
            return "Storage bucket bulunamadı"
            
        // Sync
        case .conflictDetected:
            return "Veri çakışması tespit edildi"
        case .syncInProgress:
            return "Senkronizasyon devam ediyor"
        case .mergeConflict:
            return "Birleştirme çakışması"
        case .versionMismatch:
            return "Versiyon uyuşmazlığı"
            
        // General
        case .unknown(let error):
            return "Beklenmeyen hata: \(error.localizedDescription)"
        case .decodingFailed(let type):
            return "Veri okunamadı: \(type)"
        case .encodingFailed(let type):
            return "Veri yazılamadı: \(type)"
        }
    }
    
    // MARK: - Recovery Suggestion
    
    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated, .sessionExpired:
            return "Ayarlar'dan tekrar giriş yapın"
        case .noConnection:
            return "İnternet bağlantınızı kontrol edin"
        case .timeout:
            return "Daha sonra tekrar deneyin"
        case .rateLimited:
            return "Birkaç dakika bekleyip tekrar deneyin"
        case .conflictDetected, .mergeConflict:
            return "Çakışan değişikliklerden birini seçin"
        case .fileTooLarge:
            return "Daha küçük bir dosya seçin"
        default:
            return nil
        }
    }
    
    // MARK: - Is Retryable
    
    /// Bu hata yeniden denenebilir mi?
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .serverError, .rateLimited, .syncInProgress:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Should Show Alert
    
    /// Kullanıcıya alert gösterilmeli mi?
    var shouldShowAlert: Bool {
        switch self {
        case .noConnection, .syncInProgress:
            return false // Sessizce handle et
        default:
            return true
        }
    }
}

// MARK: - Error Mapping

extension SupabaseServiceError {
    
    /// Genel Error'dan SupabaseServiceError'a dönüştür
    static func map(_ error: Error) -> SupabaseServiceError {
        // URLSession errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .noConnection
            case .timedOut:
                return .timeout
            default:
                return .unknown(error)
            }
        }
        
        // Postgrest errors
        let nsError = error as NSError
        
        // HTTP status codes
        if let statusCode = nsError.userInfo["statusCode"] as? Int {
            switch statusCode {
            case 401:
                return .notAuthenticated
            case 403:
                return .permissionDenied
            case 404:
                return .recordNotFound
            case 409:
                return .duplicateRecord
            case 422:
                return .validationFailed(nsError.localizedDescription)
            case 429:
                return .rateLimited
            case 500...599:
                return .serverError(statusCode)
            default:
                break
            }
        }
        
        // Postgrest error codes
        if let code = nsError.userInfo["code"] as? String {
            switch code {
            case "PGRST116": // Not found
                return .recordNotFound
            case "23505": // Unique violation
                return .duplicateRecord
            case "23503": // Foreign key violation
                return .foreignKeyViolation
            case "42501": // Permission denied
                return .permissionDenied
            default:
                break
            }
        }
        
        return .unknown(error)
    }
}

// MARK: - Result Extension

extension Result where Failure == Error {
    /// SupabaseServiceError olarak map et
    var supabaseError: SupabaseServiceError? {
        if case .failure(let error) = self {
            return SupabaseServiceError.map(error)
        }
        return nil
    }
}