//
//  Social_BookmarkApp+OneSignal.swift
//  Social Bookmark
//
//  Created by Antigravity on 31.01.2026.
//

import Foundation
import OneSignalFramework
import OSLog

extension Social_BookmarkApp {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SocialBookmark", category: "OneSignal")
    
    /// OneSignal SDK'sını başlat
    /// init() içinde çağrılmalı
    func initializeOneSignal(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        do {
            let appID = try AppConfig.onesignalAppID
            
            // Log level set et
            OneSignal.Debug.setLogLevel(.LL_WARN)
            
            // SDK'yı başlat
            OneSignal.initialize(appID, withLaunchOptions: launchOptions)
            
            // Notification permission prompt (Opsiyonel: Burada değil, onboarding veya özel bir butonda çağırmak daha iyidir)
            // OneSignal.Notifications.requestPermission({ accepted in
            //    print("User accepted notifications: \(accepted)")
            // }, fallbackToSettings: true)
            
            Self.logger.info("✅ OneSignal initialized successfully")
            
        } catch {
            Self.logger.error("❌ OneSignal initialization failed: \(error.localizedDescription)")
            // App ID eksikse uygulama çökmesin diye fatalError atmıyoruz (Production'da kritik olabilir ama runtime'da config hatası uyarısı verir)
        }
    }
}
