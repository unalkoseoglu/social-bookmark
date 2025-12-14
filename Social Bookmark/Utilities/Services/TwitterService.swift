import Foundation

/// Twitter/X içeriklerini çeken servis
/// FxTwitter API kullanır - ücretsiz ve stabil
/// FixUpX alternatif olarak kullanılır
final class TwitterService {
    // MARK: - Singleton
    
    static let shared = TwitterService()
    private init() {}
    
    // MARK: - Models
    
    struct Tweet {
        let id: String
        let text: String
        let authorName: String
        let authorUsername: String
        let authorAvatarURL: URL?
        let mediaURLs: [URL]
        let createdAt: Date?
        let likeCount: Int
        let retweetCount: Int
        let replyCount: Int
        let originalURL: URL
        
        var fullText: String {
            """
            @\(authorUsername) (\(authorName)):
            
            \(text)
            """
        }
        
        var shortSummary: String {
            let maxLength = 80
            let cleanText = text.replacingOccurrences(of: "\n", with: " ")
            if cleanText.count > maxLength {
                return String(cleanText.prefix(maxLength)) + "..."
            }
            return cleanText
        }
        
        var hasMedia: Bool {
            !mediaURLs.isEmpty
        }
        
        var firstImageURL: URL? {
            mediaURLs.first
        }
    }
    
    // MARK: - API Response Models
    
    private struct FxTwitterResponse: Codable {
        let code: Int?
        let message: String?
        let tweet: FxTweet?
    }
    
    private struct FxTweet: Codable {
        let id: String?
        let text: String?
        let author: FxAuthor?
        let media: FxMedia?
        let created_at: String?
        let likes: Int?
        let retweets: Int?
        let replies: Int?
        let url: String?
    }
    
    private struct FxAuthor: Codable {
        let name: String?
        let screen_name: String?
        let avatar_url: String?
    }
    
    private struct FxMedia: Codable {
        let all: [FxMediaItem]?
        let photos: [FxPhoto]?
        let videos: [FxVideo]?
        let mosaic: FxMosaic?
    }
    
    private struct FxMediaItem: Codable {
        let type: String?
        let url: String?
        let thumbnail_url: String?
        let width: Int?
        let height: Int?
    }
    
    private struct FxPhoto: Codable {
        let url: String?
        let width: Int?
        let height: Int?
    }
    
    private struct FxVideo: Codable {
        let url: String?
        let thumbnail_url: String?
        let width: Int?
        let height: Int?
    }
    
    private struct FxMosaic: Codable {
        let formats: FxMosaicFormats?
    }
    
    private struct FxMosaicFormats: Codable {
        let jpeg: String?
        let webp: String?
    }
    
    // MARK: - API Endpoints (with fallbacks)
    
    private let apiEndpoints = [
        "https://api.fxtwitter.com",
        "https://api.vxtwitter.com",
        "https://api.fixupx.com"
    ]
    
    // MARK: - Public Methods
    
    func fetchTweet(from urlString: String) async throws -> Tweet {
        guard let tweetId = extractTweetId(from: urlString),
              let originalURL = URL(string: urlString) else {
            throw TwitterError.invalidURL
        }
        
        print("🐦 Twitter: Tweet ID: \(tweetId)")
        
        // Her endpoint'i dene
        var lastError: Error = TwitterError.networkError
        
        for endpoint in apiEndpoints {
            do {
                let tweet = try await fetchFromEndpoint(endpoint, tweetId: tweetId, originalURL: originalURL)
                return tweet
            } catch {
                print("⚠️ Twitter: \(endpoint) başarısız: \(error.localizedDescription)")
                lastError = error
                continue
            }
        }
        
        throw lastError
    }
    
    private func fetchFromEndpoint(_ endpoint: String, tweetId: String, originalURL: URL) async throws -> Tweet {
        let apiURL = "\(endpoint)/status/\(tweetId)"
        
        guard let url = URL(string: apiURL) else {
            throw TwitterError.invalidURL
        }
        
        print("🔍 Twitter API isteği: \(apiURL)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwitterError.networkError
        }
        
        print("📡 HTTP Status: \(httpResponse.statusCode)")
        
        // Rate limit kontrolü
        if httpResponse.statusCode == 429 {
            print("⚠️ Twitter: Rate limit, sonraki endpoint deneniyor...")
            throw TwitterError.rateLimited
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TwitterError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // DEBUG: Raw JSON'ı yazdır
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📦 Raw JSON (ilk 1000 karakter):")
            print(String(jsonString.prefix(1000)))
        }
        
        let decoder = JSONDecoder()
        let fxResponse = try decoder.decode(FxTwitterResponse.self, from: data)
        
        if let code = fxResponse.code, code != 200 {
            throw TwitterError.tweetNotFound
        }
        
        guard let fxTweet = fxResponse.tweet else {
            throw TwitterError.tweetNotFound
        }
        
        // DEBUG: Media bilgisi
        print("🖼️ Media bilgisi:")
        print("   - media.all: \(fxTweet.media?.all?.count ?? 0) adet")
        print("   - media.photos: \(fxTweet.media?.photos?.count ?? 0) adet")
        print("   - media.videos: \(fxTweet.media?.videos?.count ?? 0) adet")
        print("   - media.mosaic: \(fxTweet.media?.mosaic?.formats?.jpeg ?? "yok")")
        
        return convertToTweet(fxTweet, originalURL: originalURL)
    }
    
