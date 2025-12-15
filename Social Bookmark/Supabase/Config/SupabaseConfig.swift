//
//  SupabaseConfig.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//


//
//  SupabaseConfig.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//

import Foundation

/// Supabase yapılandırma yöneticisi
/// Info.plist veya Environment'dan credentials okur
/// 
/// Kullanım:
/// 1. Info.plist'e SUPABASE_URL ve SUPABASE_ANON_KEY ekle
/// 2. Veya xcconfig dosyası kullan (önerilen - güvenlik için)
enum SupabaseConfig {
    
    // MARK: - Keys
    
    private enum Keys {
        static let url = "SUPABASE_URL"
        static let anonKey = "SUPABASE_ANON_KEY"
        static let serviceRoleKey = "SUPABASE_SERVICE_ROLE_KEY" // Sadece backend için
    }
    
    // MARK: - Public Properties
    
    /// Supabase proje URL'i
    /// Format: https://xxxxx.supabase.co
    static var url: URL {
        guard let urlString = value(for: Keys.url),
              let url = URL(string: urlString) else {
            fatalError("""
                ❌ SUPABASE_URL bulunamadı!
                
                Çözüm:
                1. Info.plist'e SUPABASE_URL key'i ekleyin
                2. Değer: https://your-project.supabase.co
                
                Veya SupabaseSecrets.xcconfig dosyası oluşturun:
                SUPABASE_URL = https://your-project.supabase.co
                """)
        }
        return url
    }
    
    /// Supabase anonymous key (client-side kullanım için)
    /// Bu key RLS (Row Level Security) ile korunur
    static var anonKey: String {
        guard let key = value(for: Keys.anonKey), !key.isEmpty else {
            fatalError("""
                ❌ SUPABASE_ANON_KEY bulunamadı!
                
                Çözüm:
                1. Supabase Dashboard > Settings > API
                2. "anon public" key'i kopyalayın
                3. Info.plist veya xcconfig'e ekleyin
                """)
        }
        return key
    }
    
    /// Service role key (opsiyonel - sadece admin işlemleri için)
    static var serviceRoleKey: String? {
        value(for: Keys.serviceRoleKey)
    }
    
    // MARK: - Configuration Options
    
    /// Auth ayarları
    enum Auth {
        /// Oturum süresi (saniye) - varsayılan 1 hafta
        static let sessionExpiry: TimeInterval = 60 * 60 * 24 * 7
        
        /// Token yenileme eşiği (saniye) - 5 dakika kala yenile
        static let refreshThreshold: TimeInterval = 60 * 5
        
        /// Otomatik token yenileme
        static let autoRefreshToken: Bool = true
        
        /// Session'ı Keychain'de sakla
        static let persistSession: Bool = true
    }
    
    /// Storage ayarları
    enum Storage {
        /// Bookmark görselleri bucket'ı
        static let bookmarkImagesBucket = "bookmark-images"
        
        /// Maksimum dosya boyutu (5MB)
        static let maxFileSize: Int = 5 * 1024 * 1024
        
        /// İzin verilen MIME tipleri
        static let allowedMimeTypes = ["image/jpeg", "image/png", "image/webp"]
        
        /// Thumbnail boyutu
        static let thumbnailSize: CGSize = CGSize(width: 200, height: 200)
    }
    
    /// Sync ayarları
    enum Sync {
        /// Otomatik sync aralığı (saniye) - 5 dakika
        static let autoSyncInterval: TimeInterval = 60 * 5
        
        /// Batch upload limiti
        static let batchSize: Int = 50
        
        /// Retry sayısı
        static let maxRetries: Int = 3
        
        /// Retry delay (saniye)
        static let retryDelay: TimeInterval = 2.0
        
        /// Offline queue maksimum boyutu
        static let maxQueueSize: Int = 1000
    }
    
    /// Database tablo isimleri
    enum Tables {
        static let bookmarks = "bookmarks"
        static let categories = "categories"
        static let syncStatus = "sync_status"
        static let userProfiles = "user_profiles"
    }
    
    // MARK: - Environment
    
    /// Mevcut ortam
    static var environment: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    enum Environment: String {
        case development
        case staging
        case production
        
        var isDebugLoggingEnabled: Bool {
            self != .production
        }
    }
    
    // MARK: - Validation
    
    /// Yapılandırmanın geçerli olup olmadığını kontrol et
    static func validate() -> ConfigurationStatus {
        var issues: [String] = []
        
        // URL kontrolü
        if value(for: Keys.url) == nil {
            issues.append("SUPABASE_URL eksik")
        } else if !url.absoluteString.contains("supabase.co") {
            issues.append("SUPABASE_URL geçersiz format")
        }
        
        // Key kontrolü
        if value(for: Keys.anonKey) == nil {
            issues.append("SUPABASE_ANON_KEY eksik")
        } else if anonKey.count < 100 {
            issues.append("SUPABASE_ANON_KEY çok kısa - geçersiz olabilir")
        }
        
        if issues.isEmpty {
            return .valid
        } else {
            return .invalid(issues)
        }
    }
    
    enum ConfigurationStatus {
        case valid
        case invalid([String])
        
        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    /// Değeri Info.plist veya Environment'dan oku
    private static func value(for key: String) -> String? {
        // 1. Önce Info.plist'e bak
        if let infoPlistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !infoPlistValue.isEmpty,
           !infoPlistValue.hasPrefix("$(") { // xcconfig placeholder değilse
            return infoPlistValue
        }
        
        // 2. Environment variable'a bak
        if let envValue = ProcessInfo.processInfo.environment[key],
           !envValue.isEmpty {
            return envValue
        }
        
        return nil
    }
}

// MARK: - Debug Description

extension SupabaseConfig {
    /// Debug için yapılandırma özeti
    static var debugDescription: String {
        """
        ╔══════════════════════════════════════════════════════════╗
        ║                 SUPABASE CONFIGURATION                   ║
        ╠══════════════════════════════════════════════════════════╣
        ║ Environment: \(environment.rawValue.padding(toLength: 42, withPad: " ", startingAt: 0))║
        ║ URL: \(url.absoluteString.prefix(49).padding(toLength: 49, withPad: " ", startingAt: 0))║
        ║ Anon Key: \(String(anonKey.prefix(20)))...\(String(anonKey.suffix(10)).padding(toLength: 32, withPad: " ", startingAt: 0))║
        ║ Status: \(validate().isValid ? "✅ Valid" : "❌ Invalid").padding(toLength: 46, withPad: " ", startingAt: 0))║
        ╚══════════════════════════════════════════════════════════╝
        """
    }
}