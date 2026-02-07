//
//  EncryptionDebugView.swift
//  Social Bookmark
//
//  Encryption durumunu kontrol etmek için
//

import SwiftUI

// TODO: Re-enable when EncryptionService is implemented
struct EncryptionDebugView: View {
    var body: some View {
        EncryptionKeyBackupView()
    }
}

#Preview {
    NavigationStack {
        EncryptionDebugView()
    }
}
