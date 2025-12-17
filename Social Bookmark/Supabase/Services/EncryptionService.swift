//
//  EncryptionService.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 15.12.2025.
//


//
//  EncryptionService.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//
//  End-to-End Encryption (E2EE) Service
//  - Kullanıcı verilerini cihazda şifreler
//  - Sunucuya sadece şifreli veri gönderilir
//  - Admin dahil kimse içeriği okuyamaz
//  - AES-256-GCM encryption
//

import Foundation
import CryptoKit
import Security

/// End-to-End Encryption Service
/// Tüm kullanıcı verileri cihazda şifrelenir, sunucuya şifreli gider
@MainActor
final class EncryptionService: ObservableObject {

    
    
    // MARK: - Singleton
    
    static let shared = EncryptionService()
    
    // MARK: - Properties
    
    /// Encryption key Keychain'de saklanıyor mu?
    @Published private(set) var isKeyAvailable: Bool = false
    
    /// Keychain service identifier
    private let keychainService = "com.unal.socialbookmark.encryption"
    private let keyAccount = "user_encryption_key"
    
    /// Cached symmetric key (memory'de)
    private var cachedKey: SymmetricKey?
    
    // MARK: - Initialization
    
    private init() {
        // Mevcut key'i kontrol et
        isKeyAvailable = retrieveKeyFromKeychain() != nil
    }
    
    // MARK: - Key Management
    
    /// Yeni encryption key oluştur (ilk kurulum veya key reset)
    /// ⚠️ Bu işlem geri alınamaz - eski şifreli veriler okunamaz hale gelir
    func generateNewKey() throws -> SymmetricKey {
        // 256-bit (32 byte) AES key
        let key = SymmetricKey(size: .bits256)
        
        // Keychain'e kaydet
        try storeKeyInKeychain(key)
        
        cachedKey = key
        isKeyAvailable = true
        
        print("🔐 [ENCRYPTION] New encryption key generated and stored")
        return key
    }
    
    /// Mevcut key'i al veya yeni oluştur
    func getOrCreateKey() throws -> SymmetricKey {
        // Cache'de varsa döndür
        if let cached = cachedKey {
            return cached
        }
        
        // Keychain'den al
        if let existingKey = retrieveKeyFromKeychain() {
            cachedKey = existingKey
            return existingKey
        }
        
        // Yoksa yeni oluştur
        return try generateNewKey()
    }
    
    /// Key'i export et (backup için)
    /// Base64 encoded string döndürür
    func exportKey() throws -> String {
        let key = try getOrCreateKey()
        let keyData = key.withUnsafeBytes { Data($0) }
        return keyData.base64EncodedString()
    }
    
    /// Key'i import et (restore için)
    func importKey(base64String: String) throws {
        guard let keyData = Data(base64Encoded: base64String),
              keyData.count == 32 else { // 256 bits = 32 bytes
            throw EncryptionError.invalidKeyFormat
        }
        
        let key = SymmetricKey(data: keyData)
        try storeKeyInKeychain(key)
        cachedKey = key
        isKeyAvailable = true
        
        print("🔐 [ENCRYPTION] Key imported successfully")
    }
    
