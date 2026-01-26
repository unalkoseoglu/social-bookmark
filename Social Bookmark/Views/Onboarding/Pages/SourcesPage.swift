import SwiftUI

struct SourcesPage: View {
    @State private var animateIcons = false
    
    let platforms = [
        ("twitter", "X", Color.primary),
        ("reddit", "Reddit", Color.orange),
        ("linkedin", "LinkedIn", Color.blue),
        ("medium", "Medium", Color.primary),
        ("globe", "Web", Color.gray),
        ("photo", "Images", Color.green)
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon Grid
            ZStack {
                Circle()
                    .stroke(LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    .frame(width: 300, height: 300)
                
                ForEach(0..<platforms.count, id: \.self) { index in
                    PlatformIcon(
                        systemName: platforms[index].0,
                        name: platforms[index].1,
                        color: platforms[index].2
                    )
                    .offset(
                        x: 100 * cos(CGFloat(index) * 2 * .pi / CGFloat(platforms.count)),
                        y: 100 * sin(CGFloat(index) * 2 * .pi / CGFloat(platforms.count))
                    )
                    .scaleEffect(animateIcons ? 1.0 : 0.0)
                    .opacity(animateIcons ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(index) * 0.1), value: animateIcons)
                }
                
                // Central Icon
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                    .background(Circle().fill(.white).frame(width: 50, height: 50))
                    .shadow(radius: 10)
                    .scaleEffect(animateIcons ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateIcons)
            }
            .frame(height: 320)
            
            // Text Content
            VStack(spacing: 16) {
                Text(LocalizedStringKey("onboarding.sources.title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text(LocalizedStringKey("onboarding.sources.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Bullet Points
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(text: "onboarding.sources.features.smart")
                FeatureRow(text: "onboarding.sources.features.ocr")
                FeatureRow(text: "onboarding.sources.features.web")
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .onAppear {
            animateIcons = true
        }
    }
}

struct PlatformIcon: View {
    let systemName: String
    let name: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: systemName == "twitter" ? "xmark" : systemName)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
            }
            Text(name)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
    }
}

struct FeatureRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(LocalizedStringKey(text))
                .font(.subheadline)
        }
    }
}

#Preview {
    SourcesPage()
        .preferredColorScheme(.dark)
}
