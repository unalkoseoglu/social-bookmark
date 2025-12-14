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
                Text("LinkedIn Önizleme")
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
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
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
            if post.hasContent && !post.content.contains("⚠️") {
                Text(post.displayText)
                    .font(.body)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Görsel
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if post.imageURL != nil && !post.isPartial {
                // Görsel yükleniyor (sadece kısmi veri değilse)
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
            
            // Alt bilgi ve aksiyonlar
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundStyle(.cyan)
                Text("LinkedIn")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Tarayıcıda aç butonu
                if let onOpenInBrowser {
                    Button {
                        onOpenInBrowser()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "safari")
                            Text("Tarayıcıda Aç")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(post.isPartial ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
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
