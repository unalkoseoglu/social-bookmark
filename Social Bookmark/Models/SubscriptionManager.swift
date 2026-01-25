//
//  SubscriptionManager.swift
//  Social Bookmark
//
//  Created by Social Bookmark App on 24.01.2026.
//

import Foundation
import RevenueCat
import SwiftUI
internal import Combine

/// IAP ve Abonelik durumunu yöneten Singleton
@MainActor
final class SubscriptionManager: NSObject, ObservableObject {
    
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    
    /// Kullanıcı Premium mu?
    @Published var isPro: Bool = false
    
    /// Mevcut satın alma paketleri
    @Published var packages: [Package] = []
    
    /// Yükleniyor mu?
    @Published var isLoading: Bool = false
    
    /// Hata mesajı
    @Published var errorMessage: String?
    
    // MARK: - Configuration
    
    // ⚠️ TODO: RevenueCat Dashboard'dan alacağınız Public API Key'i buraya yapıştırın
    private let apiKey = "appl_REVENUECAT_PUBLIC_API_KEY_HERE"
    
    
    override private init() {
        super.init()
        // Singleton
    }
    
    // MARK: - Setup
    
    private var isConfigured = false
    
    func configure() {
        guard !isConfigured else { return }
        
        Purchases.logLevel = .debug
        
        // App Group desteği için UserDefaults yapılandırması
        let userDefaults = UserDefaults(suiteName: "group.com.unal.socialbookmark") ?? .standard
        
        let configuration = Configuration.Builder(withAPIKey: apiKey)
            .with(userDefaults: userDefaults)
            .build()
            
        Purchases.configure(with: configuration)
        
        // Dinleyiciyi başlat
        Purchases.shared.delegate = self
        
        // Mevcut durumu kontrol et
        checkSubscriptionStatus()
        
        // Paketleri getir
        fetchOfferings()
        
        isConfigured = true
    }
    
    // MARK: - Fetching
    
    func fetchOfferings() {
        isLoading = true
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                print("❌ [IAP] Error fetching offerings: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                return
            }
            
            if let current = offerings?.current {
                self.packages = current.availablePackages
                print("✅ [IAP] Fetched \(self.packages.count) packages")
            }
        }
    }
    
    func checkSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { [weak self] (info, error) in
            guard let self = self else { return }
            
            if let info = info {
                self.updateProStatus(from: info)
            }
        }
    }
    
    // MARK: - Actions
    
    func purchase(package: Package) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            isLoading = false
            
            if !result.userCancelled {
                updateProStatus(from: result.customerInfo)
                return true
            } else {
                return false
            }
        } catch {
            isLoading = false
            print("❌ [IAP] Purchase failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let info = try await Purchases.shared.restorePurchases()
            isLoading = false
            updateProStatus(from: info)
            return isPro
        } catch {
            isLoading = false
            print("❌ [IAP] Restore failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Helpers
    
    private func updateProStatus(from customerInfo: CustomerInfo) {
        // "pro" entitlement tanımladığınızdan emin olun (RevenueCat Dashboard'da)
        if customerInfo.entitlements["pro"]?.isActive == true {
            print("✅ [IAP] User is PRO")
            self.isPro = true
        } else {
            print("ℹ️ [IAP] User is FREE")
            self.isPro = false
        }
    }
}

// MARK: - Delegate

extension SubscriptionManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        updateProStatus(from: customerInfo)
    }
}
