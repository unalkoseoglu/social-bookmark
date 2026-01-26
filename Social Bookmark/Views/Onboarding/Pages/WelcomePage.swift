import SwiftUI

struct WelcomePage: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            
            VStack(spacing: 40) {
                Spacer()
                
                // Welcome Illustration
                Image(colorScheme == .dark ? "logo_light_app_icon" : "logo_dark_app_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200)

                
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
                        .fixedSize(horizontal: false, vertical: true)
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
