//
//  AppLanguage.swift
//  Social Bookmark
//
//  Uygulama dil seçenekleri
//

import SwiftUI

/// Uygulama dil seçenekleri
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case turkish = "tr"
    case english = "en"

    static let storageKey = "selectedLanguage"

    var id: String { rawValue }

    /// Dil için kullanıcıya gösterilecek başlık (localized değil - sabit)
    /// Bu şekilde dil seçenekleri her zaman doğru dilde görünür
    var displayName: String {
        switch self {
        case .system:
            return "🌐 System"
        case .turkish:
            return "🇹🇷 Türkçe"
        case .english:
            return "🇬🇧 English"
        }
    }
    
    /// Dil için kullanıcıya gösterilecek başlık (LocalizedStringKey)
    var titleKey: LocalizedStringKey {
        switch self {
        case .system:
            return "settings.language.system"
        case .turkish:
            return "settings.language.turkish"
        case .english:
            return "settings.language.english"
        }
    }

    /// Dil seçiminin açıklaması
    var descriptionKey: LocalizedStringKey {
        switch self {
        case .system:
            return "settings.language.system_desc"
        case .turkish:
            return "settings.language.turkish_desc"
        case .english:
            return "settings.language.english_desc"
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
    
    /// Dil kodu
    var languageCode: String? {
        switch self {
        case .system:
            return nil
        case .turkish:
            return "tr"
        case .english:
            return "en"
        }
    }
}
