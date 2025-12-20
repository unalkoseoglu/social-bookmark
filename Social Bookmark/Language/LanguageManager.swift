//
//  LanguageManager.swift
//  Social Bookmark
//
//  Runtime'da dil değişikliği için
//

import Foundation
import SwiftUI
internal import Combine

// MARK: - Language Manager

/// Uygulama dilini runtime'da değiştirmek için manager
final class LanguageManager: ObservableObject {

    
    
    // MARK: - Singleton
    
    static let shared = LanguageManager()
    
    // MARK: - Published Properties
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            if oldValue != currentLanguage {
                applyLanguage(currentLanguage)
            }
        }
    }
    
    /// Dil değişikliğini tetiklemek için kullanılan ID
    @Published var refreshID = UUID()
    
    /// Dil değişti mi flag'i - alert göstermek için
    @Published var languageJustChanged = false
    
    // MARK: - Private Properties
    
    private var currentBundle: Bundle?
    
    // MARK: - Initialization
    
    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        let language = AppLanguage(rawValue: savedLanguage ?? "") ?? .system
        self.currentLanguage = language
        self.currentBundle = Self.loadBundle(for: language)
    }
    
    // MARK: - Public Methods
    
    /// Localized string al
    func localized(_ key: String) -> String {
        let bundle = currentBundle ?? Bundle.main
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    /// Localized string al (format ile)
    func localized(_ key: String, _ args: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, arguments: args)
    }
    
    /// Uygulamayı yeniden başlat (exit)
    func restartApp() {
        // Kısa bir gecikme ile çık
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }
    
    // MARK: - Private Methods
    
    private static func loadBundle(for language: AppLanguage) -> Bundle? {
        let languageCode: String
        
        switch language {
        case .system:
            guard let preferredLanguage = Locale.preferredLanguages.first else {
                return nil
            }
            languageCode = String(preferredLanguage.prefix(2))
        case .turkish:
            languageCode = "tr"
        case .english:
            languageCode = "en"
        }
        
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        
        return nil
    }
    
    private func applyLanguage(_ language: AppLanguage) {
        // Bundle'ı güncelle
        currentBundle = Self.loadBundle(for: language)
        
        // UserDefaults'a kaydet
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        
        // AppleLanguages'ı da set et
        if let code = language.languageCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        
        UserDefaults.standard.synchronize()
        
        // Flag'i set et
        DispatchQueue.main.async { [weak self] in
            self?.refreshID = UUID()
            self?.languageJustChanged = true
        }
        
        print("🌍 Language changed to: \(language.displayName)")
    }
}
