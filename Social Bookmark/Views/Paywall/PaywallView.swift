import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) var dismiss
    
    /// Paywall'ın gösterilme nedeni (örn: "Bookmark sınırı doldu")
    var reason: String?
    
    var body: some View {
        if sessionStore.isAuthenticated && !sessionStore.isAnonymous {
            // Kullanıcı login ise Paywall'ı göster
            RevenueCatUI.PaywallView(displayCloseButton: true)
                .onPurchaseCompleted { customerInfo in
                    print("✅ Satın alma tamamlandı: \(customerInfo.entitlements.active.keys)")
                    // 🔄 Hemen SubscriptionManager'ı güncelle
                    SubscriptionManager.shared.checkSubscriptionStatus()
                    dismiss()
                }
                .onRestoreCompleted { customerInfo in
                    // 🔄 Hemen SubscriptionManager'ı güncelle
                    SubscriptionManager.shared.checkSubscriptionStatus()
                    if SubscriptionManager.shared.isPro {
                        dismiss()
                    }
                }
        } else {
            // Kullanıcı login değilse Login ekranını göster
            SignInView(isPresented: true, isFromPaywall: true, reason: reason)
        }
    }
}
