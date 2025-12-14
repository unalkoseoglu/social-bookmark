import Foundation

/// Reddit JSON API servisi - Share URL redirect desteği ile
final class RedditService {
    static let shared = RedditService()
    private init() {}
    
    // MARK: - Public Methods
    
    func isRedditURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("reddit.com/r/") ||
               lowercased.contains("redd.it/") ||
               lowercased.contains("reddit.com/u/")
    }
    
    func fetchPost(from urlString: String) async throws -> RedditPost {
        print("🔴 Reddit: Başlangıç URL: \(urlString)")
        
        // 1. Share URL (/s/) kontrolü - redirect'i takip et
        if urlString.contains("/s/") {
            print("🔴 Reddit: Share URL tespit edildi, redirect takip ediliyor...")
            
            guard let finalURL = try await followRedirect(from: urlString) else {
                print("❌ Reddit: Redirect takip edilemedi")
                throw RedditError.invalidURL
            }
            
            print("✅ Reddit: Gerçek URL bulundu: \(finalURL)")
            
            // Gerçek URL ile devam et
            return try await fetchPost(from: finalURL)
        }
        
        // 2. URL'i temizle ve JSON formatına çevir
        var cleanURL = urlString
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "old.", with: "")
            .replacingOccurrences(of: "new.", with: "")
        
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
        request.setValue("iOS:com.unal.Social-Bookmark:v1.0 (by /u/iOSDev)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🔴 Reddit: İstek gönderiliyor...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RedditError.networkError
        }
        
        print("🔴 Reddit: HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Reddit: Response: \(String(responseString.prefix(300)))")
            }
            throw RedditError.httpError(httpResponse.statusCode)
        }
        
        print("🔴 Reddit: Data alındı (\(data.count) bytes)")
        
        // 4. JSON parse
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstItem = json.first,
              let dataDict = firstItem["data"] as? [String: Any],
              let children = dataDict["children"] as? [[String: Any]],
              let postDict = children.first,
              let postData = postDict["data"] as? [String: Any] else {
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Reddit: JSON (ilk 500 karakter): \(String(jsonString.prefix(500)))")
            }
            
            throw RedditError.parseError
        }
        
        print("✅ Reddit: Post data parse edildi")
        
        // 5. Post bilgilerini çıkar
        let title = postData["title"] as? String ?? ""
        let author = postData["author"] as? String ?? "deleted"
        let subreddit = postData["subreddit"] as? String ?? ""
        let selftext = postData["selftext"] as? String ?? ""
        let score = postData["score"] as? Int ?? 0
        let numComments = postData["num_comments"] as? Int ?? 0
        let permalink = postData["permalink"] as? String ?? ""
        
        print("🔴 Reddit: Başlık: \(title)")
        print("🔴 Reddit: Subreddit: r/\(subreddit)")
        
        // 6. Görsel URL
        var imageURL: URL? = nil
        
        // URL field
        if let urlString = postData["url"] as? String,
           (urlString.contains("i.redd.it") ||
            urlString.contains("i.imgur.com") ||
            urlString.hasSuffix(".jpg") ||
            urlString.hasSuffix(".png") ||
            urlString.hasSuffix(".gif")) {
            imageURL = URL(string: urlString)
            print("✅ Reddit: Görsel (url): \(urlString)")
        }
        
        // Preview images
        if imageURL == nil,
           let preview = postData["preview"] as? [String: Any],
           let images = preview["images"] as? [[String: Any]],
           let firstImage = images.first,
           let source = firstImage["source"] as? [String: Any],
           let urlString = source["url"] as? String {
            
            let decoded = urlString
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
            
            imageURL = URL(string: decoded)
            print("✅ Reddit: Görsel (preview): \(decoded)")
        }
        
        let post = RedditPost(
            title: title,
            author: author,
            subreddit: subreddit,
            selfText: selftext,
            imageURL: imageURL,
            score: score,
            commentCount: numComments,
            originalURL: URL(string: "https://reddit.com\(permalink)")!
        )
        
        print("✅ Reddit: Post oluşturuldu")
        
        return post
    }
    
    // MARK: - Redirect Follower
    
    /// Share URL'lerini gerçek URL'e çözümle
    private func followRedirect(from urlString: String) async throws -> String? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // Sadece header'ları al
        request.timeoutInterval = 10
        request.setValue("iOS:com.unal.Social-Bookmark:v1.0 (by /u/iOSDev)", forHTTPHeaderField: "User-Agent")
        
        // Manual redirect takibi için
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 1
        let session = URLSession(configuration: config)
        
        do {
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               let location = httpResponse.url?.absoluteString {
                print("🔴 Reddit: Redirect location: \(location)")
                return location
            }
            
            return nil
        } catch {
            print("❌ Reddit: Redirect hatası: \(error)")
            return nil
        }
    }
    
    // MARK: - Error Types
    
    enum RedditError: LocalizedError {
        case invalidURL
        case networkError
        case httpError(Int)
        case parseError
        
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
            }
        }
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
    var subtitle: String { "\(authorDisplay) • r/\(subreddit)" }

    var summary: String {
        let trimmed = selfText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? subtitle : trimmed
    }
}
