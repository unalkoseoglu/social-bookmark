import SwiftUI

/// Tweet önizleme komponenti
struct TweetPreviewView: View {
    let tweet: TwitterService.Tweet
    let imageData: Data?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık
            HStack {
                Image(systemName: "bird.fill")
                    .foregroundStyle(.blue)
                Text("tweet.preview.title")
                    .font(.headline)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
            
            Divider()
            
            // Yazar bilgisi
            HStack(spacing: 12) {
                // Avatar
                if let avatarURL = tweet.authorAvatarURL {
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            avatarPlaceholder
                        case .empty:
                            ProgressView()
                        @unknown default:
                            avatarPlaceholder
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tweet.authorName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("@\(tweet.authorUsername)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Tweet metni
            Text(tweet.text)
                .font(.body)
            
            // Görsel
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // İstatistikler
            HStack(spacing: 16) {
                Label("\(formatCount(tweet.likeCount))", systemImage: "heart.fill")
                    .foregroundStyle(.red)
                Label("\(formatCount(tweet.retweetCount))", systemImage: "arrow.2.squarepath")
                    .foregroundStyle(.green)
                Label("\(formatCount(tweet.replyCount))", systemImage: "bubble.right.fill")
                    .foregroundStyle(.blue)
            }
            .font(.caption)
            
            // Tarih
            if let date = tweet.createdAt {
                HStack {
                    Image(systemName: "calendar")
                    Text(date, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay {
                Text(String(tweet.authorName.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
