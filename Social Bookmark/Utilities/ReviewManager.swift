//
//  ReviewManager.swift
//  Social Bookmark
//
//  Created by Antigravity on 26.01.2026.
//

import Foundation
import StoreKit
import SwiftUI

class ReviewManager {
    static let shared = ReviewManager()
    
    private let launchCountKey = "app_launch_count"
    private let lastVersionReviewedKey = "last_version_reviewed"
    
    private init() {}
    
    /// Uygulama açılışını kaydeder ve gerekirse review ister
    func logLaunch() {
        var count = UserDefaults.standard.integer(forKey: launchCountKey)
        count += 1
        UserDefaults.standard.set(count, forKey: launchCountKey)
        
        print("🚀 App Launch Count: \(count)")
        
        // 2. açılışta review iste
        if count == 2 {
            requestReview()
        }
    }
    
    /// Manuel olarak review ister (Ayarlar sayfasından)
    func requestReviewManually() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
    
    /// Otomatik review isteği (Apple'ın kısıtlamalarına tabidir)
    private func requestReview() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastVersionReviewedKey) ?? ""
        
        // Aynı versiyon için tekrar sormaması için kontrol (opsiyonel ama iyi bir pratik)
        guard currentVersion != lastVersion else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
                UserDefaults.standard.set(currentVersion, forKey: self.lastVersionReviewedKey)
            }
        }
    }
}
