import Foundation

/// LinkedIn post servisi
/// NOT: LinkedIn API gerektiriyor, bu yüzden web scraping kullanıyoruz
/// Güncellenmiş: Authwall durumunda kısmi veri döndürme + gelişmiş içerik çıkarma
final class LinkedInService {
    static let shared = LinkedInService()
    private init() {}
    
    // MARK: - Public Methods
    
    func isLinkedInURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("linkedin.com/posts/") ||
               lowercased.contains("linkedin.com/feed/update/") ||
               lowercased.contains("linkedin.com/pulse/") ||
               lowercased.contains("linkedin.com/in/") ||
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
        
        // 2. HTML içeriğini çek - Geliştirilmiş headers
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        
        // LinkedIn bot tespitini atlatmak için daha gerçekçi header'lar
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9,tr;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("https://www.linkedin.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.google.com/", forHTTPHeaderField: "Referer")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
        
        print("🔵 LinkedIn: HTML çekiliyor...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LinkedInError.networkError
        }
        
        print("🔵 LinkedIn: HTTP Status: \(httpResponse.statusCode)")
        
        // Redirect kontrolü - login sayfasına yönlendirme
        if let redirectURL = httpResponse.url?.absoluteString,
           redirectURL.contains("login") || redirectURL.contains("authwall") {
            print("⚠️ LinkedIn: Login redirect tespit edildi")
            // Authwall durumunda URL'den kısmi veri çıkar
            return createPartialPost(from: finalURL, originalURL: url, error: .authRequired)
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 999 {
                print("⚠️ LinkedIn: Bot detection tetiklendi (999)")
                return createPartialPost(from: finalURL, originalURL: url, error: .botDetected)
            }
            throw LinkedInError.httpError(httpResponse.statusCode)
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw LinkedInError.parseError
        }
        
        print("🔵 LinkedIn: HTML alındı (\(html.count) karakter)")
        
        // Login/authwall kontrolü - HTML içeriğinde
        if html.contains("authwall") || html.contains("login?") ||
           html.contains("Sign in to LinkedIn") || html.contains("sign-in-form") {
            print("⚠️ LinkedIn: Authwall HTML'de tespit edildi")
            // HTML'den mümkün olduğunca veri çıkar
            let partialPost = try parseLinkedInHTML(html, originalURL: url, isAuthwalled: true)
            return partialPost
        }
        
        // 3. HTML'den bilgileri çıkar
        let post = try parseLinkedInHTML(html, originalURL: url, isAuthwalled: false)
        
        print("✅ LinkedIn: Post oluşturuldu")
        print("  - Başlık/İçerik: \(post.title.prefix(50))...")
        print("  - Yazar: \(post.authorName)")
        
