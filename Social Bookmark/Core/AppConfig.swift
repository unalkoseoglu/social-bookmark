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
    
    /// OneSignal App ID
    static var onesignalAppID: String {
        get throws {
            guard let key = Bundle.main.object(forInfoDictionaryKey: "ONESIGNAL_APP_ID") as? String,
                  !key.isEmpty,
                  !key.contains("YOUR_ONESIGNAL") else {
                logger.error("ONESIGNAL_APP_ID not configured in Info.plist")
                throw ConfigError.missingKey("ONESIGNAL_APP_ID")
            }
            
            return key
        }
    }
}
