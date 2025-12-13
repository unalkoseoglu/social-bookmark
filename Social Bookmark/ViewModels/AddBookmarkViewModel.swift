import SwiftUI
import Observation

@Observable
final class AddBookmarkViewModel {
    // MARK: - Form State
    
    var title = ""
    
    var url = "" {
        didSet {
            if !url.isEmpty {
                selectedSource = BookmarkSource.detect(from: url)
                debounceMetadataFetch()
            }
        }
    }
    
    var note = ""
    var selectedSource = BookmarkSource.other
    var tagsInput = ""
    
    // MARK: - Validation State
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var isURLValid: Bool {
        url.isEmpty || URLValidator.isValid(url)
    }
    
    private(set) var validationErrors: [String] = []
    private(set) var isLoadingMetadata = false
    private(set) var fetchedMetadata: URLMetadataService.URLMetadata?
    private var metadataFetchTask: Task<Void, Never>?
    
    // MARK: - Twitter State
    
    private(set) var fetchedTweet: TwitterService.Tweet?
    private(set) var fetchedLinkedInContent: LinkedInContent?
    
    /// Tüm tweet görselleri (çoklu destek) ← YENİ
    private(set) var tweetImagesData: [Data] = []
    
    /// İlk görsel (geriye uyumluluk için)
    var tweetImageData: Data? {
        tweetImagesData.first
    }
    
    /// Tüm görseller UIImage olarak
    var tweetImages: [UIImage] {
        tweetImagesData.compactMap { UIImage(data: $0) }
    }
    
    // MARK: - Dependencies
    
    private let repository: BookmarkRepositoryProtocol
    private let linkedinAuthClient: LinkedInAuthProviding
    private let linkedinContentClient: LinkedInContentProviding
    private let linkedinHTMLParser: LinkedInHTMLParsing

    init(
        repository: BookmarkRepositoryProtocol,
        linkedinAuthClient: LinkedInAuthProviding = LinkedInAuthClient(),
        linkedinContentClient: LinkedInContentProviding = LinkedInContentClient(),
        linkedinHTMLParser: LinkedInHTMLParsing = LinkedInHTMLParser()
    ) {
        self.repository = repository
        self.linkedinAuthClient = linkedinAuthClient
        self.linkedinContentClient = linkedinContentClient
        self.linkedinHTMLParser = linkedinHTMLParser
    }
    
    // MARK: - Public Methods
    
    @discardableResult
    func saveBookmark(withImage imageData: Data? = nil, extractedText: String? = nil) -> Bool {
        guard validate() else { return false }
        
        let parsedTags = parseTags(from: tagsInput)
        let sanitizedURL = url.isEmpty ? nil : URLValidator.sanitize(url)
        
        // Görsel verilerini hazırla
        let finalImageData = tweetImagesData.first ?? imageData  // Geriye uyumluluk
        let finalImagesData = tweetImagesData.isEmpty ? nil : tweetImagesData  // Çoklu görseller
        
        let newBookmark = Bookmark(
            title: title.trimmingCharacters(in: .whitespaces),
            url: sanitizedURL,
            note: note.trimmingCharacters(in: .whitespaces),
            source: selectedSource,
            tags: parsedTags,
            imageData: finalImageData,
            imagesData: finalImagesData,
            extractedText: extractedText
        )
        
        repository.create(newBookmark)
        resetForm()
        
        return true
    }
    
    func fetchMetadata() async {
        guard !url.isEmpty, isURLValid else { return }
        
        await MainActor.run {
            isLoadingMetadata = true
            fetchedTweet = nil
            fetchedLinkedInContent = nil
            tweetImagesData = []
        }

        if isLinkedInURL(url) {
            await fetchLinkedInContent()
        } else if TwitterService.shared.isTwitterURL(url) {
            await fetchTwitterContent()
        } else {
            await fetchGenericMetadata()
        }
        
        await MainActor.run {
            isLoadingMetadata = false
        }
    }
    
