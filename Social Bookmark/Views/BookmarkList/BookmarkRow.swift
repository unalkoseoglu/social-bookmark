import SwiftUI

/// Tek bookmark satırı - Liste içinde her öğe için kullanılır
struct BookmarkRow: View {
    // MARK: - Properties
    
    /// Gösterilecek bookmark
    let bookmark: Bookmark
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Üst kısım: Emoji + Başlık + Okundu badge
            headerSection
            
            // Not varsa göster
            if bookmark.hasNote {
                noteSection
            }
            
            // URL varsa göster
            if bookmark.hasURL {
                urlSection
            }
            
            // Alt kısım: Tags + Tarih
            footerSection
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Subviews
    
    /// Üst bölüm: Emoji + Başlık
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            // Kaynak emoji
            Text(bookmark.source.emoji)
                .font(.title3)
            
            // Başlık
            Text(bookmark.title)
                .font(.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Okundu badge'i
            if bookmark.isRead {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
    }
    
    /// Not bölümü
    private var noteSection: some View {
        Text(bookmark.note)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .padding(.leading, 32) // Emoji genişliği kadar indent
    }
    
    /// URL bölümü
    private var urlSection: some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .font(.caption2)
            
            Text(bookmark.url ?? "")
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(.blue)
        .padding(.leading, 32)
    }
    
    /// Alt bölüm: Etiketler ve tarih
    private var footerSection: some View {
        HStack {
            // Etiketler
            if bookmark.hasTags {
                tagsView
            }
            
            Spacer()
            
            // Tarih
            Text(bookmark.relativeDate)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, 32)
    }
    
    /// Etiket görünümü
    private var tagsView: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag.fill")
                .font(.caption2)
            
            // İlk 3 etiketi göster
            ForEach(bookmark.tags.prefix(3), id: \.self) { tag in
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            
            // Daha fazla etiket varsa
            if bookmark.tags.count > 3 {
                Text("+\(bookmark.tags.count - 3)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("Normal Bookmark") {
    List {
        BookmarkRow(
            bookmark: Bookmark(
                title: "SwiftUI Best Practices for Production Apps",
                url: "https://developer.apple.com/documentation/swiftui",
                note: "Great article covering advanced patterns and architecture",
                source: .article,
                tags: ["Swift", "iOS", "Architecture"]
            )
        )
    }
}

#Preview("Minimal Bookmark") {
    List {
        BookmarkRow(
            bookmark: Bookmark(
                title: "Quick Twitter Thread",
                source: .twitter
            )
        )
    }
}

#Preview("Read Bookmark") {
    List {
        BookmarkRow(
            bookmark: Bookmark(
                title: "Already Read This Article",
                url: "https://medium.com/example",
                note: "Finished reading yesterday",
                source: .medium,
                isRead: true,
                tags: ["Completed"]
            )
        )
    }
}

#Preview("Multiple Bookmarks") {
    List {
        BookmarkRow(
            bookmark: Bookmark(
                title: "Twitter Thread on Async/Await",
                url: "https://twitter.com/johnsundell",
                note: "Must read",
                source: .twitter,
                tags: ["Swift", "Concurrency"]
            )
        )
        
        BookmarkRow(
            bookmark: Bookmark(
                title: "GitHub Repo: Awesome Swift",
                url: "https://github.com/awesome-swift",
                source: .github,
                isRead: true
            )
        )
        
        BookmarkRow(
            bookmark: Bookmark(
                title: "YouTube: WWDC Session",
                url: "https://youtube.com/watch?v=example",
                note: "New SwiftUI features explained",
                source: .youtube,
                tags: ["WWDC", "SwiftUI", "iOS17"]
            )
        )
    }
}