    func isTwitterURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("twitter.com/") ||
               lowercased.contains("x.com/") ||
               lowercased.contains("fxtwitter.com/") ||
               lowercased.contains("vxtwitter.com/") ||
               lowercased.contains("fixupx.com/")
    }
    
    // MARK: - Private Methods
    
    private func extractTweetId(from urlString: String) -> String? {
        let patterns = [
            #"/status/(\d+)"#,
            #"/statuses/(\d+)"#,
            #"[?&]id=(\d+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
               let range = Range(match.range(at: 1), in: urlString) {
                return String(urlString[range])
            }
        }
        
        return nil
    }
    
    private func convertToTweet(_ fxTweet: FxTweet, originalURL: URL) -> Tweet {
        var mediaURLs: [URL] = []
        
        // ÖNCE: media.all array'inden çek (daha güvenilir)
        if let allMedia = fxTweet.media?.all {
            for item in allMedia {
                // Fotoğraf için url, video için thumbnail_url
                if let urlString = item.url ?? item.thumbnail_url,
                   let url = URL(string: urlString) {
                    mediaURLs.append(url)
                    print("   ✅ Media URL eklendi (all): \(urlString.prefix(80))...")
                }
            }
        }
        
        // Mosaic (çoklu görsel için tek birleştirilmiş görsel)
        if mediaURLs.isEmpty, let mosaicURL = fxTweet.media?.mosaic?.formats?.jpeg {
            if let url = URL(string: mosaicURL) {
                mediaURLs.append(url)
                print("   ✅ Mosaic URL eklendi: \(mosaicURL.prefix(80))...")
            }
        }
        
        // SONRA: Eski yöntem (fallback)
        if mediaURLs.isEmpty {
            if let photos = fxTweet.media?.photos {
                for photo in photos {
                    if let urlString = photo.url, let url = URL(string: urlString) {
                        mediaURLs.append(url)
                        print("   ✅ Photo URL eklendi: \(urlString.prefix(80))...")
                    }
                }
            }
            
            if let videos = fxTweet.media?.videos {
                for video in videos {
                    if let urlString = video.thumbnail_url, let url = URL(string: urlString) {
                        mediaURLs.append(url)
                        print("   ✅ Video thumbnail eklendi: \(urlString.prefix(80))...")
                    }
                }
            }
        }
        
        print("🖼️ Toplam media URL: \(mediaURLs.count)")
        
        // Tarih parse
        var createdAt: Date?
        if let dateString = fxTweet.created_at {
            // ISO 8601 formatı
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: dateString)
            
            // Alternatif format: "Sat Jun 10 12:34:56 +0000 2023"
            if createdAt == nil {
                let altFormatter = DateFormatter()
                altFormatter.dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
                altFormatter.locale = Locale(identifier: "en_US_POSIX")
                createdAt = altFormatter.date(from: dateString)
            }
            
            // Alternatif format 2: RFC 2822
            if createdAt == nil {
                let rfc2822Formatter = DateFormatter()
                rfc2822Formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                rfc2822Formatter.locale = Locale(identifier: "en_US_POSIX")
                createdAt = rfc2822Formatter.date(from: dateString)
            }
        }
        
        // Avatar URL
        var avatarURL: URL? = nil
        if let avatarString = fxTweet.author?.avatar_url {
            avatarURL = URL(string: avatarString)
            print("👤 Avatar URL: \(avatarString)")
        }
        
        let tweet = Tweet(
            id: fxTweet.id ?? "",
            text: fxTweet.text ?? "",
            authorName: fxTweet.author?.name ?? "Unknown",
            authorUsername: fxTweet.author?.screen_name ?? "unknown",
            authorAvatarURL: avatarURL,
            mediaURLs: mediaURLs,
            createdAt: createdAt,
            likeCount: fxTweet.likes ?? 0,
            retweetCount: fxTweet.retweets ?? 0,
            replyCount: fxTweet.replies ?? 0,
            originalURL: originalURL
        )
        
        print("✅ Tweet oluşturuldu: hasMedia = \(tweet.hasMedia)")
        
        return tweet
    }
}

// MARK: - Error Types

enum TwitterError: LocalizedError {
    case invalidURL
    case networkError
    case apiError(statusCode: Int)
    case tweetNotFound
    case parseError
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz Twitter URL'i"
        case .networkError:
            return "Ağ bağlantısı hatası"
        case .apiError(let code):
            return "API hatası (kod: \(code))"
        case .tweetNotFound:
            return "Tweet bulunamadı veya silindi"
        case .parseError:
            return "Tweet verisi okunamadı"
        case .rateLimited:
            return "Çok fazla istek, lütfen bekleyin"
        }
    }
}
