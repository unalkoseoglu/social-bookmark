import Foundation

/// URL doğrulama ve metin içinden URL bulma işlemlerini yönetir
struct URLValidator {
    /// URL formatı geçerli mi kontrolü
    static func isValid(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    /// URL'i temizler ve başına http ekler (yoksa)
    static func sanitize(_ urlString: String) -> String {
        var sanitized = urlString.trimmingCharacters(in: .whitespaces)
        
        if !sanitized.hasPrefix("http://") && !sanitized.hasPrefix("https://") {
            sanitized = "https://" + sanitized
        }
        
        return sanitized
    }
    
    /// Metin içinde geçen ilk URL'i bulur
    static func findFirstURL(in text: String) -> String? {
        guard !text.isEmpty else { return nil }
        
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
            if let firstMatch = matches.first, let url = firstMatch.url {
                return url.absoluteString
            }
        } catch {
            print("❌ [URLValidator] NSDataDetector error: \(error)")
        }
        
        return nil
    }
}

