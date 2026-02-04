//
//  LinkAccountSheet.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 24.12.2025.
//


//
//  AccountSettingsView+Migration.swift
//  Social Bookmark
//
//  Migration progress UI ve güncellenmiş Link Account akışı
//

import SwiftUI
import AuthenticationServices

// MARK: - Link Account Sheet (Migration destekli)

struct LinkAccountSheet: View {
    @EnvironmentObject private var sessionStore: SessionStore
    // @StateObject private var migrationService = AccountMigrationService.shared // TODO: Re-enable when AccountMigrationService is implemented
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationStack {
            Group {
                linkAccountContent
                // TODO: Re-enable migration views when AccountMigrationService is implemented
                // if migrationService.state.isInProgress {
                //     migrationProgressView
                // } else if migrationService.state == .completed {
                //     migrationCompletedView
                // } else if case .failed(let error) = migrationService.state {
                //     migrationFailedView(error: error)
                // } else {
                //     linkAccountContent
                // }
            }
            .navigationTitle(String(localized: "settings.link_account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
        // .interactiveDismissDisabled(migrationService.state.isInProgress) // TODO: Re-enable
    }
    
    // MARK: - Link Account Content
    
    private var linkAccountContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // İkon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)
            }
            
            // Başlık
            VStack(spacing: 8) {
                Text("settings.secure_your_data")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("settings.link_description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Faydalar
            VStack(alignment: .leading, spacing: 12) {
                benefitRow(
                    icon: "icloud.fill",
                    text: "settings.benefit_sync",
                    color: .blue
                )
                benefitRow(
                    icon: "arrow.triangle.2.circlepath",
                    text: "settings.benefit_restore",
                    color: .green
                )
                benefitRow(
                    icon: "lock.shield.fill",
                    text: "settings.benefit_secure",
                    color: .purple
                )
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Uyarı
            warningSection
            
            // Apple Sign In Butonu
            SignInWithAppleButton(.continue) { request in
                sessionStore.configureAppleRequest(request)
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .cornerRadius(12)
            .padding(.horizontal, 24)
            
            // Bilgi
            Text("settings.link_keeps_data")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
                .frame(height: 20)
        }
    }
    
    // MARK: - Warning Section
    
    private var warningSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("settings.migration_warning_title")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("settings.migration_warning_body")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Migration Progress View (Placeholder)
    // TODO: Re-enable when AccountMigrationService is implemented
    
    private var migrationProgressView: some View {
        VStack {
            ProgressView()
            Text("Migration in progress...")
        }
    }
    
    private var stateIcon: String {
        return "arrow.triangle.2.circlepath"
    }
    
    // MARK: - Migration Completed View (Placeholder)
    // TODO: Re-enable when AccountMigrationService is implemented
    
    private var migrationCompletedView: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("Migration completed")
            Button("Done") {
                dismiss()
            }
        }
    }
    
    // MARK: - Migration Failed View (Placeholder)
    // TODO: Re-enable when AccountMigrationService is implemented
    
    private func migrationFailedView(error: String) -> some View {
        VStack {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("Migration failed")
            Text(error)
                .font(.caption)
            Button("Dismiss") {
                dismiss()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func benefitRow(icon: String, text: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
    
    private func statisticRow(icon: String, label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Private Methods
    
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }
            Task {
                await sessionStore.linkAnonymousToApple(credential: credential)
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                return
            }
            // sessionStore.setError(.appleSignInFailed(error.localizedDescription)) // TODO: Re-enable when error handling is implemented
            print("❌ Apple Sign In failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

#Preview("Link Account") {
    LinkAccountSheet()
        .environmentObject(SessionStore())
}