    /// Key'i sil (logout veya hesap silme)
    func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyAccount
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw EncryptionError.keychainError(status)
        }
        
        cachedKey = nil
        isKeyAvailable = false
        
        print("🔐 [ENCRYPTION] Key deleted")
    }
    
    // MARK: - Encryption Methods
    
    /// String'i şifrele
    func encrypt(_ plaintext: String) throws -> EncryptedData {
        guard let data = plaintext.data(using: .utf8) else {
            throw EncryptionError.encodingFailed
        }
        return try encrypt(data)
    }
    
    /// Data'yı şifrele
    func encrypt(_ plainData: Data) throws -> EncryptedData {
        let key = try getOrCreateKey()
        
        // Random nonce (IV) oluştur
        let nonce = AES.GCM.Nonce()
        
        // AES-256-GCM ile şifrele
        let sealedBox = try AES.GCM.seal(plainData, using: key, nonce: nonce)
        
        // Combined = nonce + ciphertext + tag
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return EncryptedData(
            ciphertext: combined.base64EncodedString(),
            algorithm: "AES-256-GCM"
        )
    }
    
    /// Şifreli string'i çöz
    func decryptString(_ encrypted: EncryptedData) throws -> String {
        let data = try decrypt(encrypted)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncryptionError.decodingFailed
        }
        return string
    }
    
    /// Şifreli data'yı çöz
    func decrypt(_ encrypted: EncryptedData) throws -> Data {
        let key = try getOrCreateKey()
        
        guard let combined = Data(base64Encoded: encrypted.ciphertext) else {
            throw EncryptionError.invalidCiphertext
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        return decryptedData
    }
    
    /// Optional string'i şifrele (nil safe)
    func encryptOptional(_ plaintext: String?) throws -> String? {
        guard let text = plaintext, !text.isEmpty else { return nil }
        let encrypted = try encrypt(text)
        return encrypted.ciphertext
    }
    
    /// Optional şifreli string'i çöz (nil safe)
    func decryptOptional(_ ciphertext: String?) throws -> String? {
        guard let cipher = ciphertext, !cipher.isEmpty else { return nil }
        let encrypted = EncryptedData(ciphertext: cipher, algorithm: "AES-256-GCM")
        return try decryptString(encrypted)
    }
    
    // MARK: - Batch Encryption (for sync)
    
    /// Bookmark payload'ını şifrele
    func encryptBookmarkPayload(_ payload: [String: Any]) throws -> [String: Any] {
        var encrypted = payload
        
        // Şifrelenecek alanlar
        let sensitiveFields = ["title", "url", "note", "extracted_text"]
        
        for field in sensitiveFields {
            if let value = payload[field] as? String, !value.isEmpty {
                let encryptedValue = try encrypt(value)
                encrypted[field] = encryptedValue.ciphertext
            }
        }
        
        // Tags array'ini şifrele
        if let tags = payload["tags"] as? [String] {
            let encryptedTags = try tags.map { try encrypt($0).ciphertext }
            encrypted["tags"] = encryptedTags
        }
        
        // image_urls array'ini şifrele
        if let imageUrls = payload["image_urls"] as? [String] {
            let encryptedUrls = try imageUrls.map { try encrypt($0).ciphertext }
            encrypted["image_urls"] = encryptedUrls
        }
        
        // Encryption flag ekle
        encrypted["is_encrypted"] = true
        
        return encrypted
    }
    
    /// Şifreli bookmark payload'ını çöz
    func decryptBookmarkPayload(_ payload: [String: Any]) throws -> [String: Any] {
        // Şifreli değilse olduğu gibi döndür
        guard payload["is_encrypted"] as? Bool == true else {
            return payload
        }
        
        var decrypted = payload
        
        let sensitiveFields = ["title", "url", "note", "extracted_text"]
        
        for field in sensitiveFields {
            if let ciphertext = payload[field] as? String, !ciphertext.isEmpty {
                decrypted[field] = try decryptOptional(ciphertext)
            }
        }
        
        // Tags
        if let encryptedTags = payload["tags"] as? [String] {
            let decryptedTags = try encryptedTags.compactMap { try decryptOptional($0) }
            decrypted["tags"] = decryptedTags
        }
        
        // image_urls
        if let encryptedUrls = payload["image_urls"] as? [String] {
            let decryptedUrls = try encryptedUrls.compactMap { try decryptOptional($0) }
            decrypted["image_urls"] = decryptedUrls
        }
        
        return decrypted
    }
    
    /// Category payload'ını şifrele
    func encryptCategoryPayload(_ payload: [String: Any]) throws -> [String: Any] {
        var encrypted = payload
        
        // Sadece name şifrelenecek (icon ve color değil)
        if let name = payload["name"] as? String {
            encrypted["name"] = try encrypt(name).ciphertext
        }
        
        encrypted["is_encrypted"] = true
        
        return encrypted
    }
    
    /// Şifreli category payload'ını çöz
    func decryptCategoryPayload(_ payload: [String: Any]) throws -> [String: Any] {
        guard payload["is_encrypted"] as? Bool == true else {
            return payload
        }
        
        var decrypted = payload
        
        if let ciphertext = payload["name"] as? String {
            decrypted["name"] = try decryptOptional(ciphertext)
        }
        
        return decrypted
    }
    
    // MARK: - Private Methods
    
    private func storeKeyInKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Önce mevcut key'i sil
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Yeni key'i ekle
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw EncryptionError.keychainError(status)
        }
    }
    
    private func retrieveKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyAccount,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data,
              keyData.count == 32 else {
            return nil
        }
        
        return SymmetricKey(data: keyData)
    }
}

// MARK: - Types

