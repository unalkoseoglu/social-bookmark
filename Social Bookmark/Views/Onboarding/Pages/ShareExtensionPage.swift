import SwiftUI

struct ShareExtensionPage: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var animateStep = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 1. iPhone Mockup (Top)
            ZStack(alignment: .bottom) {
                // Device Frame
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 6)
                    .frame(width: 240, height: 420)
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                
                // Screen Content (Clipped)
                ZStack(alignment: .bottom) {
                    // Web Content Simulation (Safari)
                    VStack(spacing: 12) {
                        HStack {
                            Circle().fill(.secondary.opacity(0.2)).frame(width: 20, height: 20)
                            Capsule().fill(.secondary.opacity(0.2)).frame(width: 100, height: 10)
                            Spacer()
                        }
                        .padding(.top, 30)
                        
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 160)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Capsule().fill(.secondary.opacity(0.2)).frame(width: 160, height: 6)
                            Capsule().fill(.secondary.opacity(0.2)).frame(width: 120, height: 6)
                            Capsule().fill(.secondary.opacity(0.2)).frame(width: 140, height: 6)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Share Sheet Simulation (Inside Screen)
                    VStack(spacing: 16) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 36, height: 5)
                            .padding(.top, 8)
                        
                        // App Row
                        ScrollView(.horizontal, showsIndicators: false) {
                            var imageDark = colorScheme == .dark ? "logo_dark_app_icon" : "logo_dark_app_icon";
                            var imageDark2 = colorScheme == .dark ? "logo_light_app_icon" : "logo_dark_app_icon";
                            HStack(spacing: 16) {
                                ShareAppIcon(name: "Link Bookmark", image: animateStep == 1 ? imageDark : imageDark2 , color: .white, isHighlighted: animateStep == 1)
                                ShareAppIcon(name: "Messages", systemImage: "message.fill", color: .green, isHighlighted: false)
                                ShareAppIcon(name: "Mail", systemImage: "envelope.fill", color: .blue, isHighlighted: false)
                            }
                            .padding(.horizontal)
                        }
                        
                        VStack(spacing: 1) {
                            ShareActionRow(label: "Add to Reading List", icon: "book")
                            Divider().padding(.leading, 40)
                            ShareActionRow(label: "Add Bookmark", icon: "star")
                        }
                        .cornerRadius(6)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .frame(width: 240, height: 240)
                    .background(.ultraThinMaterial)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                    .shadow(color: Color.black.opacity(0.15), radius: 10, y: -5)
                    .offset(y: animateStep >= 1 ? 20 : 250)
                }
                .frame(width: 240, height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
            .frame(height: 420)
            
            Spacer(minLength: 30)
            
            // 2. Step Animation Bar (Middle)
            HStack(spacing: 40) {
                StepIcon(systemName: "square.and.arrow.up", isActive: animateStep == 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                StepIcon(systemName: "bookmark.fill", isActive: animateStep == 1)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                StepIcon(systemName: "checkmark.circle.fill", isActive: animateStep == 2)
            }
            .padding(.bottom, 30)
            
            // 3. Text Content (Bottom)
            VStack(spacing: 12) {
                Text("onboarding.share.title")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("onboarding.share.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(LocalizedStringKey("onboarding.share.reminder"))
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)
            
            Spacer()
        
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.spring()) {
                animateStep = (animateStep + 1) % 3
            }
        }
    }
}

struct ShareAppIcon: View {
    let name: String
    var systemImage: String?
    var image: String?
    let color: Color
    let isHighlighted: Bool
    
    var body: some View {
        @Environment(\.colorScheme) var colorScheme
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHighlighted ? (colorScheme == .dark ? Color.primary :  Color.white) : Color(UIColor.secondarySystemBackground))
                    .frame(width: 54, height: 54)
                    .shadow(color: Color.primary.opacity(0.1), radius: 2)
                if (image != nil){
                    Image(image!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24)
                        
                }
                if (systemImage != nil){
                    Image(systemName: systemImage!)
                        .font(.system(size: 20))
                        
                        .foregroundStyle(isHighlighted ? Color.primary : color)
                }
                
               
            }
            .scaleEffect(isHighlighted ? 1.05 : 1.0)
            
            Text(name)
                .font(.system(size: 10))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ShareActionRow: View {
    let label: String
    let icon: String
    
    var body: some View {
        HStack {
            Text(label).font(.system(size: 10))
            Spacer()
            Image(systemName: icon).font(.system(size: 10))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(6)
    }
}

struct StepIcon: View {
    let systemName: String
    let isActive: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? Color.primary : Color.primary.opacity(0.1))
                .frame(width: 40, height: 40)
            
            Image(systemName: systemName)
                .font(.title3)
                .foregroundStyle(isActive ? Color(UIColor.systemBackground) : Color.primary.opacity(0.6))
        }
        .scaleEffect(isActive ? 1.2 : 1.0)
    }
}

#Preview {
    ShareExtensionPage()
        .preferredColorScheme(.dark)
}
