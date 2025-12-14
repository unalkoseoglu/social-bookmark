import SwiftUI

/// Bookmark kaynak türleri
/// Her sosyal platform için özelleştirilmiş görünüm
enum BookmarkSource: String, CaseIterable, Identifiable, Codable {
    case twitter = "Twitter"
    case reddit = "Reddit"
    case linkedin = "LinkedIn"
    case medium = "Medium"
    case youtube = "YouTube"
    case instagram = "Instagram"
    case github = "GitHub"
    case article = "Article"
    case other = "Other"
    
    var id: String { rawValue }
    
    /// Görünen isim
    var displayName: String {
        rawValue
    }
    
    /// Platform emoji'si
    var emoji: String {
        switch self {
        case .twitter: return "🐦"
        case .reddit: return "🤖"
        case .linkedin: return "💼"
        case .medium: return "📝"
        case .youtube: return "▶️"
        case .instagram: return "📷"
        case .github: return "💻"
        case .article: return "📄"
        case .other: return "🔗"
        }
    }
    
    /// SF Symbol ikonu
    var systemIcon: String {
        switch self {
        case .twitter: return "bird"
        case .reddit: return "bubble.left.and.bubble.right"
        case .linkedin: return "briefcase.fill"
        case .medium: return "text.alignleft"
        case .youtube: return "play.rectangle.fill"
        case .instagram: return "camera.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .article: return "doc.text"
        case .other: return "link"
        }
    }
    
    /// Platform rengi
    var color: Color {
        switch self {
        case .twitter: return .blue
        case .reddit: return .orange
        case .linkedin: return Color(red: 0, green: 0.47, blue: 0.71)
        case .medium: return .black
        case .youtube: return .red
        case .instagram: return Color(red: 0.88, green: 0.19, blue: 0.42)
        case .github: return Color(red: 0.1, green: 0.1, blue: 0.1)
        case .article: return .gray
        case .other: return .secondary
        }
    }
    
    /// URL'den kaynak türünü tahmin et
    static func detect(from urlString: String) -> BookmarkSource {
        let lowercased = urlString.lowercased()
        
        if lowercased.contains("twitter.com") || lowercased.contains("x.com") {
            return .twitter
        } else if lowercased.contains("reddit.com") {
            return .reddit
        } else if lowercased.contains("linkedin.com") {
            return .linkedin
        } else if lowercased.contains("medium.com") {
            return .medium
        } else if lowercased.contains("youtube.com") || lowercased.contains("youtu.be") {
            return .youtube
        } else if lowercased.contains("instagram.com") {
            return .instagram
        } else if lowercased.contains("github.com") {
            return .github
        }
        
        // Genel makale siteleri
        let articleDomains = ["blog", "news", "article", "post", "dev.to", "hashnode"]
        if articleDomains.contains(where: { lowercased.contains($0) }) {
            return .article
        }
        
        return .other
    }
}
