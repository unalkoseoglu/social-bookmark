import SwiftUI

/// Reddit post önizleme komponenti
/// AddBookmarkView içinde kullanılır - Twitter preview ile aynı stil
struct RedditPreviewView: View {
    let post: RedditPost
    
    // Görsel verileri (ViewModel'den gelir)
    var imagesData: [Data] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık
            HStack {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.orange)
                Text("Reddit Önizleme")
                    .font(.headline)
                Spacer()
                
                // Görsel sayısı badge
                if imagesData.count > 1 {
                    Text("\(imagesData.count) görsel")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
            
            Divider()
            
            // Subreddit ve yazar bilgisi
            HStack {
                Text("r/\(post.subreddit)")
                    .font(.headline)
                    .foregroundStyle(.orange)
                
                Spacer()
                
                Text(post.authorDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Post başlığı
            Text(post.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
            
            // Selftext (varsa)
            if !post.selfText.isEmpty {
                Text(post.selfText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Görseller galerisi
            if !imagesData.isEmpty {
                redditImagesGallery
            } else if post.imageURL != nil {
                // Tek görsel - AsyncImage ile
                if let imageURL = post.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 180)
                                .overlay {
                                    ProgressView()
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 140)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            
            // İstatistikler
            HStack(spacing: 16) {
                Label(formatCount(post.score), systemImage: "arrow.up")
                    .foregroundStyle(.orange)
                Label("\(formatCount(post.commentCount)) yorum", systemImage: "bubble.right")
                    .foregroundStyle(.blue)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Görsel Galerisi
    
    /// Çoklu görsel galerisi (Twitter ile aynı layout)
    @ViewBuilder
    private var redditImagesGallery: some View {
        let images = imagesData.compactMap { UIImage(data: $0) }
        
        if images.count == 1 {
            // Tek görsel - tam genişlik
            Image(uiImage: images[0])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if images.count == 2 {
            // 2 görsel - yan yana
            HStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        } else if images.count == 3 {
            // 3 görsel - 1 büyük + 2 küçük
            HStack(spacing: 4) {
                Image(uiImage: images[0])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(spacing: 4) {
                    ForEach(1..<3, id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 98)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } else if images.count >= 4 {
            // 4+ görsel - 2x2 grid
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<2, id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                HStack(spacing: 4) {
                    ForEach(2..<min(4, images.count), id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                // 4'ten fazla görsel varsa sayı göster
                                if index == 3 && images.count > 4 {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.black.opacity(0.5))
                                    Text("+\(images.count - 4)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Preview

#Preview("Text Post") {
    RedditPreviewView(
        post: RedditPost(
            title: "I built a SwiftUI bookmark manager!",
            author: "swiftdev",
            subreddit: "iOSProgramming",
            selfText: "Here's how I structured the data models and handled asynchronous fetching. It uses SwiftData for persistence and supports multiple platforms.",
            imageURL: nil,
            score: 4200,
            commentCount: 182,
            originalURL: URL(string: "https://reddit.com/r/iOSProgramming/comments/abc123")!
        )
    )
    .padding()
}

#Preview("Image Post") {
    RedditPreviewView(
        post: RedditPost(
            title: "Beautiful sunset over the Golden Gate Bridge",
            author: "photographer",
            subreddit: "pics",
            selfText: "",
            imageURL: URL(string: "https://i.redd.it/example.jpg"),
            score: 12500,
            commentCount: 342,
            originalURL: URL(string: "https://reddit.com/r/pics/comments/def456")!
        )
    )
    .padding()
}

#Preview("Gallery Post - With Images") {
    RedditPreviewView(
        post: RedditPost(
            title: "My photography collection from Iceland trip",
            author: "traveler",
            subreddit: "itookapicture",
            selfText: "Spent 2 weeks exploring Iceland. Here are my favorite shots.",
            imageURL: URL(string: "https://i.redd.it/img1.jpg"),
            score: 8900,
            commentCount: 256,
            originalURL: URL(string: "https://reddit.com/r/itookapicture/comments/ghi789")!
        ),
        imagesData: [] // Normalde ViewModel'den gelir
    )
    .padding()
}
