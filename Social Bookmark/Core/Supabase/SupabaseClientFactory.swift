//
//  SupabaseClientFactory.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//


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
            
            
            Logger.supabase.info("Supabase client initialized successfully")
            return SupabaseManager.shared.client
            
        } catch {
            Logger.supabase.fault("Failed to initialize Supabase client: \(error.localizedDescription)")
            fatalError("Supabase configuration error: \(error.localizedDescription)")
        }
    }()
}


