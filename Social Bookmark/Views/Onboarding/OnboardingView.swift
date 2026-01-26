import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack {
                // Header (Skip Button)
                HStack {
                    Spacer()
                    if currentPage < 3 {
                        Button(action: { isPresented = false }) {
                            Text(LocalizedStringKey("common.skip"))
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .transition(.opacity)
                    }
                }
                .padding()
                .zIndex(1)
                
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
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Footer
                VStack(spacing: 24) {
                    // Page Indicator (Dots)
                    HStack(spacing: 8) {
                        ForEach(0..<4) { index in
                            Circle()
                                .fill(currentPage == index ? Color.blue : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    
                    if currentPage < 3 {
                        // Regular "Continue" button for first 3 pages
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            Text(LocalizedStringKey("common.continue"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.blue)
                                .cornerRadius(16)
                                .padding(.horizontal, 32)
                        }
                    } else {
                        // Final CTA for the last page
                        VStack(spacing: 16) {
                            Button(action: { isPresented = false }) {
                                Text(LocalizedStringKey("common.getStarted"))
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.blue)
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
                                    .foregroundStyle(.blue)
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
