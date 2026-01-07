//
//  EncryptionService.swift - iCloud Keychain Sync Patch
//  Social Bookmark
//
//  Updated: 27.12.2025
//
//  Değişiklikler:
//  - iCloud Keychain sync eklendi (kSecAttrSynchronizable)
//  - Encryption key tüm cihazlarda senkronize olacak
//

import Foundation
import CryptoKit
import Security
import OSLog
internal import Combine

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
    
    nonisolated private init() {
        // Mevcut key'i kontrol et
        // Not: isKeyAvailable MainActor'da olduğu için burada set edilemez
        // İlk kullanımda lazy olarak kontrol edilecek
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
        
        Logger.keychain.info("New encryption key generated and stored")
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
            
            // isKeyAvailable'ı güncelle (MainActor'da)
            Task { @MainActor in
                self.isKeyAvailable = true
            }
            
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
            kSecAttrAccount as String: keyAccount,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny // ✅ Both local and synced
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw EncryptionError.keychainError(status)
        }
        
        cachedKey = nil
        isKeyAvailable = false
        
        print("🔐 [ENCRYPTION] Key deleted")
    }
    
    // MARK: - Encryption Methods (unchanged)
    
    func encrypt(_ plaintext: String) throws -> EncryptedData {
        guard let data = plaintext.data(using: .utf8) else {
            throw EncryptionError.encodingFailed
        }
        return try encrypt(data)
    }
    
    func encrypt(_ plainData: Data) throws -> EncryptedData {
        let key = try getOrCreateKey()
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(plainData, using: key, nonce: nonce)
        
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return EncryptedData(
            ciphertext: combined.base64EncodedString(),
            algorithm: "AES-256-GCM"
        )
    }
    
    func decryptString(_ encrypted: EncryptedData) throws -> String {
        let data = try decrypt(encrypted)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncryptionError.decodingFailed
        }
        return string
    }
    
    func decrypt(_ encrypted: EncryptedData) throws -> Data {
        let key = try getOrCreateKey()
        
        guard let combined = Data(base64Encoded: encrypted.ciphertext) else {
            throw EncryptionError.invalidCiphertext
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        return decryptedData
    }
    
    func encryptOptional(_ plaintext: String?) throws -> String? {
        guard let text = plaintext, !text.isEmpty else { return nil }
        let encrypted = try encrypt(text)
        return encrypted.ciphertext
    }
    
    func decryptOptional(_ ciphertext: String?) throws -> String? {
        guard let cipher = ciphertext, !cipher.isEmpty else { return nil }
        let encrypted = EncryptedData(ciphertext: cipher, algorithm: "AES-256-GCM")
        return try decryptString(encrypted)
    }
    
    // MARK: - Batch Encryption (unchanged)
    
    func encryptBookmarkPayload(_ payload: [String: Any]) throws -> [String: Any] {
        var encrypted = payload
        
        let sensitiveFields = ["title", "url", "note", "extracted_text"]
        
        for field in sensitiveFields {
            if let value = payload[field] as? String, !value.isEmpty {
                let encryptedValue = try encrypt(value)
                encrypted[field] = encryptedValue.ciphertext
            }
        }
        
        if let tags = payload["tags"] as? [String] {
            let encryptedTags = try tags.map { try encrypt($0).ciphertext }
            encrypted["tags"] = encryptedTags
        }
        
        if let imageUrls = payload["image_urls"] as? [String] {
            let encryptedUrls = try imageUrls.map { try encrypt($0).ciphertext }
            encrypted["image_urls"] = encryptedUrls
        }
        
        encrypted["is_encrypted"] = true
        
        return encrypted
    }
    
    func decryptBookmarkPayload(_ payload: [String: Any]) throws -> [String: Any] {
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
        
        if let encryptedTags = payload["tags"] as? [String] {
            let decryptedTags = try encryptedTags.compactMap { try decryptOptional($0) }
            decrypted["tags"] = decryptedTags
        }
        
        if let encryptedUrls = payload["image_urls"] as? [String] {
            let decryptedUrls = try encryptedUrls.compactMap { try decryptOptional($0) }
            decrypted["image_urls"] = decryptedUrls
        }
        
        return decrypted
    }
    
    func encryptCategoryPayload(_ payload: [String: Any]) throws -> [String: Any] {
        var encrypted = payload
        
        if let name = payload["name"] as? String {
            encrypted["name"] = try encrypt(name).ciphertext
        }
        
        encrypted["is_encrypted"] = true
        
        return encrypted
    }
    
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
    
    // MARK: - Private Methods (UPDATED for iCloud Sync)
    
    /// Keychain'e kaydet - iCloud sync ile
    nonisolated private func storeKeyInKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Önce mevcut key'i sil (hem local hem synced)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyAccount,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // ✅ Yeni key'i ekle - iCloud Keychain sync ile
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true // ✅ iCloud sync enabled
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            Logger.keychain.error("❌ Failed to store key in Keychain: \(status)")
            throw EncryptionError.keychainError(status)
        }
        
        Logger.keychain.info("✅ Encryption key stored with iCloud sync")
    }
    
    /// Keychain'den al - iCloud sync ile
    nonisolated private func retrieveKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyAccount,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny, // ✅ Search both local and synced
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data,
              keyData.count == 32 else {
            if status != errSecItemNotFound {
                Logger.keychain.error("❌ Failed to retrieve key from Keychain: \(status)")
            }
            return nil
        }
        
        Logger.keychain.info("✅ Encryption key retrieved from Keychain")
        return SymmetricKey(data: keyData)
    }
}

