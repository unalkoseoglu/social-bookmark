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
    
    
    /// RevenueCat API Key (Info.plist üzerinden alınır)
    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? ""
    }
    private var cancellables = Set<AnyCancellable>()
    
    override private init() {
        super.init()
        setupSupabaseObserver()
    }
    
    private func setupSupabaseObserver() {
        SupabaseManager.shared.$userProfile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let self = self else { return }
                let newProStatus = profile?.is_pro ?? false
                if self.isPro != newProStatus {
                    print("🔄 [IAP] Supabase Profile Sync - IS_PRO: \(newProStatus)")
                    self.isPro = newProStatus
                }
            }
            .store(in: &cancellables)
    }
    
    /// Oturum kapatıldığında durumu sıfırla
    func reset() {
        print("🧹 [IAP] Resetting subscription status...")
        isPro = false
        errorMessage = nil
        isLoading = false
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
                print("   - Error Code: \(error._code)")
                print("   - Underlying Error: \(String(describing: error.userInfo))")
                self.errorMessage = error.localizedDescription
                return
            }
            
            if let offerings = offerings {
                if let current = offerings.current {
                    self.packages = current.availablePackages
                    print("✅ [IAP] Fetched \(self.packages.count) packages from CURRENT offering: \(current.identifier)")
                } else {
                    print("⚠️ [IAP] No 'current' offering found. Available offerings: \(offerings.all.keys)")
                    self.errorMessage = "RevenueCat Dashboard'da bir 'Offering' oluşturduğunuzdan ve bunu 'Current' (aktif) olarak işaretlediğinizden emin olun."
                }
            } else {
                print("⚠️ [IAP] Offerings object is nil")
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
        let activeEntitlements = customerInfo.entitlements.active.keys
        print("📦 [IAP] Active Entitlements: \(activeEntitlements)")
        
        // "pro" veya "premium" gibi yaygın isimleri kontrol edelim
        // ⚠️ En doğrusu Dashboard'daki ID ile tam eşleşmedir
        // RevenueCat Entitlement ID'leri
        let proActive = customerInfo.entitlements["pro"]?.isActive == true || 
                        customerInfo.entitlements["premium"]?.isActive == true ||
                        customerInfo.entitlements["all_features"]?.isActive == true ||
                        customerInfo.entitlements["com.unal.Social-Bookmark"]?.isActive == true
        
        DispatchQueue.main.async {
            if proActive {
                print("✅ [IAP] User status updated to: PRO (via RevenueCat)")
                self.isPro = true
                
                // ✅ Supabase'i de güncelle (Webhook yedeği olarak)
                Task {
                    await SupabaseManager.shared.updateProStatus(isPro: true)
                }
            } else {
                // Eğer RevenueCat FREE diyorsa, Supabase'e son bir kez daha soralım
                let supabasePro = SupabaseManager.shared.userProfile?.is_pro == true
                if supabasePro {
                    print("🔄 [IAP] RevenueCat says FREE, but Supabase says PRO. Keeping PRO status.")
                    self.isPro = true
                } else {
                    print("ℹ️ [IAP] User status updated to: FREE")
                    self.isPro = false
                }
            }
        }
    }
}

// MARK: - Delegate

extension SubscriptionManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        updateProStatus(from: customerInfo)
    }
}
