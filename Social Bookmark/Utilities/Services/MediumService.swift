import Foundation

/// Medium post servisi - Tam içerik çekme desteği ile
final class MediumService {
    static let shared = MediumService()
    private init() {}
    
    // MARK: - Public Methods
    
    func isMediumURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("medium.com") ||
               lowercased.contains("towardsdatascience.com") ||
               lowercased.contains("betterprogramming.pub") ||
               lowercased.contains("levelup.gitconnected.com")
    }
    
    func fetchPost(from urlString: String) async throws -> MediumPost {
        print("📗 Medium: Başlangıç URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw MediumError.invalidURL
        }
        
        // 1. HTML içeriğini çek
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                        forHTTPHeaderField: "User-Agent")
        
        print("📗 Medium: HTML çekiliyor...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MediumError.networkError
        }
        
        print("📗 Medium: HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw MediumError.httpError(httpResponse.statusCode)
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw MediumError.parseError
        }
        
        print("📗 Medium: HTML alındı (\(html.count) karakter)")
        
        // 2. HTML'den bilgileri çıkar
        let post = try parseMediumHTML(html, originalURL: url)
        
        print("✅ Medium: Post oluşturuldu")
        print("  - Başlık: \(post.title.prefix(50))...")
        print("  - Yazar: \(post.authorName)")
        print("  - İçerik: \(post.fullContent.count) karakter")
        
        return post
    }
    
    // MARK: - HTML Parser
    
    private func parseMediumHTML(_ html: String, originalURL: URL) throws -> MediumPost {
        print("📗 Medium: HTML parse ediliyor...")
        
        // Open Graph meta tags
        let title = extractOGTag(from: html, property: "og:title") ??
                   extractTitle(from: html) ??
                   "Medium Post"
        
        let subtitle = extractOGTag(from: html, property: "og:description") ?? ""
        
        let imageURL = extractOGTag(from: html, property: "og:image")
            .flatMap { URL(string: $0) }
        
        // TAM İÇERİK ÇIKART ← YENİ (subtitle'ı parametre olarak geç)
        let fullContent = extractFullContent(from: html, fallbackSubtitle: subtitle)
        
        // Yazar bilgisi
        var authorName = "Medium Writer"
        var authorURL: URL?
        
        // JSON-LD structured data
        if let jsonLD = extractMediumJSONLD(from: html) {
            if let author = jsonLD["author"] as? [String: Any] {
                authorName = author["name"] as? String ?? authorName
                if let urlString = author["url"] as? String {
                    authorURL = URL(string: urlString)
                }
            }
        }
        
        // Fallback: HTML meta tags
        if authorName == "Medium Writer" {
            if let metaAuthor = extractMetaTag(from: html, property: "author") {
                authorName = metaAuthor
            }
        }
        
        // Read time
        let readTime = extractReadTime(from: html)
        
        // Publication date
        let publishedDate = extractPublishedDate(from: html)
        
        // Claps
        let claps = extractClaps(from: html)
        
        print("📗 Medium: Parse tamamlandı")
        print("  - Başlık: \(title)")
        print("  - Yazar: \(authorName)")
        print("  - Okuma süresi: \(readTime) dk")
        print("  - İçerik uzunluğu: \(fullContent.count) karakter")
        
        return MediumPost(
            title: cleanText(title),
            subtitle: cleanText(subtitle),
            fullContent: cleanText(fullContent),
            authorName: cleanText(authorName),
            authorURL: authorURL,
            imageURL: imageURL,
            readTime: readTime,
            publishedDate: publishedDate,
            claps: claps,
            originalURL: originalURL
        )
    }
    
    // MARK: - Full Content Extraction ← YENİ
    
    /// Medium'un tam içeriğini çıkar
    private func extractFullContent(from html: String, fallbackSubtitle: String) -> String {
        print("📗 Medium: Tam içerik çıkarılıyor...")
        
        var paragraphs: [String] = []
        
        // Method 1: JSON embedded data içinden çek (en güvenilir)
        if let jsonContent = extractContentFromJSON(html) {
            print("  ✅ JSON'dan \(jsonContent.count) karakter çıkarıldı")
            return jsonContent
        }
        
        // Method 2: Article body paragraflarını çek
        let articlePatterns = [
            #"<article[^>]*>(.*?)</article>"#,
            #"<div[^>]*class="[^"]*section-content[^"]*"[^>]*>(.*?)</div>"#,
            #"<div[^>]*class="[^"]*post-content[^"]*"[^>]*>(.*?)</div>"#
        ]
        
        for pattern in articlePatterns {
            if let articleHTML = extractPattern(from: html, pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                paragraphs = extractParagraphs(from: articleHTML)
                if !paragraphs.isEmpty {
                    print("  ✅ Article tag'inden \(paragraphs.count) paragraf çıkarıldı")
                    break
                }
            }
        }
        
        // Method 3: Tüm <p> taglerini çek (fallback)
        if paragraphs.isEmpty {
            paragraphs = extractAllParagraphs(from: html)
            print("  ✅ Genel arama: \(paragraphs.count) paragraf bulundu")
        }
        
        // Paragrafları birleştir
        let content = paragraphs
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        
        // Çok kısa içerik varsa (muhtemelen paywall), uyarı ver
        if content.count < 500 {
            print("  ⚠️ İçerik çok kısa (\(content.count) karakter) - muhtemelen paywall")
            // fallbackSubtitle kullan ← DÜZELTİLDİ
            if !fallbackSubtitle.isEmpty {
                return fallbackSubtitle + "\n\n[İçeriğin tamamını okumak için Medium'da açın]"
            }
            return "[İçeriğin tamamını okumak için Medium'da açın]"
        }
        
        return content
    }
    
    /// JSON embedded data'dan içerik çıkar
    private func extractContentFromJSON(_ html: String) -> String? {
        // Medium sayfalarında window.__APOLLO_STATE__ veya __PRELOADED_STATE__ var
        let jsonPatterns = [
            #"window\.__APOLLO_STATE__\s*=\s*(\{.*?\});"#,
            #"window\.__PRELOADED_STATE__\s*=\s*(\{.*?\});"#
        ]
        
        for pattern in jsonPatterns {
            if let jsonString = extractPattern(from: html, pattern: pattern, options: [.dotMatchesLineSeparators]) {
                // JSON parse et
                guard let data = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                
                // Paragrafları bul
                var paragraphs: [String] = []
                findParagraphsInJSON(json, paragraphs: &paragraphs)
                
                if !paragraphs.isEmpty {
                    return paragraphs.joined(separator: "\n\n")
                }
            }
        }
        
        return nil
    }
    
    /// JSON içinde recursive olarak paragrafları ara
    private func findParagraphsInJSON(_ json: Any, paragraphs: inout [String]) {
        if let dict = json as? [String: Any] {
            // "text" veya "content" key'lerini ara
            if let text = dict["text"] as? String, text.count > 20 {
                paragraphs.append(text)
            } else if let content = dict["content"] as? String, content.count > 20 {
                paragraphs.append(content)
            }
            
            // Nested objekteleri tara
            for (_, value) in dict {
                findParagraphsInJSON(value, paragraphs: &paragraphs)
            }
        } else if let array = json as? [Any] {
            for item in array {
                findParagraphsInJSON(item, paragraphs: &paragraphs)
            }
        }
    }
    
    /// HTML'den paragrafları çıkar
    private func extractParagraphs(from html: String) -> [String] {
        var paragraphs: [String] = []
        
        // <p> tag pattern
        let pPattern = #"<p[^>]*>(.*?)</p>"#
        
        guard let regex = try? NSRegularExpression(pattern: pPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: range)
        
        for match in matches {
            if match.numberOfRanges > 1,
               let contentRange = Range(match.range(at: 1), in: html) {
                let rawText = String(html[contentRange])
                let cleanedText = stripHTMLTags(rawText)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Çok kısa paragrafları atla (muhtemelen UI elementleri)
                if cleanedText.count > 30 {
                    paragraphs.append(cleanedText)
                }
            }
        }
        
        return paragraphs
    }
    
    /// Tüm paragrafları çek (fallback)
    private func extractAllParagraphs(from html: String) -> [String] {
        extractParagraphs(from: html)
    }
    
    /// HTML taglerini kaldır
    private func stripHTMLTags(_ html: String) -> String {
        var text = html
        
        // HTML taglerini kaldır
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // HTML entities'leri temizle
        text = cleanText(text)
        
        // Fazla boşlukları temizle
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Existing Helper Methods
    
    private func extractOGTag(from html: String, property: String) -> String? {
        let pattern = #"<meta[^>]*property=["']\#(property)["'][^>]*content=["']([^"']+)["']"#
        return extractPattern(from: html, pattern: pattern)
    }
    
    private func extractMetaTag(from html: String, property: String) -> String? {
        let pattern = #"<meta[^>]*name=["']\#(property)["'][^>]*content=["']([^"']+)["']"#
        return extractPattern(from: html, pattern: pattern)
    }
    
    private func extractTitle(from html: String) -> String? {
        let pattern = #"<title>([^<]+)</title>"#
        return extractPattern(from: html, pattern: pattern)
    }
    
    private func extractReadTime(from html: String) -> Int {
        let patterns = [
            #"(\d+)\s*min\s*read"#,
            #"(\d+)\s*minute\s*read"#,
            #"readingTime[\"']:\s*(\d+)"#
        ]
        
        for pattern in patterns {
            if let timeString = extractPattern(from: html, pattern: pattern),
               let time = Int(timeString) {
                return time
            }
        }
        
        return 0
    }
    
    private func extractClaps(from html: String) -> Int {
        let patterns = [
            #"claps[\"']:\s*(\d+)"#,
            #"clapCount[\"']:\s*(\d+)"#,
            #"(\d+)\s*claps"#
        ]
        
        for pattern in patterns {
            if let clapsString = extractPattern(from: html, pattern: pattern),
               let claps = Int(clapsString) {
                return claps
            }
        }
        
        return 0
    }
    
    private func extractPublishedDate(from html: String) -> Date? {
        let pattern = #"datePublished[\"']:\s*["']([^"']+)["']"#
        
        if let dateString = extractPattern(from: html, pattern: pattern) {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: dateString)
        }
        
        return nil
    }
    
    private func extractMediumJSONLD(from html: String) -> [String: Any]? {
        let pattern = #"<script type="application/ld\+json">([^<]+)</script>"#
        
        guard let jsonString = extractPattern(from: html, pattern: pattern, options: [.dotMatchesLineSeparators]),
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
            
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let firstItem = jsonArray.first {
                return firstItem
            }
        } catch {
            print("📗 Medium: JSON-LD parse hatası: \(error)")
        }
        
        return nil
    }
    
    private func extractPattern(from html: String, pattern: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
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
    
    private func cleanText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\u2026", with: "…")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Error Types
    
    enum MediumError: LocalizedError {
        case invalidURL
        case networkError
        case httpError(Int)
        case parseError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Geçersiz Medium URL'i"
            case .networkError:
                return "Medium isteği başarısız oldu"
            case .httpError(let code):
                return "Medium HTTP hatası (kod: \(code))"
            case .parseError:
                return "Medium içeriği çözümlenemedi"
            }
        }
    }
}

// MARK: - MediumPost Model

struct MediumPost: Equatable {
    let title: String
    let subtitle: String
    let fullContent: String
    let authorName: String
    let authorURL: URL?
    let imageURL: URL?
    let readTime: Int
    let publishedDate: Date?
    let claps: Int
    let originalURL: URL
    
    var hasSubtitle: Bool {
        !subtitle.isEmpty
    }
    
    var hasFullContent: Bool {
        fullContent.count > 100
    }
    
    var displayText: String {
        if hasFullContent {
            return fullContent
        } else if !subtitle.isEmpty && subtitle != title {
            return subtitle
        }
        return title
    }
    
    var previewText: String {
        let text = hasFullContent ? fullContent : subtitle
        if text.count > 300 {
            return String(text.prefix(300)) + "..."
        }
        return text
    }
    
    var authorDisplay: String {
        authorName
    }
    
    var readTimeText: String {
        if readTime > 0 {
            return "\(readTime) min read"
        }
        return ""
    }
    
    var relativeDate: String? {
        guard let date = publishedDate else { return nil }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var formattedClaps: String {
        if claps >= 1000 {
            return String(format: "%.1fK", Double(claps) / 1000)
        } else if claps > 0 {
            return "\(claps)"
        }
        return ""
    }
}
