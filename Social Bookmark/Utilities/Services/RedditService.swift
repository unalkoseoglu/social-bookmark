import Foundation

/// Reddit JSON API servisi - Share URL redirect desteği ile
/// Güncellenmiş versiyon: /s/ share URL'leri ve object payload desteği
final class RedditService {
    static let shared = RedditService()
    
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Public Methods
    
    func isRedditURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("reddit.com/r/") ||
               lowercased.contains("reddit.com/u/") ||
               lowercased.contains("redd.it/") ||
               lowercased.contains("reddit.com/s/") ||  // Share URL
               lowercased.contains("/comments/")
    }
    
    func fetchPost(from urlString: String) async throws -> RedditPost {
        print("🔴 Reddit: Başlangıç URL: \(urlString)")
        
        // 1. Share URL (/s/) kontrolü - redirect'i takip et
        if urlString.contains("/s/") {
            print("🔴 Reddit: Share URL tespit edildi, redirect takip ediliyor...")
            
            guard let finalURL = try await followRedirect(from: urlString) else {
                print("❌ Reddit: Redirect takip edilemedi, alternatif yöntem deneniyor...")
                // Alternatif: Doğrudan fetch dene
                return try await fetchDirectly(from: urlString)
            }
            
            print("✅ Reddit: Gerçek URL bulundu: \(finalURL)")
            
            // Gerçek URL ile devam et (recursive call)
            return try await fetchPost(from: finalURL)
        }
        
        // 2. URL'i temizle ve JSON formatına çevir
        var cleanURL = urlString
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "old.", with: "")
            .replacingOccurrences(of: "new.", with: "")
            .replacingOccurrences(of: "np.", with: "")  // No-participation links
        
        // URL sonundaki slash'ı kaldır
        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }
        
        // Query parameters'ları kaldır
        if let queryIndex = cleanURL.firstIndex(of: "?") {
            cleanURL = String(cleanURL[..<queryIndex])
        }
        
        // .json ekle
        if !cleanURL.hasSuffix(".json") {
            cleanURL += ".json"
        }
        
        print("🔴 Reddit: JSON URL: \(cleanURL)")
        
        guard let url = URL(string: cleanURL) else {
            throw RedditError.invalidURL
        }
        
        // 3. HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        // Reddit'in güncel User-Agent gereksinimleri
        request.setValue("iOS:com.unal.Social-Bookmark:v1.0 (by /u/iOSDev)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        print("🔴 Reddit: İstek gönderiliyor...")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RedditError.networkError
        }
        
        print("🔴 Reddit: HTTP Status: \(httpResponse.statusCode)")
        
        // Rate limit kontrolü
        if httpResponse.statusCode == 429 {
            print("⚠️ Reddit: Rate limit aşıldı")
            throw RedditError.rateLimited
        }
        
        guard httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Reddit: Response: \(String(responseString.prefix(300)))")
            }
            throw RedditError.httpError(httpResponse.statusCode)
        }
        
        print("🔴 Reddit: Data alındı (\(data.count) bytes)")
        
        // 4. JSON parse - İki farklı format destekle
        let postData = try parseRedditJSON(data)
        
        print("✅ Reddit: Post data parse edildi")
        
        // 5. Post bilgilerini çıkar
        let title = postData["title"] as? String ?? ""
        let author = postData["author"] as? String ?? "deleted"
        let subreddit = postData["subreddit"] as? String ?? ""
        let selftext = postData["selftext"] as? String ?? ""
        let score = postData["score"] as? Int ?? postData["ups"] as? Int ?? 0
        let numComments = postData["num_comments"] as? Int ?? 0
        let permalink = postData["permalink"] as? String ?? ""
        
        print("🔴 Reddit: Başlık: \(title)")
        print("🔴 Reddit: Subreddit: r/\(subreddit)")
        print("🔴 Reddit: Yazar: u/\(author)")
        
        // 6. Görsel URL - Çoklu kaynak kontrolü
        let imageURL = extractImageURL(from: postData)
        
        // 7. Post oluştur
        let originalURLString = permalink.isEmpty ? urlString : "https://reddit.com\(permalink)"
        
        let post = RedditPost(
            title: title,
            author: author,
            subreddit: subreddit,
            selfText: selftext,
            imageURL: imageURL,
            score: score,
            commentCount: numComments,
            originalURL: URL(string: originalURLString) ?? URL(string: urlString)!
        )
        
        print("✅ Reddit: Post oluşturuldu")
        print("   - Skor: \(score)")
        print("   - Yorum: \(numComments)")
        print("   - Görsel: \(imageURL?.absoluteString ?? "yok")")
        
        return post
    }
    
    // MARK: - JSON Parsing
    
    /// Reddit'in iki farklı JSON formatını destekle
    private func parseRedditJSON(_ data: Data) throws -> [String: Any] {
        // Format 1: Array formatı [[{data: {children: [{data: {...}}]}}]]
        if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let firstItem = json.first,
           let dataDict = firstItem["data"] as? [String: Any],
           let children = dataDict["children"] as? [[String: Any]],
           let postDict = children.first,
           let postData = postDict["data"] as? [String: Any] {
            print("🔴 Reddit: Array format parse edildi")
            return postData
        }
        
        // Format 2: Object formatı {kind: "Listing", data: {children: [{data: {...}}]}}
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataDict = json["data"] as? [String: Any],
           let children = dataDict["children"] as? [[String: Any]],
           let postDict = children.first,
           let postData = postDict["data"] as? [String: Any] {
            print("🔴 Reddit: Object format parse edildi")
            return postData
        }
        
        // Format 3: Direkt post datası
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["title"] != nil {
            print("🔴 Reddit: Direct format parse edildi")
            return json
        }
        
        // Debug için JSON'ı yazdır
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 Reddit: JSON (ilk 500 karakter): \(String(jsonString.prefix(500)))")
        }
        
        throw RedditError.parseError
    }
    
    // MARK: - Image URL Extraction
    
    /// Çoklu kaynaklardan görsel URL'i çıkar
    private func extractImageURL(from postData: [String: Any]) -> URL? {
        var imageURL: URL? = nil
        
        // Kaynak 1: url field - direkt görsel linkler
        if let urlString = postData["url"] as? String {
            let extensions = [".jpg", ".jpeg", ".png", ".gif", ".webp"]
            let hosts = ["i.redd.it", "i.imgur.com", "imgur.com", "preview.redd.it"]
            
            if extensions.contains(where: { urlString.lowercased().hasSuffix($0) }) ||
               hosts.contains(where: { urlString.contains($0) }) {
                imageURL = URL(string: urlString)
                print("✅ Reddit: Görsel (url): \(urlString)")
            }
        }
        
        // Kaynak 2: thumbnail - bazen yeterli
        if imageURL == nil, let thumbnail = postData["thumbnail"] as? String,
           thumbnail.hasPrefix("http"),
           !thumbnail.contains("self") && !thumbnail.contains("default") {
            // Düşük çözünürlüklü ama kullanılabilir
            imageURL = URL(string: thumbnail)
            print("✅ Reddit: Görsel (thumbnail): \(thumbnail)")
        }
        
        // Kaynak 3: preview images - yüksek kalite
        if imageURL == nil,
           let preview = postData["preview"] as? [String: Any],
           let images = preview["images"] as? [[String: Any]],
           let firstImage = images.first,
           let source = firstImage["source"] as? [String: Any],
           let urlString = source["url"] as? String {
            
            // HTML entities decode
            let decoded = decodeHTMLEntities(urlString)
            imageURL = URL(string: decoded)
            print("✅ Reddit: Görsel (preview): \(decoded)")
        }
        
        // Kaynak 4: media_metadata - gallery postlar için
        if imageURL == nil,
           let mediaMetadata = postData["media_metadata"] as? [String: Any],
           let firstKey = mediaMetadata.keys.first,
           let firstMedia = mediaMetadata[firstKey] as? [String: Any],
           let s = firstMedia["s"] as? [String: Any],
           let urlString = s["u"] as? String {
            
            let decoded = decodeHTMLEntities(urlString)
            imageURL = URL(string: decoded)
            print("✅ Reddit: Görsel (media_metadata): \(decoded)")
        }
        
        // Kaynak 5: gallery_data ile media_metadata kombinasyonu
        if imageURL == nil,
           let galleryData = postData["gallery_data"] as? [String: Any],
           let items = galleryData["items"] as? [[String: Any]],
           let firstItem = items.first,
           let mediaId = firstItem["media_id"] as? String,
           let mediaMetadata = postData["media_metadata"] as? [String: Any],
           let media = mediaMetadata[mediaId] as? [String: Any],
           let s = media["s"] as? [String: Any],
           let urlString = s["u"] as? String {
            
            let decoded = decodeHTMLEntities(urlString)
            imageURL = URL(string: decoded)
            print("✅ Reddit: Görsel (gallery): \(decoded)")
        }
        
        return imageURL
    }
    
    // MARK: - Redirect Follower
    
    /// Share URL'lerini gerçek URL'e çözümle
    private func followRedirect(from urlString: String) async throws -> String? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        // Custom session ile redirect'i manuel takip et
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 1
        
        // Delegate ile redirect'i yakala
        let delegate = RedirectCaptureDelegate()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"  // HEAD bazen çalışmıyor
        request.timeoutInterval = 10
        request.setValue("iOS:com.unal.Social-Bookmark:v1.0 (by /u/iOSDev)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        
        do {
            let (_, response) = try await session.data(for: request)
            
            // Redirect capture delegate'den al
            if let capturedURL = delegate.redirectedURL?.absoluteString {
                print("🔴 Reddit: Redirect yakalandı: \(capturedURL)")
                return capturedURL
            }
            
            // Response URL'den al
            if let httpResponse = response as? HTTPURLResponse,
               let responseURL = httpResponse.url?.absoluteString,
               responseURL != urlString {
                print("🔴 Reddit: Response URL: \(responseURL)")
                return responseURL
            }
            
            // URL değişmediyse nil dön
            return nil
        } catch {
            print("❌ Reddit: Redirect hatası: \(error)")
            return nil
        }
    }
    
    /// Direkt fetch (redirect başarısız olursa)
    private func fetchDirectly(from urlString: String) async throws -> RedditPost {
        // URL'den post ID çıkarmayı dene
        guard let postId = extractPostId(from: urlString) else {
            throw RedditError.invalidURL
        }
        
        // Generic reddit URL oluştur
        let genericURL = "https://reddit.com/comments/\(postId).json"
        
        print("🔴 Reddit: Alternatif URL deneniyor: \(genericURL)")
        
        guard let url = URL(string: genericURL) else {
            throw RedditError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("iOS:com.unal.Social-Bookmark:v1.0 (by /u/iOSDev)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RedditError.networkError
        }
        
        let postData = try parseRedditJSON(data)
        
        let title = postData["title"] as? String ?? ""
        let author = postData["author"] as? String ?? "deleted"
        let subreddit = postData["subreddit"] as? String ?? ""
        let selftext = postData["selftext"] as? String ?? ""
        let score = postData["score"] as? Int ?? 0
        let numComments = postData["num_comments"] as? Int ?? 0
        let permalink = postData["permalink"] as? String ?? ""
        let imageURL = extractImageURL(from: postData)
        
        return RedditPost(
            title: title,
            author: author,
            subreddit: subreddit,
            selfText: selftext,
            imageURL: imageURL,
            score: score,
            commentCount: numComments,
            originalURL: URL(string: "https://reddit.com\(permalink)") ?? URL(string: urlString)!
        )
    }
    
    // MARK: - Helpers
    
    private func extractPostId(from urlString: String) -> String? {
        let patterns = [
            #"/comments/([a-z0-9]+)"#,
            #"/s/([a-zA-Z0-9]+)"#,
            #"redd\.it/([a-z0-9]+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
               let range = Range(match.range(at: 1), in: urlString) {
                return String(urlString[range])
            }
        }
        
        return nil
    }
    
    private func decodeHTMLEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
    
    // MARK: - Error Types
    
    enum RedditError: LocalizedError {
        case invalidURL
        case networkError
        case httpError(Int)
        case parseError
        case rateLimited
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Geçersiz Reddit URL'i"
            case .networkError:
                return "Reddit isteği başarısız oldu"
            case .httpError(let code):
                return "Reddit HTTP hatası (kod: \(code))"
            case .parseError:
                return "Reddit yanıtı çözümlenemedi"
            case .rateLimited:
                return "Çok fazla istek, lütfen bekleyin"
            }
        }
    }
}

