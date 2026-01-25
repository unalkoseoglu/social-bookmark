import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Image / Icon
            Image(systemName: page.systemImage)
                .font(.system(size: 120))
                .foregroundStyle(page.accentColor.gradient)
                .symbolEffect(.bounce, value: page.id)
            
            VStack(spacing: 16) {
                // Title
                Text(LocalizedStringKey(page.titleKey))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Subtitle
                Text(LocalizedStringKey(page.subtitleKey))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingPageView(page: OnboardingPage(
        titleKey: "onboarding.welcome.title",
        subtitleKey: "onboarding.welcome.subtitle",
        systemImage: "bookmark.fill",
        accentColor: .blue
    ))
}
