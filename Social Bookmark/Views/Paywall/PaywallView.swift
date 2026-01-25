import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    
    /// Paywall'ın gösterilme nedeni (örn: "Bookmark sınırı doldu")
    /// Not: RevenueCat Paywalls'da bu metni dinamik olarak göstermek için 
    /// Dashboard'daki paywall metinlerini kullanabilir veya Footer/Header ekleyebilirsiniz.
    var reason: String?
    
    var body: some View {
        // RevenueCat'in Dashboard'dan yönetilen Paywall bileşeni
        RevenueCatUI.PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { customerInfo in
                print("✅ Satın alma tamamlandı: \(customerInfo.entitlements.active.keys)")
                dismiss()
            }
            .onRestoreCompleted { customerInfo in
                if customerInfo.entitlements["pro"]?.isActive == true {
                    dismiss()
                }
            }
    }
}
