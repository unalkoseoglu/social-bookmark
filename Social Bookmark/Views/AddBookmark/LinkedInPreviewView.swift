import SwiftUI

/// LinkedIn post önizleme komponenti
struct LinkedInPreviewView: View {
    let post: LinkedInPost
    let imageData: Data?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.cyan)
                Text("LinkedIn Önizleme")
                    .font(.headline)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
            
            Divider()
            
            // Yazar bilgisi
            VStack(alignment: .leading, spacing: 4) {
                Text(post.authorName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                if !post.authorTitle.isEmpty {
                    Text(post.authorTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // İçerik
            Text(post.displayText)
                .font(.body)
                .lineLimit(8)
                .fixedSize(horizontal: false, vertical: true)
            
            // Görsel
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if post.imageURL != nil {
                // Görsel yükleniyor
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 120)
                    .overlay {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Görsel yükleniyor...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
            
            // LinkedIn badge
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundStyle(.cyan)
                Text("LinkedIn")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview("Text Post") {
    LinkedInPreviewView(
        post: LinkedInPost(
            title: "Excited to share my latest project!",
            content: "After months of hard work, I'm thrilled to announce the launch of our new iOS app. Built with SwiftUI and leveraging the latest Apple technologies.",
            authorName: "John Developer",
            authorTitle: "Senior iOS Engineer at Tech Corp",
            imageURL: nil,
            originalURL: URL(string: "https://linkedin.com/posts/johndoe_ios-swiftui-development")!
        ),
        imageData: nil
    )
    .padding()
}

#Preview("Post with Image") {
    LinkedInPreviewView(
        post: LinkedInPost(
            title: "Check out our new office!",
            content: "We've moved to a new space in downtown. Excited for this next chapter!",
            authorName: "Jane Manager",
            authorTitle: "CEO at Startup Inc",
            imageURL: URL(string: "https://example.com/image.jpg"),
            originalURL: URL(string: "https://linkedin.com/posts/janemanager_office-startup")!
        ),
        imageData: nil
    )
    .padding()
}
