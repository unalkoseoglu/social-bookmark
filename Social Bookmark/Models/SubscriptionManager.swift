import Foundation
import RevenueCat
import SwiftUI
import Combine

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
        // Note: Observer will be set up after SessionStore is available or via periodic checks
    }
    
    func setupObservers(sessionStore: SessionStore) {
        sessionStore.$userProfile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let self = self else { return }
                let newProStatus = profile?.isPro ?? false
                if self.isPro != newProStatus {
                    print("🔄 [IAP] Profile Sync - IS_PRO: \(newProStatus)")
                    self.isPro = newProStatus
                    
                    // Persist to App Group immediately so extensions can see it
                    if let defaults = UserDefaults(suiteName: APIConstants.appGroupId) {
                        defaults.set(self.isPro, forKey: "isProUser")
                    }
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
    
    /// `shouldFetch`: Paketleri ve durumu hemen çeksin mi? (Extension'lar için false tercih edilebilir)
    func configure(shouldFetch: Bool = true) {
        guard !isConfigured else { return }
        
        Purchases.logLevel = .info
        
        let userDefaults = UserDefaults(suiteName: "group.com.unal.socialbookmark") ?? .standard
        
        let configuration = Configuration.Builder(withAPIKey: apiKey)
            .with(userDefaults: userDefaults)
            .build()
            
        Purchases.configure(with: configuration)
        if shouldFetch {
            Purchases.shared.delegate = self
            checkSubscriptionStatus()
            fetchOfferings()
        } else {
            // Extension modunda cache'den oku
            if let defaults = UserDefaults(suiteName: APIConstants.appGroupId) {
                self.isPro = defaults.bool(forKey: "isProUser")
                print("📱 [IAP] Extension mode: Initial Pro status loaded from App Group: \(self.isPro)")
            }
        }
        
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
            
            if let offerings = offerings {
                if let current = offerings.current {
                    self.packages = current.availablePackages
                    print("✅ [IAP] Fetched \(self.packages.count) packages")
                }
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
        
        let proActive = customerInfo.entitlements["pro"]?.isActive == true || 
                        customerInfo.entitlements["premium"]?.isActive == true ||
                        customerInfo.entitlements["all_features"]?.isActive == true ||
                        customerInfo.entitlements["com.unal.Social-Bookmark"]?.isActive == true
        
        DispatchQueue.main.async {
            // Extension modundaysak ve yeni durum FREE ise,
            // ana uygulamadan gelen PRO durumunu ezmemek için güncellemeyi atla.
            let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
            if isExtension && !proActive && self.isPro {
                print("⚠️ [IAP] Extension mode: Ignoring FREE update from RevenueCat to keep existing PRO status.")
                return
            }
            
            self.isPro = proActive
            
            if proActive {
                print("✅ [IAP] User status updated to: PRO (via RevenueCat)")
                // Server'ı güncelle (opsiyonel)
                Task { try? await AuthService.shared.updateProStatus(isPro: true) }
            } else {
                print("ℹ️ [IAP] User status updated to: FREE")
            }
            
            // App Group'a kaydet (Share Extension için)
            if let defaults = UserDefaults(suiteName: APIConstants.appGroupId) {
                defaults.set(self.isPro, forKey: "isProUser")
                print("💾 [IAP] Pro status synced to App Group: \(self.isPro ? "PRO" : "FREE")")
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