        return post
    }
    
    // MARK: - Partial Post Creation (Authwall durumları için)
    
    private func createPartialPost(from urlString: String, originalURL: URL, error: LinkedInError) -> LinkedInPost {
        print("⚠️ LinkedIn: Kısmi veri oluşturuluyor (URL'den)...")
        
        // URL'den kullanıcı adını çıkar
        var authorName = "LinkedIn User"
        var title = "LinkedIn Post"
        
        // linkedin.com/posts/username_... formatı
        if let usernameMatch = extractURLComponent(from: urlString, pattern: #"linkedin\.com/posts/([^_/]+)"#) {
            authorName = formatUsername(usernameMatch)
            title = "\(authorName) - LinkedIn Post"
        }
        // linkedin.com/in/username formatı
        else if let usernameMatch = extractURLComponent(from: urlString, pattern: #"linkedin\.com/in/([^/]+)"#) {
            authorName = formatUsername(usernameMatch)
            title = "\(authorName) - LinkedIn Profile"
        }
        // linkedin.com/feed/update/urn:li:activity:... formatı
        else if urlString.contains("feed/update") {
            title = "LinkedIn Activity"
        }
        
        let errorMessage: String
        switch error {
        case .authRequired:
            errorMessage = "⚠️ Bu içeriği görüntülemek için LinkedIn'de giriş yapılması gerekiyor.\n\n📱 Tarayıcıda açarak içeriği görebilirsiniz."
        case .botDetected:
            errorMessage = "⚠️ LinkedIn erişimi geçici olarak kısıtlandı.\n\n🔄 Lütfen birkaç dakika sonra tekrar deneyin."
        default:
            errorMessage = "⚠️ LinkedIn içeriği yüklenemedi."
        }
        
        return LinkedInPost(
            title: title,
            content: errorMessage,
            authorName: authorName,
            authorTitle: "",
            imageURL: nil,
            originalURL: originalURL,
            isPartial: true,
            errorType: error
        )
    }
    
    private func formatUsername(_ username: String) -> String {
        // ahmet-kahrimanoglu -> Ahmet Kahrimanoglu
        username
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    
    private func extractURLComponent(from urlString: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
              let range = Range(match.range(at: 1), in: urlString) else {
            return nil
        }
        return String(urlString[range])
    }
    
    // MARK: - HTML Parser
    
    private func parseLinkedInHTML(_ html: String, originalURL: URL, isAuthwalled: Bool) throws -> LinkedInPost {
        print("🔵 LinkedIn: HTML parse ediliyor... (authwalled: \(isAuthwalled))")
        
        // Open Graph meta tags'lerini çıkar (authwall durumunda bile çalışır)
        let title = extractOGTag(from: html, property: "og:title") ??
                   extractMetaTag(from: html, name: "title") ??
                   extractTitle(from: html) ??
                   "LinkedIn Post"
        
        var description = extractOGTag(from: html, property: "og:description") ??
                         extractMetaTag(from: html, name: "description") ??
                         ""
        
        // Eğer meta description yoksa, alternatif yöntemler dene
        if description.isEmpty && !isAuthwalled {
            description = extractPostContent(from: html)
        }
        
        // Görsel URL - Birden fazla kaynak dene
        let imageURL = extractImageURL(from: html)
        
        // Yazar bilgisini çıkar
        var authorName = "LinkedIn User"
        var authorTitle = ""
        
        // Yöntem 1: og:title'dan "Name on LinkedIn: Post text" formatı
        if let ogTitle = extractOGTag(from: html, property: "og:title") {
            // "Ahmet Kahrimanoglu on LinkedIn: Git kullanırken..." formatı
            if ogTitle.contains(" on LinkedIn:") {
                let parts = ogTitle.components(separatedBy: " on LinkedIn:")
                if let name = parts.first {
                    authorName = name.trimmingCharacters(in: .whitespaces)
                }
            }
            // "Name · Job Title" formatı
            else if ogTitle.contains("·") {
                let parts = ogTitle.components(separatedBy: "·")
                if parts.count >= 2 {
                    authorName = parts[0].trimmingCharacters(in: .whitespaces)
                    authorTitle = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Yöntem 2: Title tag'inden
        if authorName == "LinkedIn User" {
            if let titleMatch = extractPattern(from: html, pattern: #"<title>([^|<]+?)(?:\s+on\s+LinkedIn|\s*\|)"#) {
                let name = titleMatch.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty && name != "LinkedIn" {
                    authorName = name
                }
            }
        }
        
        // Yöntem 3: JSON-LD structured data
        if authorName == "LinkedIn User",
           let jsonLD = extractJSONLD(from: html) {
            if let author = jsonLD["author"] as? [String: Any] {
                authorName = author["name"] as? String ?? authorName
            } else if let authorString = jsonLD["author"] as? String {
                authorName = authorString
            }
        }
        
        // Yöntem 4: URL'den
        if authorName == "LinkedIn User" {
            if let urlAuthor = extractURLComponent(from: originalURL.absoluteString, pattern: #"linkedin\.com/posts/([^_/]+)"#) {
                authorName = formatUsername(urlAuthor)
            }
        }
        
        // Authwall durumunda bilgi mesajı ekle
        var finalDescription = description
        if isAuthwalled && description.isEmpty {
            finalDescription = "⚠️ Bu içeriği tam olarak görüntülemek için LinkedIn'de giriş yapmanız gerekiyor."
        } else if isAuthwalled && !description.isEmpty {
            finalDescription = description + "\n\n📱 Tam içerik için LinkedIn'de açın."
        }
        
        print("🔵 LinkedIn: Parse tamamlandı")
        print("  - Başlık: \(title.prefix(100))...")
        print("  - İçerik: \(finalDescription.isEmpty ? "boş" : finalDescription.prefix(100) + "...")")
        print("  - Yazar: \(authorName)")
        print("  - Görsel: \(imageURL?.absoluteString ?? "yok")")
        
        return LinkedInPost(
            title: cleanText(title),
            content: cleanText(finalDescription),
            authorName: cleanText(authorName),
            authorTitle: cleanText(authorTitle),
            imageURL: imageURL,
            originalURL: originalURL,
            isPartial: isAuthwalled,
            errorType: isAuthwalled ? .authRequired : nil
        )
    }
    
    // MARK: - HTML Extraction Helpers
    
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
            extractOGTag(from: html, property: "twitter:image"),
            extractMetaTag(from: html, name: "image"),
            extractPattern(from: html, pattern: #"<img[^>]*class="[^"]*feed[^"]*"[^>]*src=["']([^"']+)["']"#),
            extractPattern(from: html, pattern: #"data-delayed-url=["']([^"']+\.(?:jpg|jpeg|png|gif|webp)[^"']*)["']"#)
        ]
        
        for source in sources {
            if let urlString = source, !urlString.isEmpty {
                var cleanURL = urlString
                    .replacingOccurrences(of: "&amp;", with: "&")
                
                if cleanURL.hasPrefix("/") {
                    cleanURL = "https://www.linkedin.com" + cleanURL
                }
                
                if let url = URL(string: cleanURL) {
                    return url
                }
            }
        }
        
        return nil
    }
    
    private func extractPostContent(from html: String) -> String {
        var content = ""
        
        // Yöntem 1: JSON-LD Article'dan extract et
        if let jsonLD = extractJSONLD(from: html),
           let articleBody = jsonLD["articleBody"] as? String {
            content = articleBody
        }
        
        // Yöntem 2: data-test-id içeriği
        if content.isEmpty {
            if let commentary = extractPattern(from: html, pattern: #"data-test-id="[^"]*commentary[^"]*"[^>]*>([^<]+)"#) {
                content = commentary
            }
        }
        
        // Yöntem 3: span.break-words içeriği
        if content.isEmpty {
            if let breakWords = extractPattern(from: html, pattern: #"<span[^>]*class="[^"]*break-words[^"]*"[^>]*>([^<]+)"#) {
                content = breakWords
            }
        }
        
        // Yöntem 4: Hashtag'leri topla
        if content.isEmpty {
            let hashtagPattern = #"#[A-Za-z][A-Za-z0-9_]*"#
            if let regex = try? NSRegularExpression(pattern: hashtagPattern) {
                let range = NSRange(html.startIndex..<html.endIndex, in: html)
                let matches = regex.matches(in: html, range: range)
                let hashtags = matches.compactMap { match -> String? in
                    if let range = Range(match.range, in: html) {
                        return String(html[range])
                    }
                    return nil
                }
                let uniqueHashtags = Array(Set(hashtags)).prefix(10)
                if !uniqueHashtags.isEmpty {
                    content = uniqueHashtags.joined(separator: " ")
                }
            }
        }
        
        return content
    }
    
    private func extractPattern(from html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range) else {
            return nil
        }
        
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
    
    private func extractJSONLD(from html: String) -> [String: Any]? {
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
                       ["Article", "SocialMediaPosting", "BlogPosting"].contains(type) {
                        return json
                    }
                }
                
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for item in jsonArray {
                        if let type = item["@type"] as? String,
                           ["Article", "SocialMediaPosting", "BlogPosting"].contains(type) {
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
    
    private func cleanText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\u2019", with: "'")
            .replacingOccurrences(of: "\\u2018", with: "'")
            .replacingOccurrences(of: "\\u201c", with: "\"")
            .replacingOccurrences(of: "\\u201d", with: "\"")
            .replacingOccurrences(of: "\\u2026", with: "...")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - URL Helpers
    
    private func expandShortURL(_ urlString: String) async throws -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           let location = httpResponse.url?.absoluteString,
           location != urlString {
            return location
        }
        
        return nil
    }
    
    // MARK: - Error Types
    
    enum LinkedInError: LocalizedError, Equatable {
        case invalidURL
        case networkError
        case httpError(Int)
        case parseError
        case authRequired
        case botDetected
        
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
                return "Bu LinkedIn içeriği giriş gerektiriyor"
            case .botDetected:
                return "LinkedIn erişimi geçici olarak kısıtlandı"
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
    let isPartial: Bool
    let errorType: LinkedInService.LinkedInError?
    
    init(title: String, content: String, authorName: String, authorTitle: String, imageURL: URL?, originalURL: URL, isPartial: Bool = false, errorType: LinkedInService.LinkedInError? = nil) {
        self.title = title
        self.content = content
        self.authorName = authorName
        self.authorTitle = authorTitle
        self.imageURL = imageURL
        self.originalURL = originalURL
        self.isPartial = isPartial
        self.errorType = errorType
    }
    
    var hasContent: Bool {
        !content.isEmpty
    }
    
    var hasImage: Bool {
        imageURL != nil
    }
    
    var hasError: Bool {
        errorType != nil
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
    
    var shortSummary: String {
        let text = displayText
        if text.count > 100 {
            return String(text.prefix(100)) + "..."
        }
        return text
    }
    
    /// Hata mesajını kullanıcıya göstermek için
    var userFacingErrorMessage: String? {
        guard let error = errorType else { return nil }
        
        switch error {
        case .authRequired:
            return "🔒 LinkedIn giriş gerektiriyor\nTarayıcıda açarak içeriği görüntüleyebilirsiniz."
        case .botDetected:
            return "⏳ LinkedIn geçici olarak kısıtlandı\nBirkaç dakika sonra tekrar deneyin."
        default:
            return nil
        }
    }
}
