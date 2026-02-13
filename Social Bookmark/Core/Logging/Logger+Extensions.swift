
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.app"
    
    /// Authentication related logs
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    
    /// Keychain operations
    static let keychain = Logger(subsystem: subsystem, category: "Keychain")
    
    /// App lifecycle logs
    static let app = Logger(subsystem: subsystem, category: "App")
    
    /// Sync operations
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    
    /// Network operations
    static let network = Logger(subsystem: subsystem, category: "Network")
    
    /// Repository operations
    static let repository = Logger(subsystem: subsystem, category: "Repository")
    
    /// Share Extension logs
    static let share = Logger(subsystem: subsystem, category: "ShareExtension")
}
