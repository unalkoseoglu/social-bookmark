//
//  AddBookmarkViewModel.swift
//  Social Bookmark
//
//  ✅ DÜZELTME: Tüm hatalar giderildi
//  - URLValidator scope hatası düzeltildi
//  - TwitterError.parsingError -> .parseError
//  - RedditPost.imageURLs -> .imageURL (tek URL)
//  - LinkedInPost.summary -> .content
//  - MediumPost.summary -> .subtitle
//  - URL -> String dönüşümleri düzeltildi
//  - Static metinler lokalize edildi

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
    
    // MARK: - Category & Organization State
    
    var selectedCategoryId: UUID?
    private(set) var categories: [Category] = []
    private(set) var isLoadingCategories = true
    
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
    
    // MARK: - Saving State
    private(set) var isSaving = false
    private(set) var saveError: String?
    
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
    
    // MARK: - Document State (YENİ)
    
    var selectedFileURL: URL? {
        didSet {
            if let url = selectedFileURL {
                processSelectedFile(url)
            }
        }
    }
    private(set) var selectedFileData: Data?
    private(set) var fileName: String?
    private(set) var fileExtension: String?
    private(set) var fileSize: Int64?
    private(set) var isProcessingFile = false
    
    // MARK: - Service Error
    
    private(set) var serviceError: ServiceError?
        
    /// Hata mesajı gösteriliyor mu?
    var showingServiceError: Bool {
        get { serviceError != nil }
        set { if !newValue { serviceError = nil } }
    }
    
    enum ServiceError: LocalizedError, Identifiable {
        case twitter(TwitterError)
        case reddit(RedditService.RedditError)
        case linkedin(LinkedInService.LinkedInError)
        case medium(MediumService.MediumError)
        case network(String)
        case unknown(String)
        
        var id: String {
            switch self {
            case .twitter: return "x.com"
            case .reddit: return "reddit"
            case .linkedin: return "linkedin"
            case .medium: return "medium"
            case .network: return "network"
            case .unknown: return "unknown"
            }
        }
        
        var errorDescription: String? {
            switch self {
            case .twitter(let error):
                return error.errorDescription
            case .reddit(let error):
                return error.errorDescription
            case .linkedin(let error):
                return error.errorDescription
            case .medium(let error):
                return error.errorDescription
            case .network(let message):
                return message
            case .unknown(let message):
                return message
            }
        }
        
        /// Kullanıcı dostu hata mesajı
        var userMessage: String {
            switch self {
            case .twitter(let error):
                switch error {
                case .tweetNotFound:
                    return String(localized: "error.twitter.not_found")
                case .invalidURL:
                    return String(localized: "error.twitter.invalid_url")
                case .networkError:
                    return String(localized: "error.network")
                case .parseError:  // ✅ DÜZELTME: parsingError -> parseError
                    return String(localized: "error.twitter.parse")
                case .rateLimited:
                    return String(localized: "error.rate_limited")
                default:
                    return String(localized: "error.twitter.generic")
                }
            case .reddit(let error):
                return error.localizedDescription
            case .linkedin(let error):
                return error.localizedDescription
            case .medium(let error):
                return error.localizedDescription
            case .network(let message):
                return "🌐 \(message)"
            case .unknown(let message):
                return "⚠️ \(message)"
            }
        }
        
        /// Hata için platform rengi
        var platformColor: Color {
            switch self {
            case .twitter: return .blue
            case .reddit: return .orange
            case .linkedin: return Color(red: 0, green: 0.47, blue: 0.71)
            case .medium: return .primary
            case .network, .unknown: return .red
            }
        }
        
        /// Kısmi veri var mı?
        var hasPartialData: Bool {
            switch self {
            case .linkedin(let error):
                return error == .authRequired || error == .botDetected
            default:
                return false
            }
        }
    }
    
    // MARK: - Clear All
    func clearAll() {
        // URL'yi temizle
        url = ""
        
        // Başlık ve notları temizle
        title = ""
        note = ""
        
        // Fetch edilen içerikleri temizle
        fetchedTweet = nil
        fetchedRedditPost = nil
        fetchedLinkedInContent = nil
        fetchedMetadata = nil
        
        // Görsel verilerini temizle
        tweetImagesData = []
        redditImagesData = []
        linkedInImageData = nil
        
        // Kaynak seçimini sıfırla
        selectedSource = .other
        
        // Tags'i temizle
        tagsInput = ""
        
        // Document state'i temizle
        selectedFileURL = nil
        selectedFileData = nil
        fileName = nil
        fileExtension = nil
        fileSize = nil
        
        // Validation errors'ı temizle
        validationErrors = []
    }
    
    // MARK: - Dependencies
    
    private let repository: BookmarkRepositoryProtocol
    private let categoryRepository: CategoryRepositoryProtocol
    
    init(repository: BookmarkRepositoryProtocol, categoryRepository: CategoryRepositoryProtocol) {
        self.repository = repository
        self.categoryRepository = categoryRepository
        loadCategories()
    }
    
    // MARK: - Public Methods
    
    /// Kategorileri yükle
    func loadCategories() {
        isLoadingCategories = true
        categories = categoryRepository.fetchAll()
        isLoadingCategories = false
        print("📝 AddBookmarkViewModel loaded \(self.categories.count) categories")
    }
    
    /// Bookmark kaydetme
    @discardableResult
    func saveBookmark(withImage imageData: Data? = nil, extractedText: String? = nil) async -> Bool {
        guard validate() else { return false }
        
        await MainActor.run {
            isSaving = true
            saveError = nil
        }
        
        defer {
            Task { @MainActor in
                isSaving = false
            }
        }

        let parsedTags = parseTags(from: tagsInput)
        let sanitizedURL = url.isEmpty ? nil : URLValidator.sanitize(url)

        let finalImageData: Data? = {
            if let first = tweetImagesData.first { return first }
            if let first = redditImagesData.first { return first }
            if let linkedin = linkedInImageData { return linkedin }
            if let medium = mediumImageData { return medium }
            return imageData
        }()

        let finalImagesData: [Data]? = {
            if !tweetImagesData.isEmpty { return tweetImagesData }
            if !redditImagesData.isEmpty { return redditImagesData }
            return nil
        }()

        let newBookmark = Bookmark(
            title: title.trimmingCharacters(in: .whitespaces),
            url: sanitizedURL,
            note: note.trimmingCharacters(in: .whitespaces),
            source: selectedSource,
            categoryId: selectedCategoryId,
            tags: parsedTags,
            imageData: finalImageData,
            imagesData: finalImagesData,
            extractedText: extractedText,
            fileURL: nil, // Bu sonra sync layer'da yüklenebilir veya burada yüklenebilir
            fileName: fileName,
            fileExtension: fileExtension,
            fileSize: fileSize
        )
        newBookmark.fileData = selectedFileData // Transient veriyi set et

        repository.create(newBookmark)
        
        print("✅ [AddBookmarkViewModel] Bookmark saved: \(newBookmark.title)")
        
        await MainActor.run {
            resetForm()
        }
        
        return true
    }
    
    // MARK: - Metadata Fetch
    
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
            fetchedMediumPost = nil
            mediumImageData = nil
        }
        
        if TwitterService.shared.isTwitterURL(url) {
            await fetchTwitterContent()
        } else if isRedditURL(url) {
            await fetchRedditContent()
        } else if isLinkedInURL(url) {
            await fetchLinkedInContent()
        } else if isMediumURL(url) {
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
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            guard !Task.isCancelled else { return }
            await fetchMetadata()
        }
    }
    
    // MARK: - Platform Detection
    
    func isRedditURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("reddit.com") || lowercased.contains("redd.it")
    }
    
    func isLinkedInURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("linkedin.com")
    }
    
    func isMediumURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("medium.com") || lowercased.contains("towardsdatascience.com")
    }
    
    // MARK: - Twitter Content
    
    private func fetchTwitterContent() async {
        do {
            let tweet = try await TwitterService.shared.fetchTweet(from: url)
            
            await MainActor.run {
                self.fetchedTweet = tweet
                
                if self.title.isEmpty {
                    // ✅ DÜZELTME: authorDisplayName -> "@username: summary" formatı
                    self.title = "@\(tweet.authorUsername): \(tweet.shortSummary)"
                }
                if self.note.isEmpty {
                    self.note = tweet.fullText
                }
            }
            
            // ✅ DÜZELTME: imageURLs -> mediaURLs
            for mediaURL in tweet.mediaURLs {
                if let data = try? await downloadImageData(from: mediaURL.absoluteString) {
                    await MainActor.run {
                        self.tweetImagesData.append(data)
                    }
                }
            }
            
        } catch let error as TwitterError {
            await MainActor.run {
                self.serviceError = .twitter(error)
            }
        } catch {
            await MainActor.run {
                self.serviceError = .unknown(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Reddit Content
    
    private func fetchRedditContent() async {
        do {
            let post = try await RedditService.shared.fetchPost(from: url)
            
            await MainActor.run {
                self.fetchedRedditPost = post
                
                if self.title.isEmpty {
                    self.title = post.title
                }
                if self.note.isEmpty {
                    // ✅ DÜZELTME: RedditPost'un summary computed property'si var
                    self.note = post.summary
                }
            }
            
            // ✅ DÜZELTME: RedditPost.imageURL tek URL (optional)
            if let imageURL = post.imageURL {
                if let data = try? await downloadImageData(from: imageURL.absoluteString) {
                    await MainActor.run {
                        self.redditImagesData.append(data)
                    }
                }
            }
            
        } catch let error as RedditService.RedditError {
            await MainActor.run {
                self.serviceError = .reddit(error)
            }
        } catch {
            await MainActor.run {
                self.serviceError = .unknown(error.localizedDescription)
            }
        }
    }
    
    // MARK: - LinkedIn Content
    
    private func fetchLinkedInContent() async {
        do {
            let post = try await LinkedInService.shared.fetchPost(from: url)
            
            await MainActor.run {
                self.fetchedLinkedInContent = post
                
                if self.title.isEmpty {
                    self.title = post.title
                }
                if self.note.isEmpty {
                    // ✅ DÜZELTME: LinkedInPost.content kullanılıyor (summary değil)
                    self.note = post.content
                }
            }
            
            // ✅ DÜZELTME: imageURL zaten URL? tipinde
            if let imageURL = post.imageURL {
                if let data = try? await downloadImageData(from: imageURL.absoluteString) {
                    await MainActor.run {
                        self.linkedInImageData = data
                    }
                }
            }
            
        } catch let error as LinkedInService.LinkedInError {
            await MainActor.run {
                self.serviceError = .linkedin(error)
            }
        } catch {
            await MainActor.run {
                self.serviceError = .unknown(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Medium Content
    
    private func fetchMediumContent() async {
        do {
            let post = try await MediumService.shared.fetchPost(from: url)
            
            await MainActor.run {
                self.fetchedMediumPost = post
                
                if self.title.isEmpty {
                    self.title = post.title
                }
                if self.note.isEmpty {
                    // ✅ DÜZELTME: MediumPost.subtitle kullanılıyor (summary değil)
                    if !post.subtitle.isEmpty {
                        self.note = post.subtitle
                        if post.hasFullContent {
                            self.note += "\n\n" + post.fullContent
                        }
                    } else if post.hasFullContent {
                        self.note = post.fullContent
                    }
                }
            }
            
            // ✅ DÜZELTME: imageURL zaten URL? tipinde
            if let imageURL = post.imageURL {
                if let data = try? await downloadImageData(from: imageURL.absoluteString) {
                    await MainActor.run {
                        self.mediumImageData = data
                    }
                }
            }
            
        } catch let error as MediumService.MediumError {
            await MainActor.run {
                self.serviceError = .medium(error)
            }
        } catch {
            await MainActor.run {
                self.serviceError = .unknown(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Generic Metadata
    
    private func fetchGenericMetadata() async {
        guard let metadata = try? await URLMetadataService.shared.fetchMetadata(from: url) else {
            return
        }
        
        await MainActor.run {
            self.fetchedMetadata = metadata
            
            if self.title.isEmpty {
                self.title = metadata.title ?? ""
            }
            if self.note.isEmpty {
                self.note = metadata.description ?? ""
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func downloadImageData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    func validate() -> Bool {
        validationErrors.removeAll()
        
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append(String(localized: "validation.title_required"))
        }
        
        if !url.isEmpty && !isURLValid {
            validationErrors.append(String(localized: "validation.invalid_url"))
        }
        
        return validationErrors.isEmpty
    }
    
    private func parseTags(from input: String) -> [String] {
        input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    func resetForm() {
        title = ""
        url = ""
        note = ""
        selectedSource = .other
        tagsInput = ""
        selectedCategoryId = nil
        
        fetchedTweet = nil
        tweetImagesData = []
        fetchedRedditPost = nil
        redditImagesData = []
        fetchedLinkedInContent = nil
        linkedInImageData = nil
        fetchedMediumPost = nil
        mediumImageData = nil
        fetchedMetadata = nil
        
        validationErrors = []
        serviceError = nil
        validationErrors = []
        serviceError = nil
        saveError = nil
        
        selectedFileURL = nil
        selectedFileData = nil
        fileName = nil
        fileExtension = nil
        fileSize = nil
        isProcessingFile = false
    }

    // MARK: - Document Processing (YENİ)

    private func processSelectedFile(_ url: URL) {
        isProcessingFile = true
        
        Task {
            // Güvenlik: URL'e erişim izni al
            guard url.startAccessingSecurityScopedResource() else {
                isProcessingFile = false
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                let name = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                let size = Int64(data.count)
                
                await MainActor.run {
                    self.selectedFileData = data
                    self.fileName = name
                    self.fileExtension = ext
                    self.fileSize = size
                    self.selectedSource = .document
                    
                    if self.title.isEmpty {
                        self.title = name
                    }
                }
                
                // PDF ise metin çıkar
                if ext == "pdf" {
                    let result = try await PDFService.shared.extractText(from: url)
                    
                    await MainActor.run {
                        if !result.cleanText.isEmpty {
                            if self.note.isEmpty {
                                self.note = result.cleanText
                            } else {
                                self.note += "\n\n---\n\n" + result.cleanText
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    self.isProcessingFile = false
                }
            } catch {
                print("❌ [AddBookmarkViewModel] File processing failed: \(error)")
                await MainActor.run {
                    self.isProcessingFile = false
                }
            }
        }
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
