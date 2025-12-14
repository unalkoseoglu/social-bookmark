import Foundation

/// LinkedIn post servisi
/// NOT: LinkedIn API gerektiriyor, bu yüzden web scraping kullanıyoruz
final class LinkedInService {
    static let shared = LinkedInService()
    private init() {}
    
    // MARK: - Public Methods
    
    func isLinkedInURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("linkedin.com/posts/") ||
               lowercased.contains("linkedin.com/feed/update/") ||
               lowercased.contains("lnkd.in/")
    }
    
    func fetchPost(from urlString: String) async throws -> LinkedInPost {
        print("🔵 LinkedIn: Başlangıç URL: \(urlString)")
        
        // 1. Kısa URL'leri expand et
        var finalURL = urlString
        if urlString.contains("lnkd.in/") {
            print("🔵 LinkedIn: Kısa URL tespit edildi, expand ediliyor...")
            if let expanded = try await expandShortURL(urlString) {
                finalURL = expanded
                print("✅ LinkedIn: Expanded URL: \(finalURL)")
            }
        }
        
        guard let url = URL(string: finalURL) else {
            throw LinkedInError.invalidURL
        }
        
        // 2. HTML içeriğini çek
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        
        // LinkedIn web scraping için gerekli header'lar
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                        forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml",
                        forHTTPHeaderField: "Accept")
        
        print("🔵 LinkedIn: HTML çekiliyor...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LinkedInError.networkError
        }
        
        print("🔵 LinkedIn: HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw LinkedInError.httpError(httpResponse.statusCode)
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw LinkedInError.parseError
        }
        
        print("🔵 LinkedIn: HTML alındı (\(html.count) karakter)")
        
        // 3. HTML'den bilgileri çıkar
        let post = try parseLinkedInHTML(html, originalURL: url)
        
        print("✅ LinkedIn: Post oluşturuldu")
        print("  - Başlık/İçerik: \(post.title.prefix(50))...")
        print("  - Yazar: \(post.authorName)")
        
        return post
    }
    
    // MARK: - HTML Parser
    
    private func parseLinkedInHTML(_ html: String, originalURL: URL) throws -> LinkedInPost {
        print("🔵 LinkedIn: HTML parse ediliyor...")
        
        // Open Graph meta tags'lerini çıkar (en güvenilir yöntem)
        let title = extractOGTag(from: html, property: "og:title") ??
                   extractTitle(from: html) ??
                   "LinkedIn Post"
        
        var description = extractOGTag(from: html, property: "og:description") ??
                         extractDescription(from: html) ??
                         ""
        
        // Eğer meta description yoksa, HTML'den post content'ini çıkarmaya çalış
        if description.isEmpty {
            description = extractPostContent(from: html)
        }
        
        let imageURL = extractOGTag(from: html, property: "og:image")
            .flatMap { URL(string: $0) }
        
        // Yazar bilgisini çıkar
        var authorName = "LinkedIn User"
        var authorTitle = ""
        
        // Pattern 1: "Name · Job Title" formatı
        if let namePattern = extractPattern(from: html, pattern: #"<title>([^·]+)·([^<]+)</title>"#) {
            let parts = namePattern.components(separatedBy: "·")
            if parts.count >= 2 {
                authorName = parts[0].trimmingCharacters(in: .whitespaces)
                authorTitle = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Pattern 2: JSON-LD structured data
        if authorName == "LinkedIn User",
           let jsonLD = extractJSONLD(from: html) {
            authorName = jsonLD["author"] as? String ?? authorName
        }
        
        print("🔵 LinkedIn: Parse tamamlandı")
        print("  - Başlık: \(title.prefix(100))...")
        print("  - İçerik: \(description.isEmpty ? "boş" : description.prefix(100) + "...")")
        print("  - Yazar: \(authorName)")
        print("  - Görsel: \(imageURL?.absoluteString ?? "yok")")
        
        return LinkedInPost(
            title: cleanText(title),
            content: cleanText(description),
            authorName: cleanText(authorName),
            authorTitle: cleanText(authorTitle),
            imageURL: imageURL,
            originalURL: originalURL
        )
    }
    
    // MARK: - HTML Extraction Helpers
    
    private func extractOGTag(from html: String, property: String) -> String? {
        let pattern = #"<meta[^>]*property=["']\#(property)["'][^>]*content=["']([^"']+)["']"#
        return extractPattern(from: html, pattern: pattern)
    }
    
    private func extractTitle(from html: String) -> String? {
        let pattern = #"<title>([^<]+)</title>"#
        return extractPattern(from: html, pattern: pattern)
    }
    
    private func extractDescription(from html: String) -> String? {
        let pattern = #"<meta[^>]*name=["']description["'][^>]*content=["']([^"']+)["']"#
        return extractPattern(from: html, pattern: pattern)
    }
    
    private func extractPostContent(from html: String) -> String {
        // LinkedIn post content'ini JSON data'dan çıkarmaya çalış
        // Structual data bulunmuyorsa, text nodes'lardan topla
        
        var content = ""
        
        // Yöntem 1: JSON-LD Article'dan extract et
        if let jsonLD = extractJSONLD(from: html),
           let articleBody = jsonLD["articleBody"] as? String {
            content = articleBody
        }
        
        // Yöntem 2: Specific paragraf patterns
        if content.isEmpty {
            // LinkedIn artık JavaScript ile render ettiği için,
            // statik HTML'de post body text'ini bulmak zor
            // Alternatif: hashtag'ler ve mention'ları çıkar
            let hashtagPattern = #"#\w+"#
            if let regex = try? NSRegularExpression(pattern: hashtagPattern),
               let url = URL(string: html) {
                let range = NSRange(html.startIndex..<html.endIndex, in: html)
                let matches = regex.matches(in: html, range: range)
                let hashtags = matches.compactMap { match -> String? in
                    if let range = Range(match.range, in: html) {
                        return String(html[range])
                    }
                    return nil
                }
                if !hashtags.isEmpty {
                    content = hashtags.joined(separator: " ")
                }
            }
        }
        
        return content
    }
    
    private func extractPattern(from html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1,
              let contentRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        return String(html[contentRange])
    }
    
    private func extractJSONLD(from html: String) -> [String: Any]? {
        let pattern = #"<script type="application/ld\+json">([^<]+)</script>"#
        guard let jsonString = extractPattern(from: html, pattern: pattern),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
    
    private func cleanText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - URL Helpers
    
    private func expandShortURL(_ urlString: String) async throws -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           let location = httpResponse.url?.absoluteString {
            return location
        }
        
        return nil
    }
    
    // MARK: - Error Types
    
    enum LinkedInError: LocalizedError {
        case invalidURL
        case networkError
        case httpError(Int)
        case parseError
        case authRequired
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Geçersiz LinkedIn URL'i"
            case .networkError:
                return "LinkedIn isteği başarısız oldu"
            case .httpError(let code):
                return "LinkedIn HTTP hatası (kod: \(code))"
            case .parseError:
                return "LinkedIn içeriği çözümlenemedi"
            case .authRequired:
                return "LinkedIn girişi gerekli (bazı postlar için)"
            }
        }
    }
}

// MARK: - LinkedInPost Model

struct LinkedInPost: Equatable {
    let title: String
    let content: String
    let authorName: String
    let authorTitle: String
    let imageURL: URL?
    let originalURL: URL
    
    var hasContent: Bool {
        !content.isEmpty
    }
    
    var displayText: String {
        if !content.isEmpty && content != title {
            return content
        }
        return title
    }
    
    var authorDisplay: String {
        if !authorTitle.isEmpty {
            return "\(authorName) • \(authorTitle)"
        }
        return authorName
    }
}
