import SwiftUI

struct WelcomePage: View {
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.15),
                    Color.purple.opacity(0.15),
                    Color(UIColor.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Icon with Glow
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.primary.opacity(0.1), radius: 20)
                    
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(isVisible ? 1.0 : 0.8)
                .opacity(isVisible ? 1.0 : 0.0)
                
                // Text Content
                VStack(spacing: 16) {
                    Text(LocalizedStringKey("onboarding.welcome.title"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .opacity(isVisible ? 1.0 : 0.0)
                        .offset(y: isVisible ? 0 : 20)
                    
                    Text(LocalizedStringKey("onboarding.welcome.subtitle"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(isVisible ? 0.8 : 0.0)
                        .offset(y: isVisible ? 0 : 20)
                }
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    WelcomePage()
        .preferredColorScheme(.dark)
}