// MARK: - Redirect Capture Delegate

private class RedirectCaptureDelegate: NSObject, URLSessionTaskDelegate {
    var redirectedURL: URL?
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Redirect URL'i kaydet
        redirectedURL = request.url
        print("🔄 Redirect yakalandı: \(request.url?.absoluteString ?? "nil")")
        
        // Redirect'e izin ver
        completionHandler(request)
    }
}

// MARK: - RedditPost Model

struct RedditPost: Equatable {
    let title: String
    let author: String
    let subreddit: String
    let selfText: String
    let imageURL: URL?
    let score: Int
    let commentCount: Int
    let originalURL: URL

    var authorDisplay: String { "u/\(author)" }
    var subredditDisplay: String { "r/\(subreddit)" }
    var subtitle: String { "\(authorDisplay) • \(subredditDisplay)" }

    var summary: String {
        let trimmed = selfText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? subtitle : trimmed
    }
    
    var hasImage: Bool {
        imageURL != nil
    }
    
    var statsText: String {
        let scoreText = score >= 1000 ? String(format: "%.1fK", Double(score) / 1000) : "\(score)"
        return "⬆️ \(scoreText) • 💬 \(commentCount)"
    }
}

// MARK: - Protocol for Testing

protocol RedditPostProviding {
    func fetchPost(from urlString: String) async throws -> RedditPost
    func isRedditURL(_ urlString: String) -> Bool
}

extension RedditService: RedditPostProviding {}
