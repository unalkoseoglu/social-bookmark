import SwiftUI

/// Bookmark kaynak türleri
/// Her sosyal platform için özelleştirilmiş görünüm
enum BookmarkSource: String, CaseIterable, Identifiable, Codable {
    case twitter = "x.com"
    case reddit = "Reddit"
    case linkedin = "LinkedIn"
    case medium = "Medium"
    case youtube = "YouTube"
    case instagram = "Instagram"
    case github = "GitHub"
    case article = "Article"
    case document = "Document"
    case other = "Other"
    
    var id: String { rawValue }
    
    /// Görünen isim
    var displayName: String {
        switch self {
        case .twitter: return String(localized: "source.twitter")
        case .reddit: return String(localized: "source.reddit")
        case .linkedin: return String(localized: "source.linkedin")
        case .medium: return String(localized: "source.medium")
        case .youtube: return String(localized: "source.youtube")
        case .instagram: return String(localized: "source.instagram")
        case .github: return String(localized: "source.github")
        case .article: return String(localized: "source.article")
        case .document: return String(localized: "source.document")
        case .other: return String(localized: "source.other")
        }
    }
    
    /// Platform emoji'si
    var emoji: String {
        switch self {
        case .twitter:
            return "𝕏"
        case .reddit:
            return "👽"
        case .linkedin:
            return "💼"
        case .medium:
            return "✍️"
        case .youtube:
            return "📺"
        case .instagram:
            return "📸"
        case .github:
            return "🧩"
        case .article:
            return "📰"
        case .document:
            return "📄"
        case .other:
            return "🔗"
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
        case .document: return "doc.fill"
        case .other: return "link"
        }
    }
    
    var color: Color {
        switch self {
        case .twitter:
            return Color(hex: "#1D9BF0")

        case .reddit:
            return Color(hex: "#FF4500")

        case .linkedin:
            return Color(hex: "#0A66C2")

        case .medium:
            return .primary

        case .youtube:
            return Color(hex: "#FF0000")

        case .instagram:
            return Color(hex: "#E1306C")

        case .github:
            return Color(hex: "#24292F")

        case .article:
            return Color(hex: "#6B7280")

        case .document:
            return Color(hex: "#10B981") // Emerald Green

        case .other:
            return .secondary
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
