import SwiftUI

/// LinkedIn post önizleme komponenti
/// Güncellenmiş: Kısmi veri ve hata durumu desteği
struct LinkedInPreviewView: View {
    let post: LinkedInPost
    let imageData: Data?
    var onOpenInBrowser: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundStyle(.cyan)
                Text("linkedin.preview.title")
                    .font(.headline)
                Spacer()
                
                // Durum ikonu
                if post.isPartial {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            
            Divider()
            
            // Hata uyarısı (kısmi veri durumunda)
            if post.isPartial, let errorMessage = post.userFacingErrorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Yazar bilgisi
            HStack(spacing: 12) {
                // Profil Görseli Yer tutucu (LinkedIn API kısıtlıdır)
                Circle()
                    .fill(Color.cyan.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundStyle(.cyan)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    if !post.authorTitle.isEmpty {
                        Text(post.authorTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            // Post içeriği
            Text(post.content)
                .font(.subheadline)
                .lineLimit(post.isPartial ? 4 : 10)
                .fixedSize(horizontal: false, vertical: true)
            
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
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    default:
                        EmptyView()
                    }
                }
            }
            
            // Tarayıcıda aç butonu (Hata durumunda çıkar)
            if post.isPartial {
                Button {
                    onOpenInBrowser?()
                } label: {
                    HStack {
                        Text("error.action.open_browser")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.cyan)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
// MARK: - Preview

#Preview("Normal Post") {
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

#Preview("Partial Data (Auth Required)") {
    LinkedInPreviewView(
        post: LinkedInPost(
            title: "Ahmet Kahrimanoglu - LinkedIn Post",
            content: "⚠️ Bu içeriği görüntülemek için LinkedIn'de giriş yapılması gerekiyor.\n\n📱 Tarayıcıda açarak içeriği görebilirsiniz.",
            authorName: "Ahmet Kahrimanoglu",
            authorTitle: "",
            imageURL: nil,
            originalURL: URL(string: "https://linkedin.com/posts/ahmet-kahrimanoglu_flutter")!,
            isPartial: true,
            errorType: .authRequired
        ),
        imageData: nil,
        onOpenInBrowser: {
            print("Open in browser tapped")
        }
    )
    .padding()
}

#Preview("Partial Data (Bot Detected)") {
    LinkedInPreviewView(
        post: LinkedInPost(
            title: "LinkedIn Activity",
            content: "⚠️ LinkedIn erişimi geçici olarak kısıtlandı.\n\n🔄 Lütfen birkaç dakika sonra tekrar deneyin.",
            authorName: "LinkedIn User",
            authorTitle: "",
            imageURL: nil,
            originalURL: URL(string: "https://linkedin.com/feed/update/urn:li:activity:123")!,
            isPartial: true,
            errorType: .botDetected
        ),
        imageData: nil
    )
    .padding()
}
