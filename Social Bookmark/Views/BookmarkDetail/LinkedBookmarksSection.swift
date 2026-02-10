import SwiftUI
import SwiftData

struct LinkedBookmarksSection: View {
    let linkedBookmarkIds: [UUID]
    let onBookmarkSelected: (Bookmark) -> Void
    let onAddLink: () -> Void
    
    @Query private var allBookmarks: [Bookmark]
    
    // Resolve UUIDs to actual Bookmark objects
    private var linkedBookmarks: [Bookmark] {
        allBookmarks.filter { linkedBookmarkIds.contains($0.id) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(String(localized: "bookmarkDetail.linked_bookmarks"), systemImage: "link")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: onAddLink) {
                    Label(String(localized: "common.add"), systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            
            if linkedBookmarks.isEmpty {
                Text(String(localized: "bookmarkDetail.linked_bookmarks_empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(linkedBookmarks) { bookmark in
                            Button {
                                onBookmarkSelected(bookmark)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bookmark.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.blue)
                                        
                                        Text(bookmark.source.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Text(bookmark.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer(minLength: 0)
                                    
                                    if !bookmark.note.isEmpty {
                                        Text(bookmark.note)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(12)
                                .frame(width: 160, height: 120)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