    private func debounceMetadataFetch() {
        metadataFetchTask?.cancel()
        
        metadataFetchTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            if !Task.isCancelled {
                await fetchMetadata()
            }
        }
    }

    // MARK: - LinkedIn Methods

    private func fetchLinkedInContent() async {
        guard let linkURL = URL(string: url) else { return }

        do {
            let token = try await linkedinAuthClient.ensureValidToken()
            let content = try await linkedinContentClient.fetchContent(from: linkURL, token: token)

            await applyLinkedInContent(content)
        } catch LinkedInError.authorizationRequired {
            await fetchLinkedInContentViaHTML(linkURL)
        } catch LinkedInError.missingCredentials {
            await fetchLinkedInContentViaHTML(linkURL)
        } catch {
            print("❌ LinkedIn hatası: \(error.localizedDescription)")
            await fetchLinkedInContentViaHTML(linkURL)
        }
    }

    private func fetchLinkedInContentViaHTML(_ url: URL) async {
        do {
            let content = try await linkedinHTMLParser.parseContent(from: url)
            await applyLinkedInContent(content)
        } catch {
            print("❌ LinkedIn HTML parse hatası: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func applyLinkedInContent(_ content: LinkedInContent) {
        fetchedLinkedInContent = content

        if title.isEmpty {
            title = content.title
        }

        if note.isEmpty {
            note = content.summary
        }

        selectedSource = .linkedin
    }
    
    func resetForm() {
        title = ""
        url = ""
        note = ""
        selectedSource = .other
        tagsInput = ""
        validationErrors = []
        fetchedMetadata = nil
        isLoadingMetadata = false
        metadataFetchTask?.cancel()
        fetchedTweet = nil
        fetchedLinkedInContent = nil
        tweetImagesData = []
    }
    
    // MARK: - Twitter Methods
    
    private func fetchTwitterContent() async {
        do {
            let tweet = try await TwitterService.shared.fetchTweet(from: url)
            
            await MainActor.run {
                fetchedTweet = tweet
                
                if title.isEmpty {
                    title = "@\(tweet.authorUsername): \(tweet.shortSummary)"
                }
                
                if note.isEmpty {
                    note = tweet.fullText
                }
                
                selectedSource = .twitter
            }
            
            print("🐦 Tweet çekildi: @\(tweet.authorUsername)")
            print("🖼️ Toplam görsel sayısı: \(tweet.mediaURLs.count)")
            
            // TÜM GÖRSELLERİ İNDİR ← YENİ
            if !tweet.mediaURLs.isEmpty {
                await downloadAllTweetImages(from: tweet.mediaURLs)
            }
            
        } catch {
            print("❌ Twitter hatası: \(error.localizedDescription)")
            await fetchGenericMetadata()
        }
    }
    
    /// Tüm tweet görsellerini indir ← YENİ
    private func downloadAllTweetImages(from urls: [URL]) async {
        print("⬇️ \(urls.count) görsel indiriliyor...")
        
        // Paralel indirme için TaskGroup kullan
        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    do {
                        print("   ⬇️ [\(index + 1)/\(urls.count)] İndiriliyor: \(url.lastPathComponent)")
                        let (data, response) = try await URLSession.shared.data(from: url)
                        
                        if let httpResponse = response as? HTTPURLResponse,
                           httpResponse.statusCode == 200,
                           data.count > 1000 {
                            print("   ✅ [\(index + 1)] İndirildi: \(data.count) bytes")
                            return (index, data)
                        }
                    } catch {
                        print("   ❌ [\(index + 1)] Hata: \(error.localizedDescription)")
                    }
                    return (index, nil)
                }
            }
            
            // Sonuçları topla ve sırala
            var results: [(Int, Data)] = []
            for await (index, data) in group {
                if let data = data {
                    results.append((index, data))
                }
            }
            
            // Index'e göre sırala (orijinal sırayı koru)
            results.sort { $0.0 < $1.0 }
            let sortedData = results.map { $0.1 }
            
            await MainActor.run {
                tweetImagesData = sortedData
                print("✅ Toplam \(sortedData.count) görsel indirildi")
            }
        }
    }
    
    private func fetchGenericMetadata() async {
        do {
            let metadata = try await URLMetadataService.shared.fetchMetadata(from: url)
            
            await MainActor.run {
                if title.isEmpty, let metaTitle = metadata.title {
                    let cleanTitle = cleanMetaTitle(metaTitle)
                    title = String(cleanTitle.prefix(200))
                }
                
                if note.isEmpty, let metaDescription = metadata.description {
                    let cleanDescription = metaDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    note = String(cleanDescription.prefix(500))
                }
                
                fetchedMetadata = metadata
            }
        } catch {
            do {
                let metadata = try await URLMetadataService.shared.fetchMetadataFallback(from: url)
                
                await MainActor.run {
                    if title.isEmpty, let metaTitle = metadata.title {
                        title = metaTitle
                    }
                    
                    if note.isEmpty, let metaDescription = metadata.description {
                        note = metaDescription
                    }
                    
                    fetchedMetadata = metadata
                }
            } catch {
                print("❌ Metadata çekilemedi: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Validation
    
    private func validate() -> Bool {
        validationErrors = []
        
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("Başlık gerekli")
        }
        
        if title.count > 200 {
            validationErrors.append("Başlık çok uzun (max 200 karakter)")
        }
        
        if !url.isEmpty && !isURLValid {
            validationErrors.append("Geçersiz URL formatı")
        }
        
        if note.count > 5000 {
            validationErrors.append("Not çok uzun (max 5000 karakter)")
        }
        
        return validationErrors.isEmpty
    }
    
    // MARK: - Helpers
    
    private func parseTags(from input: String) -> [String] {
        input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func isLinkedInURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()

        guard lowercased.contains("linkedin.com") else { return false }

        return lowercased.contains("/posts/") ||
        lowercased.contains("/feed/update/") ||
        lowercased.contains("/company/") ||
        lowercased.contains("/in/")
    }
    
    private func cleanMetaTitle(_ title: String) -> String {
        var cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        
        if let pipeIndex = cleaned.firstIndex(of: "|") {
            let beforePipe = cleaned[..<pipeIndex].trimmingCharacters(in: .whitespaces)
            if !beforePipe.isEmpty && beforePipe.count > 10 {
                cleaned = beforePipe
            }
        }
        
        if let dashIndex = cleaned.lastIndex(of: "-") {
            let beforeDash = cleaned[..<dashIndex].trimmingCharacters(in: .whitespaces)
            if !beforeDash.isEmpty && beforeDash.count > 10 {
                cleaned = beforeDash
            }
        }
        
        return cleaned
    }
}

// MARK: - URLValidator

struct URLValidator {
    static func isValid(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    static func sanitize(_ urlString: String) -> String {
        var sanitized = urlString.trimmingCharacters(in: .whitespaces)
        
        if !sanitized.hasPrefix("http://") && !sanitized.hasPrefix("https://") {
            sanitized = "https://" + sanitized
        }
        
        return sanitized
    }
}
