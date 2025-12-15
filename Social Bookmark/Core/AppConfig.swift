// Config/AppConfig.swift

import Foundation
import OSLog

/// Reads configuration values from Info.plist (populated via xcconfig)
enum AppConfig {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "App", category: "AppConfig")
    
    enum ConfigError: Error, LocalizedError {
        case missingKey(String)
        case invalidValue(String)
        
        var errorDescription: String? {
            switch self {
            case .missingKey(let key):
                return "Missing configuration key: \(key)"
            case .invalidValue(let key):
                return "Invalid value for configuration key: \(key)"
            }
        }
    }
    
    /// Supabase project URL
    static var supabaseURL: URL {
        get throws {
            guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
                  !urlString.isEmpty,
                  !urlString.contains("YOUR_PROJECT") else {
                logger.error("SUPABASE_URL not configured in Info.plist")
                throw ConfigError.missingKey("SUPABASE_URL")
            }
            
            guard let url = URL(string: urlString) else {
                logger.error("SUPABASE_URL is not a valid URL: \(urlString)")
                throw ConfigError.invalidValue("SUPABASE_URL")
            }
            
            return url
        }
    }
    
    /// Supabase anonymous key
    static var supabaseAnonKey: String {
        get throws {
            guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
                  !key.isEmpty,
                  !key.contains("YOUR_ANON") else {
                logger.error("SUPABASE_ANON_KEY not configured in Info.plist")
                throw ConfigError.missingKey("SUPABASE_ANON_KEY")
            }
            
            return key
        }
    }
}
