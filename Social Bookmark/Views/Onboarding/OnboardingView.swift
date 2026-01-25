import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            titleKey: "onboarding.welcome.title",
            subtitleKey: "onboarding.welcome.subtitle",
            systemImage: "bookmark.fill",
            accentColor: .blue
        ),
        OnboardingPage(
            titleKey: "onboarding.features.title",
            subtitleKey: "onboarding.features.subtitle",
            systemImage: "plus.square.on.square",
            accentColor: .orange
        ),
        OnboardingPage(
            titleKey: "onboarding.organize.title",
            subtitleKey: "onboarding.organize.subtitle",
            systemImage: "tag.fill",
            accentColor: .green
        ),
        OnboardingPage(
            titleKey: "onboarding.privacy.title",
            subtitleKey: "onboarding.privacy.subtitle",
            systemImage: "shield.checkered",
            accentColor: .purple
        )
    ]
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                // Skip Button
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Text(LocalizedStringKey("common.skip"))
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding()
                }
                
                // Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Footer
                VStack(spacing: 24) {
                    PageIndicator(
                        numberOfPages: pages.count,
                        currentPage: currentPage,
                        color: pages[currentPage].accentColor
                    )
                    
                    OnboardingButton(
                        title: String(localized: currentPage == pages.count - 1 ? "common.getStarted" : "common.continue"),
                        action: {
                            if currentPage < pages.count - 1 {
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                isPresented = false
                            }
                        },
                        color: pages[currentPage].accentColor
                    )
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
