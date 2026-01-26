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
                    Text(String(localized: "encryption.debug.has_key"))
                    Spacer()
                    Text(hasKey ? String(localized: "encryption.debug.yes") : String(localized: "encryption.debug.no"))
                        .foregroundStyle(hasKey ? .green : .red)
                }
                
                Button(String(localized: "encryption.debug.check_key")) {
                    checkKey()
                }
            } header: {
                Text(String(localized: "encryption.debug.key_status"))
            }
            
            Section {
                Button(String(localized: "encryption.debug.run_test")) {
                    testEncryption()
                }
                
                if !testResult.isEmpty {
                    Text(testResult)
                        .font(.caption)
                        .foregroundStyle(testResult.contains("✅") ? .green : .red)
                }
            } header: {
                Text(String(localized: "encryption.debug.test_section"))
            }
            
            Section {
                Button(String(localized: "encryption.debug.export_button")) {
                    exportKey()
                }
            } header: {
                Text(String(localized: "encryption.debug.export_section"))
            }
            
            // ✅ IMPORT SECTION EKLENDI
            Section {
                TextField(String(localized: "encryption.debug.import_placeholder"), text: $importKey, axis: .vertical)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(3...6)
                
                Button(String(localized: "encryption.debug.import_button")) {
                    importKeyAction()
                }
                .disabled(importKey.isEmpty)
            } header: {
                Text(String(localized: "encryption.debug.import_section"))
            } footer: {
                Text(String(localized: "encryption.debug.import_footer"))
            }
        }
        .navigationTitle(String(localized: "encryption.debug.title"))
        .onAppear {
            checkKey()
        }
    }
    
    private func checkKey() {
        do {
            let _ = try encryptionService.getOrCreateKey()
            hasKey = true
            testResult = String(localized: "encryption.debug.test_success")
        } catch {
            hasKey = false
            testResult = String(localized: "encryption.debug.test_fail \(error.localizedDescription)")
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
                testResult = String(localized: "encryption.debug.test_run_success \(original)")
            } else {
                testResult = String(localized: "encryption.debug.test_run_fail \(original)")
            }
        } catch {
            testResult = String(localized: "encryption.debug.test_run_fail \(error.localizedDescription)")
        }
    }
    
    private func exportKey() {
        do {
            let key = try encryptionService.exportKey()
            UIPasteboard.general.string = key
            testResult = String(localized: "encryption.debug.copy_success \(String(key.prefix(20)))")
            print("🔐 Encrypted: \(key)")
        } catch {
            testResult = String(localized: "encryption.debug.test_run_fail \(error.localizedDescription)")
        }
    }
    
    // ✅ IMPORT ACTION EKLENDI
    private func importKeyAction() {
        do {
            try encryptionService.importKey(base64String: importKey.trimmingCharacters(in: .whitespacesAndNewlines))
            testResult = String(localized: "encryption.debug.import_success")
            hasKey = true
            importKey = ""
        } catch {
            testResult = String(localized: "encryption.debug.test_run_fail \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        EncryptionDebugView()
    }
}
