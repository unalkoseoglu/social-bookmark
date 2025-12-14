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
                        Text("Medium Preview")  // "Önizleme" vurgusu
                            .font(.headline)
                        Spacer()
                        
                        // PAYWALL BADGE ← YENİ
                        if !post.hasFullContent {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                Text("Önizleme")
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
            
            // Görsel (varsa)
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if post.imageURL != nil {
                // Görsel yükleniyor
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Görsel yükleniyor...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
            
            // Başlık
            Text(post.title)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            // Subtitle (EN ÖNEMLİ KISIM)
                    if post.hasSubtitle {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(post.subtitle)
                                .font(.body)
                                .foregroundStyle(.primary)  // Vurgu
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Kısmi içerik varsa göster
                            if post.hasFullContent {
                                Text(post.fullContent)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(isExpanded ? nil : 3)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                if post.fullContent.count > 200 {
                                    Button(action: { isExpanded.toggle() }) {
                                        Text(isExpanded ? "Daha az" : "Daha fazla")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }
                            }}
                        }
                            Divider()
                            
                            // "Medium'da Aç" butonu ← YENİ
                                    Link(destination: post.originalURL) {
                                        HStack {
                                            Image(systemName: "arrow.up.right.square.fill")
                                            Text("Medium'da Tam Makaleyi Oku")
                                                .fontWeight(.medium)
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.green)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
            
            Divider()
                            
                            
            
            // Yazar bilgisi
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        // Okuma süresi
                        if !post.readTimeText.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text(post.readTimeText)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        
                        // Tarih
                        if let relativeDate = post.relativeDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(relativeDate)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            // İstatistikler (varsa)
            if !post.formattedClaps.isEmpty {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "hands.clap.fill")
                            .foregroundStyle(.green)
                        Text(post.formattedClaps)
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                }
            }
            
            // Medium badge
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.green)
                Text("Medium")
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
