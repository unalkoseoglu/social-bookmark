//
//  RandomNameGenerator.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 19.12.2025.
//


//
//  RandomNameGenerator.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 19.12.2025.
//

import Foundation

/// Anonim kullanıcılar için rastgele isimler üretir
/// Format: "user_7F3A9C" (6 karakterli hex string)
enum RandomNameGenerator {
    
    /// Rastgele bir kullanıcı adı üret
    /// Format: "user_XXXXXX" (6 karakterli hex)
    /// Örnek: "user_7F3A9C", "user_B2E4D1"
    static func generate() -> String {
        let hexString = generateHexString(length: 6)
        return "user_\(hexString)"
    }
    
    /// Belirtilen uzunlukta rastgele hex string üret
    /// - Parameter length: Karakter sayısı
    /// - Returns: Büyük harfli hex string (örn: "7F3A9C")
    private static func generateHexString(length: Int) -> String {
        let characters = "0123456789ABCDEF"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
    
    /// UUID'den kısa bir isim türet
    /// Kullanıcının UUID'sinden tutarlı bir isim oluşturur
    /// - Parameter uuid: Kullanıcı UUID'si
    /// - Returns: "user_" + UUID'nin ilk 6 hex karakteri
    static func generate(from uuid: UUID) -> String {
        let uuidString = uuid.uuidString.replacingOccurrences(of: "-", with: "")
        let prefix = String(uuidString.prefix(6))
        return "user_\(prefix)"
    }
    
    /// Özelleştirilmiş prefix ile isim üret
    /// - Parameter prefix: İsim öneki (örn: "guest", "anon")
    /// - Returns: Formatlanmış isim (örn: "guest_7F3A9C")
    static func generate(withPrefix prefix: String) -> String {
        let hexString = generateHexString(length: 6)
        return "\(prefix)_\(hexString)"
    }
}
