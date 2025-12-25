//
//  EnhancedBookmarkRow.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 21.12.2025.
//
//  ✅ DÜZELTME: Cloud image (imageUrls) desteği eklendi
//

import SwiftUI

struct EnhancedBookmarkRow: View {
    let bookmark: Bookmark
    
    @State private var loadedImage: UIImage?
    @State private var isLoadingImage = false
    
    // MARK: - Computed Properties
    
    private var contentPreview: String {
        if !bookmark.note.isEmpty {
            return bookmark.note
        } else if let extractedText = bookmark.extractedText, !extractedText.isEmpty {
            return extractedText
        } else if let url = bookmark.url {
            return url
        }
        return String(localized: "bookmark.no_content")
    }
    
    /// Local veya cloud'dan yüklenmiş görsel
    private var displayImage: UIImage? {
        // Önce local kontrol
        if let imageData = bookmark.imageData, let image = UIImage(data: imageData) {
            return image
        }
        // Sonra cloud'dan yüklenmiş
        return loadedImage
    }
    
    /// Görsel yüklenmesi gerekiyor mu?
    private var needsImageLoad: Bool {
        bookmark.imageData == nil &&
        loadedImage == nil &&
        bookmark.imageUrls?.isEmpty == false
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            thumbnailView
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                titleView
                contentView
                metaInfoView
            }
            
            Spacer(minLength: 0)
            
            // Status
            statusIndicator
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .task {
            await loadImageIfNeeded()
        }
    }
    
    // MARK: - Thumbnail View
    
    private var thumbnailView: some View {
        Group {
            if let image = displayImage {
                // Local veya yüklenmiş görsel
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoadingImage {
                // Yükleniyor
                ZStack {
                    Color(.systemGray5)
                    ProgressView()
                        .scaleEffect(0.8)
                }
            } else {
                // Placeholder - kaynak ikonu
                ZStack {
                    bookmark.source.color.opacity(0.15)
                    Text(bookmark.source.emoji)
                        .font(.title2)
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
    
    // MARK: - Title View
    
    private var titleView: some View {
        Text(bookmark.title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .lineLimit(2)
            .foregroundStyle(.primary)
    }
    
    // MARK: - Content Preview
    
    private var contentView: some View {
        Text(contentPreview)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
    }
    
    // MARK: - Meta Info
    
    private var metaInfoView: some View {
        HStack(spacing: 6) {
            // Source
            HStack(spacing: 3) {
                Text(bookmark.source.emoji)
                    .font(.caption2)
                Text(bookmark.source.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text("•")
                .font(.caption2)
                .foregroundStyle(.quaternary)
            
            // Date
            Text(bookmark.relativeDate)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            
            // Favorite
            if bookmark.isFavorite {
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
            
            // Image count
            if let imagesData = bookmark.imagesData, imagesData.count > 1 {
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                
                HStack(spacing: 2) {
                    Image(systemName: "photo.stack")
                        .font(.caption2)
                    Text("\(imagesData.count)")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            } else if let imageUrls = bookmark.imageUrls, imageUrls.count > 1 {
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                
                HStack(spacing: 2) {
                    Image(systemName: "photo.stack")
                        .font(.caption2)
                    Text("\(imageUrls.count)")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Status Indicator
    
    private var statusIndicator: some View {
        VStack(spacing: 4) {
            if !bookmark.isRead {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.top, 2)
    }
    
    // MARK: - Image Loading
    
    private func loadImageIfNeeded() async {
        guard needsImageLoad else { return }
        guard let firstImagePath = bookmark.imageUrls?.first else { return }
        
        await MainActor.run { isLoadingImage = true }
        
        let image = await ImageUploadService.shared.loadImage(from: firstImagePath)
        
        await MainActor.run {
            loadedImage = image
            isLoadingImage = false
        }
    }
}

// MARK: - Preview

#Preview("With Image") {
    List {
        EnhancedBookmarkRow(
            bookmark: Bookmark(
                title: "SwiftUI ile Modern iOS Uygulama Geliştirme Rehberi",
                url: "https://developer.apple.com/swiftui",
                note: "Apple'ın modern UI framework'ü SwiftUI ile ilgili kapsamlı dokümantasyon ve örnekler içeren resmi kaynak.",
                source: .article,
                isRead: false,
                tags: ["Swift", "iOS", "SwiftUI"]
            )
        )
        
        EnhancedBookmarkRow(
            bookmark: Bookmark(
                title: "Kısa başlık",
                url: nil,
                note: "",
                source: .twitter,
                isRead: true,
                tags: []
            )
        )
    }
}