// MARK: - Types (unchanged)

struct EncryptedData: Codable {
    let ciphertext: String
    let algorithm: String
}

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
            return NSLocalizedString("encryption.error.key_not_found", comment: "Key not found")
        case .invalidKeyFormat:
            return NSLocalizedString("encryption.error.invalid_key_format", comment: "Invalid format")
        case .encodingFailed:
            return NSLocalizedString("encryption.error.encoding_failed", comment: "Encoding failed")
        case .decodingFailed:
            return NSLocalizedString("encryption.error.decoding_failed", comment: "Decoding failed")
        case .encryptionFailed:
            return NSLocalizedString("encryption.error.encryption_failed", comment: "Encryption failed")
        case .decryptionFailed:
            return NSLocalizedString("encryption.error.decryption_failed", comment: "Decryption failed")
        case .invalidCiphertext:
            return NSLocalizedString("encryption.error.invalid_ciphertext", comment: "Invalid ciphertext")
        case .keychainError(let status):
            let format = NSLocalizedString("encryption.error.keychain_error", comment: "Keychain error")
            return String(format: format, status)
        }
    }
}

// MARK: - Key Backup View

import SwiftUI

/// Encryption key backup/restore UI - Localized
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
                    Label(
                        NSLocalizedString("encryption.status.label", comment: "Encryption Status"),
                        systemImage: "lock.shield"
                    )
                    Spacer()
                    Text(encryptionService.isKeyAvailable
                         ? NSLocalizedString("encryption.status.active", comment: "Active")
                         : NSLocalizedString("encryption.status.inactive", comment: "Inactive"))
                        .foregroundStyle(encryptionService.isKeyAvailable ? .green : .red)
                }
            } header: {
                Text(NSLocalizedString("encryption.status.title", comment: "Status"))
            } footer: {
                Text(NSLocalizedString("encryption.status.footer", comment: "Footer text"))
            }
            
            // Export
            Section {
                Button {
                    exportKey()
                } label: {
                    Label(
                        NSLocalizedString("encryption.export.button", comment: "Export Key"),
                        systemImage: "square.and.arrow.up"
                    )
                }
                
                if !exportedKey.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("encryption.export.key_label", comment: "Your Encryption Key:"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(exportedKey)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Button(NSLocalizedString("encryption.export.copy_button", comment: "Copy")) {
                            UIPasteboard.general.string = exportedKey
                        }
                        .font(.caption)
                    }
                }
            } header: {
                Text(NSLocalizedString("encryption.export.title", comment: "Backup"))
            } footer: {
                Text(NSLocalizedString("encryption.export.footer", comment: "Warning text"))
            }
            
            // Import
            Section {
                TextField(
                    NSLocalizedString("encryption.import.placeholder", comment: "Paste key..."),
                    text: $importKey
                )
                .font(.system(.body, design: .monospaced))
                
                Button {
                    importKeyAction()
                } label: {
                    Label(
                        NSLocalizedString("encryption.import.button", comment: "Import Key"),
                        systemImage: "square.and.arrow.down"
                    )
                }
                .disabled(importKey.isEmpty)
            } header: {
                Text(NSLocalizedString("encryption.import.title", comment: "Restore"))
            }
            
            // Reset (Danger Zone)
            Section {
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    Label(
                        NSLocalizedString("encryption.danger.reset_button", comment: "Reset Key"),
                        systemImage: "trash"
                    )
                }
            } header: {
                Text(NSLocalizedString("encryption.danger.title", comment: "Danger Zone"))
            } footer: {
                Text(NSLocalizedString("encryption.danger.footer", comment: "Warning"))
            }
        }
        .navigationTitle(NSLocalizedString("encryption.navigation_title", comment: "Encryption"))
        .alert(NSLocalizedString("encryption.alert.info", comment: "Info"), isPresented: $showingExportAlert) {
            Button(NSLocalizedString("encryption.alert.ok", comment: "OK"), role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert(NSLocalizedString("encryption.alert.reset_title", comment: "Reset Key"), isPresented: $showingResetAlert) {
            Button(NSLocalizedString("encryption.alert.cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("encryption.alert.reset_confirm", comment: "Reset"), role: .destructive) {
                resetKey()
            }
        } message: {
            Text(NSLocalizedString("encryption.alert.reset_message", comment: "Warning message"))
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
            alertMessage = NSLocalizedString("encryption.alert.import_success", comment: "Success message")
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

#Preview {
    NavigationStack {
        EncryptionKeyBackupView()
    }
}
