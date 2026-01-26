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
    @StateObject private var migrationService = AccountMigrationService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationStack {
            Group {
                if migrationService.state.isInProgress {
                    migrationProgressView
                } else if migrationService.state == .completed {
                    migrationCompletedView
                } else if case .failed(let error) = migrationService.state {
                    migrationFailedView(error: error)
                } else {
                    linkAccountContent
                }
            }
            .navigationTitle(String(localized: "settings.link_account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !migrationService.state.isInProgress {
                        Button(String(localized: "common.cancel")) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(migrationService.state.isInProgress)
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
    
    // MARK: - Migration Progress View
    
    private var migrationProgressView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animasyonlu ikon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: migrationService.state.progress)
                    .stroke(Color.blue, lineWidth: 4)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: migrationService.state.progress)
                
                Image(systemName: stateIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse.wholeSymbol, options: .repeating)
            }
            
            // Durum açıklaması
            VStack(spacing: 8) {
                Text("settings.migrating_data")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(migrationService.state.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: migrationService.state.progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                Text("\(Int(migrationService.state.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 48)
            
            // Uyarı
            Text("settings.do_not_close")
                .font(.caption)
                .foregroundStyle(.orange)
            
            Spacer()
        }
    }
    
    private var stateIcon: String {
        switch migrationService.state {
        case .migratingCategories:
            return "folder.fill"
        case .migratingBookmarks:
            return "bookmark.fill"
        case .uploadingImages:
            return "photo.fill"
        case .cleaningUp:
            return "trash.fill"
        default:
            return "arrow.triangle.2.circlepath"
        }
    }
    
    // MARK: - Migration Completed View
    
    private var migrationCompletedView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Başarı ikonu
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
            }
            
            // Mesaj
            VStack(spacing: 8) {
                Text("settings.migration_complete")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("settings.migration_complete_desc")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // İstatistikler
            if let result = migrationService.lastResult {
                VStack(spacing: 12) {
                    statisticRow(
                        icon: "folder.fill",
                        label: "settings.categories_migrated",
                        value: "\(result.categoriesMigrated)"
                    )
                    statisticRow(
                        icon: "bookmark.fill",
                        label: "settings.bookmarks_migrated",
                        value: "\(result.bookmarksMigrated)"
                    )
                    statisticRow(
                        icon: "photo.fill",
                        label: "settings.images_migrated",
                        value: "\(result.imagesMigrated)"
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Kapat butonu
            Button {
                migrationService.reset()
                dismiss()
            } label: {
                Text("common.done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Migration Failed View
    
    private func migrationFailedView(error: String) -> some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Hata ikonu
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
            }
            
            // Mesaj
            VStack(spacing: 8) {
                Text("settings.migration_failed")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Butonlar
            VStack(spacing: 12) {
                Button {
                    migrationService.reset()
                    // Tekrar dene
                } label: {
                    Text("common.try_again")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                
                Button {
                    migrationService.reset()
                    dismiss()
                } label: {
                    Text("common.cancel")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
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
            sessionStore.setError(.appleSignInFailed(error.localizedDescription))
        }
    }
}

// MARK: - Preview

#Preview("Link Account") {
    LinkAccountSheet()
        .environmentObject(SessionStore())
}
