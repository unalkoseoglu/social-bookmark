// Core/Supabase/SupabaseClientFactory.swift

import Foundation
import Supabase
import OSLog

/// Factory for creating and configuring the Supabase client
enum SupabaseClientFactory {
    
    /// Shared Supabase client instance
    /// Uses a custom localStorage that persists to Keychain
    static let shared: SupabaseClient = {
        do {
            let url = try AppConfig.supabaseURL
            let key = try AppConfig.supabaseAnonKey
            
            let client = SupabaseClient(
                supabaseURL: url,
                supabaseKey: key,
                options: SupabaseClientOptions(
                    auth: SupabaseClientOptions.AuthOptions(
                        storage: SupabaseKeychain(),
                        autoRefreshToken: true,
                        detectSessionInUrl: true,
                        flowType: .pkce
                    )
                )
            )
            
            Logger.supabase.info("Supabase client initialized successfully")
            return client
            
        } catch {
            Logger.supabase.fault("Failed to initialize Supabase client: \(error.localizedDescription)")
            fatalError("Supabase configuration error: \(error.localizedDescription)")
        }
    }()
}

/// Custom AuthLocalStorage that uses Keychain for secure session storage
final class SupabaseKeychain: AuthLocalStorage, @unchecked Sendable {
    
    private let storage: KeychainSessionStorage
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init(storage: KeychainSessionStorage = KeychainSessionStorage()) {
        self.storage = storage
    }
    
    func store(key: String, value: Data) throws {
        try storage.store(value, forKey: key)
    }
    
    func retrieve(key: String) throws -> Data? {
        try storage.retrieve(forKey: key)
    }
    
    func remove(key: String) throws {
        try storage.delete(forKey: key)
    }
}