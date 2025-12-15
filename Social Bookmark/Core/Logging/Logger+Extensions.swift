
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.app"
    
    /// Authentication related logs
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    
    /// Supabase client logs
    static let supabase = Logger(subsystem: subsystem, category: "Supabase")
    
    /// Keychain operations
    static let keychain = Logger(subsystem: subsystem, category: "Keychain")
}
