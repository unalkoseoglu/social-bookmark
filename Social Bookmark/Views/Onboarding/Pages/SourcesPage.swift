import SwiftUI

enum PlatformAsset {
    case system(String)
    case image(String)
}

struct Platform {
    let id: String
    let name: String
    let color: Color
    let asset: PlatformAsset
}

struct SourcesPage: View {
    @State private var animateIcons = false
    
    let platforms = [
        Platform(id: "x", name: "X", color: .primary, asset: .image("logo_x")),
        Platform(id: "reddit", name: "Reddit", color: .orange, asset: .image("logo_reddit")),
        Platform(id: "facebook", name: "Facebook", color: .blue, asset: .image("logo_facebook")),
        Platform(id: "linkedin", name: "LinkedIn", color: .blue, asset: .image("logo_linkedin")),
        Platform(id: "instagram", name: "Instagram", color: .pink, asset: .image("logo_instagram")),
        Platform(id: "youtube", name: "YouTube", color: .red, asset: .image("logo_youtube")),
        Platform(id: "medium", name: "Medium", color: .primary, asset: .image("logo_medium")),
        Platform(id: "wordpress", name: "WP", color: .blue, asset: .image("logo_wp"))
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon Grid
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    .frame(width: 300, height: 300)
                
                ForEach(0..<platforms.count, id: \.self) { index in
                    let platform = platforms[index]
                    PlatformIcon(platform: platform)
                        .offset(
                            x: 100 * cos(CGFloat(index) * 2 * .pi / CGFloat(platforms.count) - .pi/2),
                            y: 100 * sin(CGFloat(index) * 2 * .pi / CGFloat(platforms.count) - .pi/2)
                        )
                        .scaleEffect(animateIcons ? 1.0 : 0.0)
                        .opacity(animateIcons ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animateIcons)
                }
                
                // Simplified Central Icon (Black & White)
                ZStack {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color(UIColor.systemBackground))
                }
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .scaleEffect(animateIcons ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateIcons)
            }
            .frame(height: 320)
            
            // Text Content
            VStack(spacing: 12) {
                Text(LocalizedStringKey("onboarding.sources.title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text(LocalizedStringKey("onboarding.sources.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Bullet Points
            VStack(alignment: .leading, spacing: 10) {
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
    let platform: Platform
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(width: 54, height: 54)
                    .shadow(color: Color.black.opacity(0.05), radius: 5)
                
                switch platform.asset {
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(platform.color)
                        .background(Color.white)
                case .image(let name):
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                }
            }
            Text(platform.name)
                .font(.system(size: 10, weight: .medium))
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
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    SourcesPage()
        .preferredColorScheme(.dark)
}
