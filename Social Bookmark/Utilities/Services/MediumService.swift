import Foundation

/// Medium post servisi - Tam içerik çekme desteği ile
/// Güncellenmiş: Paywall tespiti ve alternatif içerik kaynakları
final class MediumService {
    static let shared = MediumService()
    private init() {}
    
    // MARK: - Public Methods
    
    func isMediumURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        
        // Ana Medium domain'leri
        let mediumDomains = [
            "medium.com",
            "towardsdatascience.com",
            "betterprogramming.pub",
            "levelup.gitconnected.com",
            "javascript.plainenglish.io",
            "blog.devgenius.io",
            "python.plainenglish.io",
            "aws.plainenglish.io",
            "bootcamp.uxdesign.cc",
            "uxdesign.cc",
            "ehandbook.com",
            "codeburst.io"
        ]
        
        return mediumDomains.contains { lowercased.contains($0) }
    }
    
    func fetchPost(from urlString: String) async throws -> MediumPost {
        print("📗 Medium: Başlangıç URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw MediumError.invalidURL
        }
        
        // 1. HTML içeriğini çek - Geliştirilmiş headers
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        
        // Medium bot tespitini atlatmak için headers
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
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
        print("  - Paywall: \(post.isPaywalled ? "Evet" : "Hayır")")
        
        return post
    }
    
    // MARK: - HTML Parser
    
    private func parseMediumHTML(_ html: String, originalURL: URL) throws -> MediumPost {
        print("📗 Medium: HTML parse ediliyor...")
        
        // Paywall kontrolü
        let isPaywalled = detectPaywall(in: html)
        if isPaywalled {
            print("⚠️ Medium: Paywall tespit edildi")
        }
        
        // Open Graph meta tags
        let title = extractOGTag(from: html, property: "og:title") ??
                   extractMetaTag(from: html, name: "title") ??
                   extractTitle(from: html) ??
                   "Medium Post"
        
        let subtitle = extractOGTag(from: html, property: "og:description") ??
                      extractMetaTag(from: html, name: "description") ??
                      ""
        
        let imageURL = extractImageURL(from: html)
        
        // TAM İÇERİK ÇIKART
        let fullContent = extractFullContent(from: html, fallbackSubtitle: subtitle, isPaywalled: isPaywalled)
        
        // Yazar bilgisi
        var authorName = "Medium Writer"
        var authorURL: URL?
        
        // JSON-LD structured data (en güvenilir)
        if let jsonLD = extractMediumJSONLD(from: html) {
            if let author = jsonLD["author"] as? [String: Any] {
                authorName = author["name"] as? String ?? authorName
                if let urlString = author["url"] as? String {
                    authorURL = URL(string: urlString)
                }
            } else if let authorString = jsonLD["author"] as? String {
                authorName = authorString
            }
            
            // Creator field
            if authorName == "Medium Writer",
               let creator = jsonLD["creator"] as? [String: Any],
               let name = creator["name"] as? String {
                authorName = name
            }
        }
        
        // Fallback: HTML meta tags
        if authorName == "Medium Writer" {
            if let metaAuthor = extractMetaTag(from: html, name: "author") {
                authorName = metaAuthor
            } else if let twitterCreator = extractMetaTag(from: html, name: "twitter:creator") {
                authorName = twitterCreator.replacingOccurrences(of: "@", with: "")
            }
        }
        
        // Fallback: URL'den yazar adı
        if authorName == "Medium Writer" {
            if let authorFromURL = extractAuthorFromURL(originalURL.absoluteString) {
                authorName = authorFromURL
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
            originalURL: originalURL,
            isPaywalled: isPaywalled
        )
    }
    
    // MARK: - Paywall Detection
    
    private func detectPaywall(in html: String) -> Bool {
        let paywallIndicators = [
            "membershipContent",
            "meteredContent",
            "locked-content",
            "premium-content",
            "member-only",
            "paywall",
            "subscribe to continue",
            "Member-only story",
            "You've read all your free"
        ]
        
        let lowercasedHTML = html.lowercased()
        return paywallIndicators.contains { lowercasedHTML.contains($0.lowercased()) }
    }
    
    // MARK: - Full Content Extraction
    
    private func extractFullContent(from html: String, fallbackSubtitle: String, isPaywalled: Bool) -> String {
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
            #"<div[^>]*class="[^"]*post-content[^"]*"[^>]*>(.*?)</div>"#,
            #"<div[^>]*class="[^"]*article-content[^"]*"[^>]*>(.*?)</div>"#,
            #"<section[^>]*data-field="body"[^>]*>(.*?)</section>"#
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
        
        // Paragrafları filtrele ve birleştir
        let filteredParagraphs = paragraphs
            .filter { paragraph in
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                // Çok kısa paragrafları ve navigasyon elementlerini atla
                return trimmed.count > 20 &&
                       !trimmed.hasPrefix("Sign in") &&
                       !trimmed.hasPrefix("Get started") &&
                       !trimmed.hasPrefix("Open in app") &&
                       !trimmed.contains("Follow") &&
                       !trimmed.contains("Member-only")
            }
        
        let content = filteredParagraphs.joined(separator: "\n\n")
        
        // Çok kısa içerik varsa (muhtemelen paywall), fallback kullan
        if content.count < 200 || isPaywalled {
            print("  ⚠️ İçerik çok kısa (\(content.count) karakter) veya paywall")
            
            if !fallbackSubtitle.isEmpty && fallbackSubtitle.count > content.count {
                if isPaywalled {
                    return fallbackSubtitle + "\n\n🔒 Bu makale yalnızca Medium üyelerine özel. Tam içeriği okumak için Medium'da açın."
                }
                return fallbackSubtitle
            }
            
            if isPaywalled && !content.isEmpty {
                return content + "\n\n🔒 Bu makale yalnızca Medium üyelerine özel."
            }
        }
        
        return content
    }
    
    /// JSON embedded data'dan içerik çıkar
    private func extractContentFromJSON(_ html: String) -> String? {
        // Medium sayfalarında window.__APOLLO_STATE__ veya benzeri var
        let jsonPatterns = [
            #"window\.__APOLLO_STATE__\s*=\s*(\{.*?\});\s*</script>"#,
            #"window\.__PRELOADED_STATE__\s*=\s*(\{.*?\});\s*</script>"#,
            #"<script[^>]*id="__NEXT_DATA__"[^>]*>(\{.*?\})</script>"#
        ]
        
        for pattern in jsonPatterns {
            if let jsonString = extractPattern(from: html, pattern: pattern, options: [.dotMatchesLineSeparators]) {
                guard let data = jsonString.data(using: .utf8) else { continue }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        continue
                    }
                    
                    // Paragrafları bul
                    var paragraphs: [String] = []
                    findParagraphsInJSON(json, paragraphs: &paragraphs)
                    
                    if !paragraphs.isEmpty {
                        return paragraphs.joined(separator: "\n\n")
                    }
                } catch {
                    continue
                }
            }
        }
        
        return nil
    }
    
    /// JSON içinde recursive olarak paragrafları ara
    private func findParagraphsInJSON(_ json: Any, paragraphs: inout [String]) {
        if let dict = json as? [String: Any] {
            // "text" veya "content" key'lerini ara
            if let text = dict["text"] as? String, text.count > 50 {
                paragraphs.append(text)
            }
            
            // Paragraph type kontrolü
            if let type = dict["type"] as? String,
               type.lowercased().contains("paragraph"),
               let text = dict["text"] as? String {
                paragraphs.append(text)
            }
            
            // Recursive arama
            for value in dict.values {
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
        
        // <p> taglerini bul
        let pattern = #"<p[^>]*>([^<]+(?:<[^/p][^>]*>[^<]*</[^p][^>]*>)*[^<]*)</p>"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, range: range)
            
            for match in matches {
                if match.numberOfRanges > 1,
                   let contentRange = Range(match.range(at: 1), in: html) {
                    let text = String(html[contentRange])
                    let cleanedText = stripHTMLTags(text)
                    if !cleanedText.isEmpty {
                        paragraphs.append(cleanedText)
                    }
                }
            }
        }
        
        return paragraphs
    }
    
    private func extractAllParagraphs(from html: String) -> [String] {
        var paragraphs: [String] = []
        
        // Basit <p>...</p> arama
        let simplePattern = #"<p[^>]*>(.*?)</p>"#
        
        if let regex = try? NSRegularExpression(pattern: simplePattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, range: range)
            
            for match in matches {
                if match.numberOfRanges > 1,
                   let contentRange = Range(match.range(at: 1), in: html) {
                    let text = String(html[contentRange])
                    let cleanedText = stripHTMLTags(text)
                    if cleanedText.count > 20 {
                        paragraphs.append(cleanedText)
                    }
                }
            }
        }
        
        return paragraphs
    }
    
    private func stripHTMLTags(_ html: String) -> String {
        // HTML taglerini kaldır
        var result = html
        
        // Inline taglerden metni koru
        let tagPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: tagPattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        
        return cleanText(result)
    }
    
    // MARK: - Extraction Helpers
    
    private func extractOGTag(from html: String, property: String) -> String? {
        let patterns = [
            #"<meta[^>]*property=["']\#(property)["'][^>]*content=["']([^"']+)["']"#,
            #"<meta[^>]*content=["']([^"']+)["'][^>]*property=["']\#(property)["']"#
        ]
        
        for pattern in patterns {
            if let result = extractPattern(from: html, pattern: pattern) {
                return result
            }
        }
        return nil
    }
    
    private func extractMetaTag(from html: String, name: String) -> String? {
        let patterns = [
            #"<meta[^>]*name=["']\#(name)["'][^>]*content=["']([^"']+)["']"#,
            #"<meta[^>]*content=["']([^"']+)["'][^>]*name=["']\#(name)["']"#
        ]
        
        for pattern in patterns {
            if let result = extractPattern(from: html, pattern: pattern) {
                return result
            }
        }
        return nil
    }
    
    private func extractTitle(from html: String) -> String? {
        let pattern = #"<title>([^<]+)</title>"#
        return extractPattern(from: html, pattern: pattern)
    }
    
    private func extractImageURL(from html: String) -> URL? {
        let sources = [
            extractOGTag(from: html, property: "og:image"),
            extractMetaTag(from: html, name: "twitter:image"),
            extractPattern(from: html, pattern: #"<img[^>]*class="[^"]*progressiveMedia[^"]*"[^>]*src=["']([^"']+)["']"#)
        ]
        
        for source in sources {
            if let urlString = source, !urlString.isEmpty {
                let cleanURL = urlString.replacingOccurrences(of: "&amp;", with: "&")
                if let url = URL(string: cleanURL) {
                    return url
                }
            }
        }
        
        return nil
    }
    
    private func extractReadTime(from html: String) -> Int {
        let patterns = [
            #"(\d+)\s*min\s*read"#,
            #"(\d+)\s*minute\s*read"#,
            #"readingTime[\"']:\s*(\d+)"#,
            #"Reading time:\s*(\d+)"#
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
        let patterns = [
            #"datePublished[\"']:\s*["']([^"']+)["']"#,
            #"published_time[\"']\s*content=["']([^"']+)["']"#
        ]
        
        for pattern in patterns {
            if let dateString = extractPattern(from: html, pattern: pattern) {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                // Alternatif format
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    private func extractAuthorFromURL(_ urlString: String) -> String? {
        // medium.com/@username/article-title formatı
        let pattern = #"medium\.com/@([^/]+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
           let range = Range(match.range(at: 1), in: urlString) {
            let username = String(urlString[range])
            // Username'i okunabilir hale getir
            return username
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
        return nil
    }
    
    private func extractMediumJSONLD(from html: String) -> [String: Any]? {
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>([^<]+)</script>"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: range)
        
        for match in matches {
            guard match.numberOfRanges > 1,
                  let jsonRange = Range(match.range(at: 1), in: html) else {
                continue
            }
            
            let jsonString = String(html[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = jsonString.data(using: .utf8) else { continue }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let type = json["@type"] as? String,
                       ["Article", "BlogPosting", "NewsArticle"].contains(type) {
                        return json
                    }
                }
                
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for item in jsonArray {
                        if let type = item["@type"] as? String,
                           ["Article", "BlogPosting", "NewsArticle"].contains(type) {
                            return item
                        }
                    }
                    if let first = jsonArray.first {
                        return first
                    }
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    private func extractPattern(from html: String, pattern: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range) else {
            return nil
        }
        
        // Capture group'ları kontrol et
        for i in stride(from: match.numberOfRanges - 1, through: 1, by: -1) {
            if let contentRange = Range(match.range(at: i), in: html) {
                let result = String(html[contentRange])
                if !result.isEmpty {
                    return result
                }
            }
        }
        
        return nil
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
            .replacingOccurrences(of: "\\u2019", with: "'")
            .replacingOccurrences(of: "\\u201c", with: "\"")
            .replacingOccurrences(of: "\\u201d", with: "\"")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#x27;", with: "'")
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
    let isPaywalled: Bool
    
    init(title: String, subtitle: String, fullContent: String, authorName: String, authorURL: URL?, imageURL: URL?, readTime: Int, publishedDate: Date?, claps: Int, originalURL: URL, isPaywalled: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.fullContent = fullContent
        self.authorName = authorName
        self.authorURL = authorURL
        self.imageURL = imageURL
        self.readTime = readTime
        self.publishedDate = publishedDate
        self.claps = claps
        self.originalURL = originalURL
        self.isPaywalled = isPaywalled
    }
    
    var hasSubtitle: Bool {
        !subtitle.isEmpty
    }
    
    var hasFullContent: Bool {
        fullContent.count > 100
    }
    
    var hasImage: Bool {
        imageURL != nil
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
            return "\(readTime) dk okuma"
        }
        return ""
    }
    
    var relativeDate: String? {
        guard let date = publishedDate else { return nil }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "tr_TR")
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
    
    var statsText: String {
        var parts: [String] = []
        if readTime > 0 {
            parts.append("📖 \(readTime) dk")
        }
        if claps > 0 {
            parts.append("👏 \(formattedClaps)")
        }
        if isPaywalled {
            parts.append("🔒 Üyelere özel")
        }
        return parts.joined(separator: " • ")
    }
}
