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
    private(set) var tweetImagesData: [Data] = []
    
    var tweetImageData: Data? {
        tweetImagesData.first
    }
    
    var tweetImages: [UIImage] {
        tweetImagesData.compactMap { UIImage(data: $0) }
    }
    
    // MARK: - Reddit State
    
    private(set) var fetchedRedditPost: RedditPost?
    private(set) var redditImagesData: [Data] = []
    
    var redditImages: [UIImage] {
        redditImagesData.compactMap { UIImage(data: $0) }
    }
    
    // MARK: - LinkedIn State
    
    private(set) var fetchedLinkedInContent: LinkedInPost?
    private(set) var linkedInImageData: Data?
    
    var linkedInImage: UIImage? {
        guard let data = linkedInImageData else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - Medium State
    
    private(set) var fetchedMediumPost: MediumPost?
    private(set) var mediumImageData: Data?

    var mediumImage: UIImage? {
        guard let data = mediumImageData else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - Dependencies
    
    private let repository: BookmarkRepositoryProtocol
    
    init(repository: BookmarkRepositoryProtocol) {
        self.repository = repository
    }
    
    // MARK: - Public Methods
    
    @discardableResult
    func saveBookmark(withImage imageData: Data? = nil, extractedText: String? = nil) -> Bool {
        guard validate() else { return false }
        
        let parsedTags = parseTags(from: tagsInput)
        let sanitizedURL = url.isEmpty ? nil : URLValidator.sanitize(url)
        
        // Görsel verilerini hazırla - Twitter, Reddit, LinkedIn, Medium veya manuel
        let finalImageData: Data? = {
            if let first = tweetImagesData.first {
                return first
            } else if let first = redditImagesData.first {
                return first
            } else if let linkedin = linkedInImageData {
                return linkedin
            } else if let medium = mediumImageData {  // ← YENİ
                return medium
            } else {
                return imageData
            }
        }()
        
        let finalImagesData: [Data]? = {
            if !tweetImagesData.isEmpty {
                return tweetImagesData
            } else if !redditImagesData.isEmpty {
                return redditImagesData
            } else {
                return nil
            }
        }()
        
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
            tweetImagesData = []
            fetchedRedditPost = nil
            redditImagesData = []
            fetchedLinkedInContent = nil
            linkedInImageData = nil
            fetchedMediumPost = nil         // ← YENİ
            mediumImageData = nil            // ← YENİ
        }
        
        if TwitterService.shared.isTwitterURL(url) {
            await fetchTwitterContent()
        } else if isRedditURL(url) {
            await fetchRedditContent()
        } else if isLinkedInURL(url) {
            await fetchLinkedInContent()
        } else if isMediumURL(url) {         // ← YENİ
            await fetchMediumContent()
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
        tweetImagesData = []
        fetchedRedditPost = nil
        redditImagesData = []
        fetchedLinkedInContent = nil
        linkedInImageData = nil
        fetchedMediumPost = nil       // ← YENİ
        mediumImageData = nil          // ← YENİ
    }
    
    // MARK: - URL Validation Helpers
    
    func isRedditURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("reddit.com/r/") || lowercased.contains("redd.it/")
    }
    
    func isLinkedInURL(_ urlString: String) -> Bool {
        return LinkedInService.shared.isLinkedInURL(urlString)
    }
    
    func isMediumURL(_ urlString: String) -> Bool {
        return MediumService.shared.isMediumURL(urlString)
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
            
            if !tweet.mediaURLs.isEmpty {
                await downloadAllTweetImages(from: tweet.mediaURLs)
            }
            
        } catch {
            print("❌ Twitter hatası: \(error.localizedDescription)")
            await fetchGenericMetadata()
        }
    }
    
    private func downloadAllTweetImages(from urls: [URL]) async {
        print("⬇️ \(urls.count) görsel indiriliyor...")
        
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
            
            var results: [(Int, Data)] = []
            for await (index, data) in group {
                if let data = data {
                    results.append((index, data))
                }
            }
            
            results.sort { $0.0 < $1.0 }
            let sortedData = results.map { $0.1 }
            
            await MainActor.run {
                tweetImagesData = sortedData
                print("✅ Toplam \(sortedData.count) görsel indirildi")
            }
        }
    }
    
    // MARK: - Reddit Methods
    
    private func fetchRedditContent() async {
        do {
            let post = try await RedditService.shared.fetchPost(from: url)
            
            await MainActor.run {
                fetchedRedditPost = post
                
                if title.isEmpty {
                    title = post.title
                }
                
                if note.isEmpty {
                    if !post.selfText.isEmpty {
                        note = post.selfText
                    } else {
                        note = "r/\(post.subreddit) - \(post.title)"
                    }
                }
                
                selectedSource = .reddit
            }
            
            print("🔴 Reddit post çekildi: r/\(post.subreddit)")
            
            // Tek görsel varsa indir
            if let imageURL = post.imageURL {
                await downloadRedditImage(from: imageURL)
            }
            
        } catch {
            print("❌ Reddit hatası: \(error.localizedDescription)")
            await fetchGenericMetadata()
        }
    }
    
    /// Tek Reddit görseli indir
    private func downloadRedditImage(from url: URL) async {
        print("⬇️ Reddit görseli indiriliyor: \(url.lastPathComponent)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               data.count > 1000 {
                
                await MainActor.run {
                    redditImagesData = [data]
                    print("✅ Reddit görseli indirildi: \(data.count) bytes")
                }
            }
        } catch {
            print("❌ Reddit görsel hatası: \(error.localizedDescription)")
        }
    }
    
    // MARK: - LinkedIn Methods
    
    private func fetchLinkedInContent() async {
        do {
            let post = try await LinkedInService.shared.fetchPost(from: url)
            
            await MainActor.run {
                fetchedLinkedInContent = post
                
                if title.isEmpty {
                    title = post.title
                }
                
                if note.isEmpty {
                    note = post.displayText
                }
                
                selectedSource = .linkedin
            }
            
            print("🔵 LinkedIn post çekildi: \(post.authorName)")
            
            // Görsel varsa indir
            if let imageURL = post.imageURL {
                await downloadLinkedInImage(from: imageURL)
            }
            
        } catch {
            print("❌ LinkedIn hatası: \(error.localizedDescription)")
            await fetchGenericMetadata()
        }
    }
    
    /// LinkedIn görseli indir
    private func downloadLinkedInImage(from url: URL) async {
        print("⬇️ LinkedIn görseli indiriliyor: \(url.lastPathComponent)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               data.count > 1000 {
                
                await MainActor.run {
                    linkedInImageData = data
                    print("✅ LinkedIn görseli indirildi: \(data.count) bytes")
                }
            }
        } catch {
            print("❌ LinkedIn görsel hatası: \(error.localizedDescription)")
        }
    }
    
    //MARK: - Medium Methods
    
    private func fetchMediumContent() async {
        do {
            let post = try await MediumService.shared.fetchPost(from: url)
            
            await MainActor.run {
                fetchedMediumPost = post
                
                // Başlık
                if title.isEmpty {
                    title = post.title
                }
                
                // SUBTITLE'I NOT OLARAK KAYDET ← ÖNEMLİ
                if note.isEmpty {
                    // Subtitle varsa kullan (genelde çok iyi bir özet)
                    if !post.subtitle.isEmpty {
                        note = post.subtitle
                        
                        // Kısmi içerik varsa ekle
                        if post.hasFullContent {
                            note += "\n\n" + post.fullContent
                        }
                        
                        // Medium linki ekle
                        note += "\n\n📗 Medium'da oku: \(url)"
                    } else if post.hasFullContent {
                        note = post.fullContent + "\n\n📗 Medium'da oku: \(url)"
                    } else {
                        note = "📗 Medium'da oku: \(url)"
                    }
                }
                
                selectedSource = .medium
            }
            
            print("📗 Medium post kaydedildi:")
            print("  - Subtitle: \(post.subtitle)")
            print("  - Kısmi içerik: \(post.fullContent.count) karakter")
            
            // Görsel varsa indir
            if let imageURL = post.imageURL {
                await downloadMediumImage(from: imageURL)
            }
            
        } catch {
            print("❌ Medium hatası: \(error.localizedDescription)")
            await fetchGenericMetadata()
        }
    }

    /// Medium görseli indir
    private func downloadMediumImage(from url: URL) async {
        print("⬇️ Medium görseli indiriliyor: \(url.lastPathComponent)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               data.count > 1000 {
                
                await MainActor.run {
                    mediumImageData = data
                    print("✅ Medium görseli indirildi: \(data.count) bytes")
                }
            }
        } catch {
            print("❌ Medium görsel hatası: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Generic Metadata
    
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
