import SwiftUI

/// Uygulama dil seçenekleri
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case turkish = "tr"
    case english = "en"

    static let storageKey = "selectedLanguage"

    var id: String { rawValue }

    /// Dil için kullanıcıya gösterilecek başlık
    var titleKey: LocalizedStringKey {
        switch self {
        case .system:
            return "Sistem (Varsayılan)"
        case .turkish:
            return "Türkçe"
        case .english:
            return "İngilizce"
        }
    }

    /// Dil seçiminin açıklaması
    var descriptionKey: LocalizedStringKey {
        switch self {
        case .system:
            return "Cihaz dilini kullanır"
        case .turkish:
            return "Arayüzü Türkçe kullan"
        case .english:
            return "Use the app in English"
        }
    }

    /// Locale karşılığı
    var locale: Locale {
        switch self {
        case .system:
            let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
            return Locale(identifier: identifier)
        case .turkish:
            return Locale(identifier: "tr")
        case .english:
            return Locale(identifier: "en")
        }
    }
}
