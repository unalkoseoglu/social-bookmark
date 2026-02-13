import SwiftUI

struct SearchFeaturesPage: View {
    @State private var searchText = ""
    @State private var animateResults = false
    
    let sampleResults = [
        ("SwiftUI Layout", "Learn how to build beautiful layouts...", "Web"),
        ("Link Bookmark API", "Documenting the endpoints for Link Bookmark", "Docs"),
        ("X Post by @username", "Check out this amazing thread about AI...", "X")
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Search Bar Mockup
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text(LanguageManager.shared.localized("search.mockup.query"))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 15).fill(Color(UIColor.secondarySystemBackground)))
                .padding(.horizontal, 40)
                
                // Results List
                VStack(spacing: 12) {
                    ForEach(0..<sampleResults.count, id: \.self) { index in
                        ResultCard(
                            title: sampleResults[index].0,
                            description: sampleResults[index].1,
                            source: sampleResults[index].2,
                            delay: Double(index) * 0.2
                        )
                        .offset(y: animateResults ? 0 : 50)
                        .opacity(animateResults ? 1.0 : 0.0)
                    }
                }
                .padding(.horizontal, 30)
            }
            
            // Text Content
            VStack(spacing: 12) {
                Text(LanguageManager.shared.localized("onboarding.search.title"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text(LanguageManager.shared.localized("onboarding.search.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Feature Grid (Icons)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                OnboardingFeatureItem(icon: "text.magnifyingglass", text: "onboarding.search.features.fulltext")
                OnboardingFeatureItem(icon: "tag.fill", text: "onboarding.search.features.filter")
                OnboardingFeatureItem(icon: "icloud.fill", text: "onboarding.search.features.sync")
                OnboardingFeatureItem(icon: "lock.shield.fill", text: "onboarding.search.features.secure")
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateResults = true
            }
        }
    }
}

struct ResultCard: View {
    let title: String
    let description: String
    let source: String
    let delay: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(source)
                .font(.system(size: 8, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .cornerRadius(4)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground).opacity(0.5)))
    }
}

struct OnboardingFeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .font(.headline)
            Text(LanguageManager.shared.localized(text))
                .font(.caption)
                .lineLimit(2)
        }
    }
}

#Preview {
    SearchFeaturesPage()
        .preferredColorScheme(.dark)
}
