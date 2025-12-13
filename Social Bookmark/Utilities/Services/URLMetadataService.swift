import Foundation
import LinkPresentation

/// URL'den metadata (başlık, görsel, açıklama) çeken servis
/// LinkPresentation framework'ü kullanır - iOS 13+
final class URLMetadataService {
    // MARK: - Singleton
    
    static let shared = URLMetadataService()
    private init() {}
    
    // MARK: - Models
    
    /// Çekilen metadata bilgileri
    struct URLMetadata {
        let title: String?
        let description: String?
        let imageURL: URL?
        let originalURL: URL
        
        /// Başlık var mı?
        var hasTitle: Bool {
            title != nil && !(title?.isEmpty ?? true)
        }
        
        /// Açıklama var mı?
        var hasDescription: Bool {
            description != nil && !(description?.isEmpty ?? true)
        }
        
        /// Görsel var mı?
        var hasImage: Bool {
            imageURL != nil
        }
    }
    
    // MARK: - Public Methods
    
    /// URL'den metadata çek
    /// - Parameter urlString: URL string
    /// - Returns: URLMetadata veya nil (geçersiz URL ise)
    func fetchMetadata(from urlString: String) async throws -> URLMetadata {
        // URL validation
        guard let url = URL(string: urlString) else {
            throw URLMetadataError.invalidURL
        }
        
        // LinkPresentation provider oluştur
        let provider = LPMetadataProvider()
        
        // Timeout ayarla (10 saniye)
        provider.timeout = 10.0
        
        do {
            // Metadata çek
            let metadata = try await provider.startFetchingMetadata(for: url)
            
            // Paralel olarak HTML'den description çek
            var description: String? = nil
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let html = String(data: data, encoding: .utf8) {
                    description = extractMetaDescription(from: html)
                }
            } catch {
                // HTML çekilemezse devam et
            }
            
            // URLMetadata'ya çevir
            return URLMetadata(
                title: metadata.title,
                description: description,
                imageURL: metadata.imageProvider != nil ? url : nil,
                originalURL: metadata.url ?? url
            )
        } catch {
            // Hata durumunda fallback'e geç
            throw URLMetadataError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Basit HTML parsing ile metadata çek (fallback)
    /// LinkPresentation başarısız olursa bu metod kullanılır
    func fetchMetadataFallback(from urlString: String) async throws -> URLMetadata {
        guard let url = URL(string: urlString) else {
            throw URLMetadataError.invalidURL
        }
        
        // HTTP request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Response kontrolü
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLMetadataError.invalidResponse
        }
        
        // HTML'i string'e çevir
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLMetadataError.invalidData
        }
        
        // Basit regex ile title çek
        let title = extractTitle(from: html)
        let description = extractMetaDescription(from: html)
        let imageURL = extractOGImage(from: html, baseURL: url)
        
        return URLMetadata(
            title: title,
            description: description,
            imageURL: imageURL,
            originalURL: url
        )
    }
    
    // MARK: - Private Helpers
    
    /// LPLinkMetadata'dan açıklama çıkar
    private func extractDescription(from metadata: LPLinkMetadata) -> String? {
        // Not: LinkPresentation'ın kendi description field'ı yok
        // Bu yüzden HTML'den çekmemiz gerekiyor
        return nil
    }
    
    /// HTML'den <title> tag'ini çıkar
    private func extractTitle(from html: String) -> String? {
        let pattern = "<title>(.*?)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let titleRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        return String(html[titleRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
    
    /// HTML'den meta description çıkar
    private func extractMetaDescription(from html: String) -> String? {
        let pattern = "<meta[^>]*name=[\"']description[\"'][^>]*content=[\"'](.*?)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let descRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        return String(html[descRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// HTML'den og:image çıkar
    private func extractOGImage(from html: String, baseURL: URL) -> URL? {
        let pattern = "<meta[^>]*property=[\"']og:image[\"'][^>]*content=[\"'](.*?)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let imageRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        let imageString = String(html[imageRange])
        
        // Relative URL'i absolute'a çevir
        if imageString.hasPrefix("http") {
            return URL(string: imageString)
        } else if imageString.hasPrefix("//") {
            return URL(string: "https:" + imageString)
        } else if imageString.hasPrefix("/") {
            return URL(string: baseURL.scheme! + "://" + baseURL.host! + imageString)
        }
        
        return nil
    }
}

// MARK: - Error Types

enum URLMetadataError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case fetchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz URL formatı"
        case .invalidResponse:
            return "Sunucu yanıt vermedi"
        case .invalidData:
            return "Veri okunamadı"
        case .fetchFailed(let message):
            return "Metadata çekilemedi: \(message)"
        }
    }
}
