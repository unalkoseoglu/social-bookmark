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
    case german = "de"
    case korean = "ko"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case arabic = "ar"

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
        case .german:
            return "🇩🇪 Deutsch"
        case .korean:
            return "🇰🇷 한국어"
        case .simplifiedChinese:
            return "🇨🇳 简体中文"
        case .traditionalChinese:
            return "🇹🇼 繁體中文"
        case .arabic:
            return "🇸🇦 العربية"
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
        case .german:
            return "settings.language.german"
        case .korean:
            return "settings.language.korean"
        case .simplifiedChinese:
            return "settings.language.simplified_chinese"
        case .traditionalChinese:
            return "settings.language.traditional_chinese"
        case .arabic:
            return "settings.language.arabic"
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
        case .german:
            return "settings.language.german_desc"
        case .korean:
            return "settings.language.korean_desc"
        case .simplifiedChinese:
            return "settings.language.simplified_chinese_desc"
        case .traditionalChinese:
            return "settings.language.traditional_chinese_desc"
        case .arabic:
            return "settings.language.arabic_desc"
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
        case .german:
            return Locale(identifier: "de")
        case .korean:
            return Locale(identifier: "ko")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .traditionalChinese:
            return Locale(identifier: "zh-Hant")
        case .arabic:
            return Locale(identifier: "ar")
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
        case .german:
            return "de"
        case .korean:
            return "ko"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        case .arabic:
            return "ar"
        }
    }
}
