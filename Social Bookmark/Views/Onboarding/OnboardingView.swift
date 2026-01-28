import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
           
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack {
                // Header (Skip Button)
                
                
                // Content
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    
                    SourcesPage()
                        .tag(1)
                    
                    ShareExtensionPage()
                        .tag(2)
                    
                    SearchFeaturesPage()
                        .tag(3)
                    
                    NotificationOnboardingPage()
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Footer
                VStack(spacing: 24) {
                    // Page Indicator (Dots)
                    HStack(spacing: 8) {
                        ForEach(0..<5) { index in
                            Circle()
                                .fill(currentPage == index ? (colorScheme == .dark ? .white : .black ): Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    
                    if currentPage < 4 {
                        // Regular "Continue" button for first 3 pages
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            Text(LocalizedStringKey("common.continue"))
                                .font(.headline)
                                .foregroundStyle(colorScheme == .dark ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(colorScheme == .dark ? .white : .black)
                                .cornerRadius(16)
                                .padding(.horizontal, 32)
                        }
                    } else {
                        // Final CTA for the last page
                        VStack(spacing: 16) {
                            Button(action: { 
                                isPresented = false 
                            }) {
                                Text(LocalizedStringKey("common.getStarted"))
                                    .font(.headline)
                                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(colorScheme == .dark ? .white : .black)
                                    .cornerRadius(16)
                                    .padding(.horizontal, 32)
                            }
                            
                            Button(action: { 
                                // In a real app, this might trigger a login flow
                                // For now, we follow the current behavior of closing onboarding
                                isPresented = false 
                            }) {
                                Text(LocalizedStringKey("onboarding.action.login"))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.black)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            
        }
       
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
