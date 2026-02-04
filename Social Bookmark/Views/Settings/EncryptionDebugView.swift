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
        List {
            Section {
                Text("Encryption service is not yet implemented.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Encryption Debug")
            }
        }
        .navigationTitle("Encryption Debug")
    }
}

#Preview {
    NavigationStack {
        EncryptionDebugView()
    }
}
