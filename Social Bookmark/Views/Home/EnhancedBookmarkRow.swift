//
//  EnhancedBookmarkRow.swift
//  Social Bookmark
//
//  AsyncImage ile native lazy loading
//  Main thread'i bloke etmez
//

import SwiftUI

struct EnhancedBookmarkRow: View {
    let bookmark: Bookmark
    var category: Category? = nil
    
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
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            thumbnailView
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(bookmark.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                // Content
                Text(contentPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                // Meta info
                HStack(spacing: 6) {
                    Text(bookmark.source.emoji)
                        .font(.caption2)
                    Text(bookmark.source.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if !bookmark.relativeDate.isEmpty {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                        Text(bookmark.relativeDate)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if bookmark.isFavorite {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    
                    if let imageUrls = bookmark.imageUrls, imageUrls.count > 1 {
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
                    Spacer()
                    if let category = category {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.primary)
                        Text(category.name)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Status indicator
            if !bookmark.isRead {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Thumbnail View
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let imageData = bookmark.imageData,
           let uiImage = UIImage(data: imageData) {
            // Local image var - direkt göster
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 0.5)
                )
        } else if let imageUrl = bookmark.imageUrls?.first {
            // Cloud-only image - lazy load
            CachedAsyncImage(url: imageUrl) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    Color(.systemGray6)
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 0.5)
            )
        } else {
            // Fallback - emoji
            ZStack {
                bookmark.source.color.opacity(0.15)
                Text(bookmark.source.emoji)
                    .font(.title2)
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 0.5)
            )
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
                note: "Apple'ın modern UI framework'ü SwiftUI ile ilgili kapsamlı dokümantasyon.",
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