/// Şifreli veri container'ı
struct EncryptedData: Codable {
    let ciphertext: String
    let algorithm: String
}

/// Encryption hataları
enum EncryptionError: LocalizedError {
    case keyNotFound
    case invalidKeyFormat
    case encodingFailed
    case decodingFailed
    case encryptionFailed
    case decryptionFailed
    case invalidCiphertext
    case keychainError(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .keyNotFound:
            return "Şifreleme anahtarı bulunamadı"
        case .invalidKeyFormat:
            return "Geçersiz anahtar formatı"
        case .encodingFailed:
            return "Veri kodlanamadı"
        case .decodingFailed:
            return "Veri çözümlenemedi"
        case .encryptionFailed:
            return "Şifreleme başarısız"
        case .decryptionFailed:
            return "Şifre çözme başarısız"
        case .invalidCiphertext:
            return "Geçersiz şifreli veri"
        case .keychainError(let status):
            return "Keychain hatası: \(status)"
        }
    }
}

// MARK: - Key Backup View

import SwiftUI
internal import Combine

/// Encryption key backup/restore UI
struct EncryptionKeyBackupView: View {
    @StateObject private var encryptionService = EncryptionService.shared
    
    @State private var exportedKey: String = ""
    @State private var importKey: String = ""
    @State private var showingExportAlert = false
    @State private var showingImportAlert = false
    @State private var showingResetAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        List {
            // Durum
            Section {
                HStack {
                    Label("Şifreleme Durumu", systemImage: "lock.shield")
                    Spacer()
                    Text(encryptionService.isKeyAvailable ? "Aktif" : "Pasif")
                        .foregroundStyle(encryptionService.isKeyAvailable ? .green : .red)
                }
            } header: {
                Text("Durum")
            } footer: {
                Text("Verileriniz cihazınızda şifrelenir. Sunucuda sadece şifreli hali saklanır.")
            }
            
            // Export
            Section {
                Button {
                    exportKey()
                } label: {
                    Label("Anahtarı Dışa Aktar", systemImage: "square.and.arrow.up")
                }
                
                if !exportedKey.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Şifreleme Anahtarınız:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(exportedKey)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Button("Kopyala") {
                            UIPasteboard.general.string = exportedKey
                        }
                        .font(.caption)
                    }
                }
            } header: {
                Text("Yedekleme")
            } footer: {
                Text("⚠️ Bu anahtarı güvenli bir yerde saklayın. Kaybederseniz verilerinize erişemezsiniz.")
            }
            
            // Import
            Section {
                TextField("Anahtar yapıştır...", text: $importKey)
                    .font(.system(.body, design: .monospaced))
                
                Button {
                    importKeyAction()
                } label: {
                    Label("Anahtarı İçe Aktar", systemImage: "square.and.arrow.down")
                }
                .disabled(importKey.isEmpty)
            } header: {
                Text("Geri Yükleme")
            }
            
            // Reset (Danger Zone)
            Section {
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    Label("Anahtarı Sıfırla", systemImage: "trash")
                }
            } header: {
                Text("Tehlikeli Bölge")
            } footer: {
                Text("⚠️ Anahtarı sıfırlarsanız tüm şifreli verileriniz okunamaz hale gelir!")
            }
        }
        .navigationTitle("Şifreleme")
        .alert("Bilgi", isPresented: $showingExportAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("Anahtarı Sıfırla", isPresented: $showingResetAlert) {
            Button("İptal", role: .cancel) { }
            Button("Sıfırla", role: .destructive) {
                resetKey()
            }
        } message: {
            Text("Bu işlem geri alınamaz. Tüm şifreli verileriniz okunamaz hale gelecek.")
        }
    }
    
    private func exportKey() {
        do {
            exportedKey = try encryptionService.exportKey()
        } catch {
            alertMessage = error.localizedDescription
            showingExportAlert = true
        }
    }
    
    private func importKeyAction() {
        do {
            try encryptionService.importKey(base64String: importKey)
            alertMessage = "Anahtar başarıyla içe aktarıldı"
            importKey = ""
        } catch {
            alertMessage = error.localizedDescription
        }
        showingExportAlert = true
    }
    
    private func resetKey() {
        do {
            try encryptionService.deleteKey()
            _ = try encryptionService.generateNewKey()
            exportedKey = ""
        } catch {
            alertMessage = error.localizedDescription
            showingExportAlert = true
        }
    }
}
