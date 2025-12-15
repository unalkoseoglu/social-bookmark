// Features/Auth/RootView.swift

import SwiftUI

/// Root view that switches between auth states
struct RootView: View {
    
    @StateObject private var sessionStore = SessionStore()
    
    var body: some View {
        Group {
            if sessionStore.isLoading {
                LoadingView()
            } else if sessionStore.isAuthenticated {
                HomeView()
            } else {
                SignInView()
            }
        }
        .environmentObject(sessionStore)
        .task {
            await sessionStore.initialize()
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("auth.loading", bundle: .main)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView()
}