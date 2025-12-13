import Foundation
import SwiftUI

/// Bookmark kaynaklarını temsil eden enum
/// Codable: JSON'a çevrilebilir (iCloud sync için gerekli)
/// CaseIterable: Tüm case'leri döngüde kullanmak için
enum BookmarkSource: String, Codable, CaseIterable {
    case twitter = "Twitter/X"
    case medium = "Medium"
    case reddit = "Reddit"
    case blog = "Blog"
    case article = "Article"
    case youtube = "YouTube"
    case github = "GitHub"
    case other = "Other"
    
    // MARK: - Display Properties
    
    /// Her kaynak için emoji icon
    var emoji: String {
        switch self {
        case .twitter:
            return "𝕏"
        case .medium:
            return "Ⓜ️"
        case .reddit:
            return "🔴"
        case .blog:
            return "📝"
        case .article:
            return "📄"
        case .youtube:
            return "▶️"
        case .github:
            return "⚙️"
        case .other:
            return "🔖"
        }
    }
    
    /// Her kaynak için tema rengi
    var color: Color {
        switch self {
        case .twitter:
            return .blue
        case .medium:
            return .green
        case .reddit:
            return .orange
        case .blog:
            return .purple
        case .article:
            return .gray
        case .youtube:
            return .red
        case .github:
            return .primary
        case .other:
            return .secondary
        }
    }
    
    /// Gösterim için emoji + isim
    var displayName: String {
        "\(emoji) \(rawValue)"
    }
}

// MARK: - URL Pattern Matching

extension BookmarkSource {
    /// URL'den otomatik kaynak tespit et
    /// Örnek: "twitter.com" içeriyorsa -> .twitter
    static func detect(from urlString: String) -> BookmarkSource {
        let lowercased = urlString.lowercased()
        
        if lowercased.contains("twitter.com") || lowercased.contains("x.com") {
            return .twitter
        } else if lowercased.contains("medium.com") {
            return .medium
        } else if lowercased.contains("reddit.com") {
            return .reddit
        } else if lowercased.contains("youtube.com") || lowercased.contains("youtu.be") {
            return .youtube
        } else if lowercased.contains("github.com") {
            return .github
        } else if lowercased.contains("blog") {
            return .blog
        } else {
            return .other
        }
    }
}

// MARK: - Hashable & Identifiable (Picker için gerekli)

extension BookmarkSource: Hashable, Identifiable {
    var id: String { rawValue }
}
