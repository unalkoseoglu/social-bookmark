//
//  EnhancedBookmarkRow.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 21.12.2025.
//

import SwiftUI


struct EnhancedBookmarkRow: View {
    let bookmark: Bookmark
    
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
    
    var body: some View {
        
        HStack(alignment: .center, spacing: 12) {
            // Thumbnail or Source Icon
            Group {
                if let imageData = bookmark.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        bookmark.source.color.opacity(0.15)
                        Text(bookmark.source.emoji)
                            .font(.title2)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(bookmark.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                // Content Preview (3-4 satır)
                Text(contentPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                
                // Meta Info
                HStack(alignment: .center, spacing: 8) {
                    // Source Badge
                    HStack(spacing: 4) {
                        Text(bookmark.source.emoji)
                            .font(.caption2)
                        Text(bookmark.source.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Text(bookmark.relativeDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                }
            }
            
            // Status Indicators
            VStack(alignment: .center, spacing: 6) {
                if !bookmark.isRead {
                    Circle()
                        .fill(.orange)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(.top, 4)
        }
        
        .contentShape(Rectangle())
    }
}
