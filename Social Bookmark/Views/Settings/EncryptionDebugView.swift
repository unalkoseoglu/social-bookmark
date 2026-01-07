//
//  EncryptionDebugView.swift
//  Social Bookmark
//
//  Encryption durumunu kontrol etmek için
//

import SwiftUI

struct EncryptionDebugView: View {
    @StateObject private var encryptionService = EncryptionService.shared
    @State private var testResult = ""
    @State private var hasKey = false
    @State private var importKey = ""
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Key Mevcut mu?")
                    Spacer()
                    Text(hasKey ? "✅ EVET" : "❌ HAYIR")
                        .foregroundStyle(hasKey ? .green : .red)
                }
                
                Button("Key'i Kontrol Et") {
                    checkKey()
                }
            } header: {
                Text("Encryption Key Durumu")
            }
            
            Section {
                Button("Şifreleme Testi Yap") {
                    testEncryption()
                }
                
                if !testResult.isEmpty {
                    Text(testResult)
                        .font(.caption)
                        .foregroundStyle(testResult.contains("✅") ? .green : .red)
                }
            } header: {
                Text("Test Encryption")
            }
            
            Section {
                Button("Key'i Export Et") {
                    exportKey()
                }
            } header: {
                Text("Key Export")
            }
            
            // ✅ IMPORT SECTION EKLENDI
            Section {
                TextField("Key'i buraya yapıştır...", text: $importKey, axis: .vertical)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(3...6)
                
                Button("Anahtarı İçe Aktar") {
                    importKeyAction()
                }
                .disabled(importKey.isEmpty)
            } header: {
                Text("Key Import")
            } footer: {
                Text("iPhone'dan export ettiğiniz key'i buraya yapıştırıp import edin.")
            }
        }
        .navigationTitle("Encryption Debug")
        .onAppear {
            checkKey()
        }
    }
    
    private func checkKey() {
        do {
            let _ = try encryptionService.getOrCreateKey()
            hasKey = true
            testResult = "✅ Encryption key başarıyla yüklendi"
        } catch {
            hasKey = false
            testResult = "❌ Encryption key yüklenemedi: \(error.localizedDescription)"
        }
    }
    
    private func testEncryption() {
        do {
            // Test data
            let original = "Test Bookmark Title"
            
            // Encrypt
            let encrypted = try encryptionService.encrypt(original)
            print("🔐 Encrypted: \(encrypted.ciphertext)")
            
            // Decrypt
            let decrypted = try encryptionService.decryptString(encrypted)
            print("🔓 Decrypted: \(decrypted)")
            
            if decrypted == original {
                testResult = "✅ Encryption/Decryption başarılı!\nOriginal: \(original)\nDecrypted: \(decrypted)"
            } else {
                testResult = "❌ Decryption başarısız!\nOriginal: \(original)\nDecrypted: \(decrypted)"
            }
        } catch {
            testResult = "❌ Test başarısız: \(error.localizedDescription)"
        }
    }
    
    private func exportKey() {
        do {
            let key = try encryptionService.exportKey()
            UIPasteboard.general.string = key
            testResult = "✅ Key kopyalandı! İlk 20 karakter: \(String(key.prefix(20)))..."
            print("🔐 Encrypted: \(key)")
        } catch {
            testResult = "❌ Key export başarısız: \(error.localizedDescription)"
        }
    }
    
    // ✅ IMPORT ACTION EKLENDI
    private func importKeyAction() {
        do {
            try encryptionService.importKey(base64String: importKey.trimmingCharacters(in: .whitespacesAndNewlines))
            testResult = "✅ Key başarıyla import edildi!"
            hasKey = true
            importKey = ""
        } catch {
            testResult = "❌ Key import başarısız: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        EncryptionDebugView()
    }
}
