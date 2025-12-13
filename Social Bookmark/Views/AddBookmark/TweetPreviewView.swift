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
                Text("Tweet Önizleme")
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
                        .fontWeight(.semibold)
                    Text("@\(tweet.authorUsername)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Tweet metni
            Text(tweet.text)
                .font(.body)
                .lineLimit(8)
                .fixedSize(horizontal: false, vertical: true)
            
            // ✅ GÖRSEL - DÜZELTİLDİ
            if let imageData = imageData {
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onAppear {
                            print("✅ TweetPreviewView: Görsel gösteriliyor (\(imageData.count) bytes)")
                        }
                } else {
                    // Data var ama UIImage oluşturulamadı
                    Text("⚠️ Görsel yüklenemedi")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            } else if tweet.hasMedia {
                // Görsel yükleniyor placeholder
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
            
            // İstatistikler
            HStack(spacing: 20) {
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
