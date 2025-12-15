//
//  SupabaseEnvironment.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//

import SwiftUI

// MARK: - Environment Keys

/// Supabase Manager için Environment Key
private struct SupabaseManagerKey: EnvironmentKey {
    static let defaultValue: SupabaseManager = .shared
}

/// Auth Service için Environment Key
private struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: AuthService = .shared
}

/// Network Monitor için Environment Key
private struct NetworkMonitorKey: EnvironmentKey {
    static let defaultValue: NetworkMonitor = .shared
}

// MARK: - Environment Values Extension

extension EnvironmentValues {
    /// Supabase Manager
    var supabaseManager: SupabaseManager {
        get { self[SupabaseManagerKey.self] }
        set { self[SupabaseManagerKey.self] = newValue }
    }
    
    /// Auth Service
    var authService: AuthService {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
    
    /// Network Monitor
    var networkMonitor: NetworkMonitor {
        get { self[NetworkMonitorKey.self] }
        set { self[NetworkMonitorKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Supabase servislerini view'a enjekte et
    func withSupabase() -> some View {
        self
            .environment(\.supabaseManager, .shared)
            .environment(\.authService, .shared)
            .environment(\.networkMonitor, .shared)
    }
}

// MARK: - Auth State View Modifier

/// Auth durumuna göre view değiştiren modifier
struct AuthStateModifier: ViewModifier {
    @ObservedObject private var authService = AuthService.shared
    
    let authenticatedView: AnyView
    let unauthenticatedView: AnyView
    let loadingView: AnyView?
    
    func body(content: Content) -> some View {
        Group {
            switch SupabaseManager.shared.authState {
            case .initializing:
                if let loadingView {
                    loadingView
                } else {
                    ProgressView()
                }
                
            case .authenticated:
                authenticatedView
                
            case .unauthenticated, .error:
                unauthenticatedView
            }
        }
    }
}

extension View {
    /// Auth durumuna göre farklı view göster
    func authStateView<Authenticated: View, Unauthenticated: View>(
        authenticated: @escaping () -> Authenticated,
        unauthenticated: @escaping () -> Unauthenticated
    ) -> some View {
        modifier(AuthStateModifier(
            authenticatedView: AnyView(authenticated()),
            unauthenticatedView: AnyView(unauthenticated()),
            loadingView: nil
        ))
    }
    
    /// Auth durumuna göre farklı view göster (loading ile)
    func authStateView<Authenticated: View, Unauthenticated: View, Loading: View>(
        authenticated: @escaping () -> Authenticated,
        unauthenticated: @escaping () -> Unauthenticated,
        loading: @escaping () -> Loading
    ) -> some View {
        modifier(AuthStateModifier(
            authenticatedView: AnyView(authenticated()),
            unauthenticatedView: AnyView(unauthenticated()),
            loadingView: AnyView(loading())
        ))
    }
}

// MARK: - Network State View Modifier

/// Offline durumunda banner gösteren modifier
struct OfflineBannerModifier: ViewModifier {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("Çevrimdışı")
                    Spacer()
                    Text("Değişiklikler kaydedilecek")
                        .font(.caption)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            content
        }
        .animation(.easeInOut, value: networkMonitor.isConnected)
    }
}

extension View {
    /// Offline durumunda banner göster
    func offlineBanner() -> some View {
        modifier(OfflineBannerModifier())
    }
}

// MARK: - Loading Overlay Modifier

/// Auth işlemleri sırasında loading overlay
struct AuthLoadingModifier: ViewModifier {
    @ObservedObject private var authService = AuthService.shared
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if authService.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
            }
            .animation(.easeInOut, value: authService.isLoading)
    }
}

extension View {
    /// Auth loading overlay
    func authLoading() -> some View {
        modifier(AuthLoadingModifier())
    }
}

// MARK: - Error Alert Modifier

/// Auth hatalarını alert olarak göster
struct AuthErrorAlertModifier: ViewModifier {
    @ObservedObject private var authService = AuthService.shared
    @State private var showAlert = false
    
    func body(content: Content) -> some View {
        content
            .alert("Hata", isPresented: $showAlert) {
                Button("Tamam", role: .cancel) {
                    authService.errorMessage = nil
                }
            } message: {
                Text(authService.errorMessage ?? "Bilinmeyen hata")
            }
            .onChange(of: authService.errorMessage) { _, newValue in
                showAlert = newValue != nil
            }
    }
}

extension View {
    /// Auth hatalarını alert olarak göster
    func authErrorAlert() -> some View {
        modifier(AuthErrorAlertModifier())
    }
}
