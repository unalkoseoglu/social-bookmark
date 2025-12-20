import SwiftUI

/// Medium post önizleme komponenti
struct MediumPreviewView: View {
    let post: MediumPost
    let imageData: Data?
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.green)
                Text("medium.preview.title")
                    .font(.headline)
                Spacer()
                
                // PAYWALL BADGE
                if !post.hasFullContent {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                        Text("medium.preview.badge")
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
                }
                
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
            
            Divider()
            
            // Görsel
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let imageURL = post.imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            
            // Metin İçeriği
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if !post.subtitle.isEmpty {
                    Text(post.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 3)
                }
            }
            
            // Alt Bilgiler
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 8) {
                        if post.readTime > 0 {
                            Text("medium.read_time \(post.readTime)")
                        }
                        
                        if let date = post.publishedDate {
                            Text("•")
                            Text(date, style: .date)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if post.claps > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "hands.clap.fill")
                        Text("\(post.claps)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview("With Image") {
    MediumPreviewView(
        post: MediumPost(
            title: "Building Production-Ready iOS Apps with SwiftUI",
            subtitle: "A comprehensive guide to creating scalable, maintainable iOS applications using modern SwiftUI patterns and best practices.", fullContent: "",
            authorName: "John Developer",
            authorURL: URL(string: "https://medium.com/@johndoe"),
            imageURL: URL(string: "https://example.com/image.jpg"),
            readTime: 12,
            publishedDate: Date().addingTimeInterval(-86400 * 3),
            claps: 2450,
            originalURL: URL(string: "https://medium.com/@johndoe/building-ios-apps")!
        ),
        imageData: nil
    )
    .padding()
}

#Preview("Text Only") {
    MediumPreviewView(
        post: MediumPost(
            title: "Understanding Swift Concurrency",
            subtitle: "Deep dive into async/await and structured concurrency.", fullContent: "",
            authorName: "Jane Swift",
            authorURL: nil,
            imageURL: nil,
            readTime: 8,
            publishedDate: Date().addingTimeInterval(-3600 * 5),
            claps: 856,
            originalURL: URL(string: "https://medium.com/@janeswift/concurrency")!
        ),
        imageData: nil
    )
    .padding()
}

#Preview("Minimal Info") {
    MediumPreviewView(
        post: MediumPost(
            title: "Quick iOS Tip",
            subtitle: "", fullContent: "",
            authorName: "Developer",
            authorURL: nil,
            imageURL: nil,
            readTime: 0,
            publishedDate: nil,
            claps: 0,
            originalURL: URL(string: "https://medium.com/@dev/tip")!
        ),
        imageData: nil
    )
    .padding()
}
