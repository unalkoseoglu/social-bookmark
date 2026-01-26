import SwiftUI

struct ShareExtensionPage: View {
    @State private var animateStep = 0
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // iPhone Mockup with Share Sheet
            ZStack(alignment: .bottom) {
                // Device Frame
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 8)
                    .frame(width: 220, height: 440)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                
                // Content (Safari simulation)
                VStack(spacing: 0) {
                    HStack {
                        Capsule().fill(.secondary.opacity(0.3)).frame(width: 100, height: 10)
                        Spacer()
                    }
                    .padding()
                    
                    Rectangle().fill(.secondary.opacity(0.1)).frame(height: 150).padding()
                    VStack(alignment: .leading, spacing: 10) {
                        Capsule().fill(.secondary.opacity(0.2)).frame(width: 140, height: 8)
                        Capsule().fill(.secondary.opacity(0.2)).frame(width: 120, height: 8)
                        Capsule().fill(.secondary.opacity(0.2)).frame(width: 160, height: 8)
                    }
                    .padding()
                    
                    Spacer()
                }
                .frame(width: 220, height: 440)
                
                // Share Sheet Simulation
                VStack(spacing: 12) {
                    Rectangle()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            VStack(spacing: 15) {
                                Capsule().fill(.secondary.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 8)
                                
                                HStack(spacing: 20) {
                                    ShareAppIcon(name: "Social Bookmark", systemImage: "bookmark.fill", color: .blue, isHighlighted: animateStep == 1)
                                    ShareAppIcon(name: "Messages", systemImage: "message.fill", color: .green, isHighlighted: false)
                                    ShareAppIcon(name: "Mail", systemImage: "envelope.fill", color: .blue, isHighlighted: false)
                                    ShareAppIcon(name: "Copy", systemImage: "doc.on.doc.fill", color: .gray, isHighlighted: false)
                                }
                                .padding(.horizontal)
                                
                                Divider().padding(.horizontal)
                                
                                VStack(spacing: 12) {
                                    ShareActionRow(label: "Add to Reading List", icon: "book")
                                    ShareActionRow(label: "Add Bookmark", icon: "star")
                                }
                                .padding(.horizontal)
                                
                                Spacer()
                            }
                        )
                        .frame(width: 200, height: 220)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                        .shadow(color: Color.primary.opacity(0.1), radius: 10)
                        .offset(y: animateStep >= 1 ? 20 : 250)
                }
            }
            .frame(height: 440)
            
            // Text Content
            VStack(spacing: 12) {
                Text(LocalizedStringKey("onboarding.share.title"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text(LocalizedStringKey("onboarding.share.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Steps
            HStack(spacing: 20) {
                StepIcon(systemName: "square.and.arrow.up", isActive: animateStep == 0)
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                StepIcon(systemName: "bookmark.fill", isActive: animateStep == 1)
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                StepIcon(systemName: "checkmark.circle.fill", isActive: animateStep == 2)
            }
            
            Text(LocalizedStringKey("onboarding.share.reminder"))
                .font(.caption)
                .foregroundStyle(.orange)
                .bold()
            
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
    let systemImage: String
    let color: Color
    let isHighlighted: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHighlighted ? .blue : .white)
                    .frame(width: 44, height: 44)
                    .shadow(radius: 1)
                
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(isHighlighted ? .white : color)
            }
            .scaleEffect(isHighlighted ? 1.1 : 1.0)
            
            Text(name)
                .font(.system(size: 8))
                .lineLimit(1)
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
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

struct StepIcon: View {
    let systemName: String
    let isActive: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? .blue : .secondary.opacity(0.1))
                .frame(width: 40, height: 40)
            
            Image(systemName: systemName)
                .font(.title3)
                .foregroundStyle(isActive ? .white : .secondary)
        }
        .scaleEffect(isActive ? 1.2 : 1.0)
    }
}

#Preview {
    ShareExtensionPage()
        .preferredColorScheme(.dark)
}
