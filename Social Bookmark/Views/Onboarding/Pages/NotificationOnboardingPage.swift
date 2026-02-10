import SwiftUI

struct NotificationOnboardingPage: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Notification Illustration
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 160, height: 160)
                
                Image(systemName: "bell.badge.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.blue)
                    .symbolEffect(.bounce, value: isVisible)
            }
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
            
            // Text Content
            VStack(spacing: 16) {
                Text(LanguageManager.shared.localized("onboarding.notifications.title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Text(LanguageManager.shared.localized("onboarding.notifications.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            
            // Features List
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow2(icon: "clock.badge.checkmark", text: "onboarding.notifications.feature1")
                FeatureRow2(icon: "sparkles", text: "onboarding.notifications.feature2")
                FeatureRow2(icon: "lock.shield", text: "onboarding.notifications.feature3")
            }
            .padding(.horizontal, 40)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                isVisible = true
            }
        }
    }
}

private struct FeatureRow2: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            Text(LanguageManager.shared.localized(text))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NotificationOnboardingPage()
}
