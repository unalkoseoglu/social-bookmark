import SwiftUI

// MARK: - Reddit Service (Share Extension için basitleştirilmiş)

struct RedditService {
    static let shared = RedditService()
    private init() {}
    
    func isRedditURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("reddit.com/r/") || lowercased.contains("redd.it/")
    }
    
    func fetchPost(from urlString: String) async throws -> RedditPost {
        // URL'den post ID'sini çıkar
        guard let postID = extractPostID(from: urlString) else {
            throw RedditError.invalidURL
        }
        
        // JSON API URL'i oluştur
        let jsonURL = urlString.hasSuffix(".json") ? urlString : urlString + ".json"
        
        guard let url = URL(string: jsonURL) else {
            throw RedditError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // JSON parse et
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstItem = json.first,
              let dataDict = firstItem["data"] as? [String: Any],
              let children = dataDict["children"] as? [[String: Any]],
              let postData = children.first?["data"] as? [String: Any] else {
            throw RedditError.parseError
        }
        
        // Post bilgilerini çıkar
        let title = postData["title"] as? String ?? ""
        let author = postData["author"] as? String ?? "deleted"
        let subreddit = postData["subreddit"] as? String ?? ""
        let selftext = postData["selftext"] as? String ?? ""
        let score = postData["score"] as? Int ?? 0
        let numComments = postData["num_comments"] as? Int ?? 0
        let permalink = postData["permalink"] as? String ?? ""
        
        // Görsel URL'i çıkar
        var imageURL: URL? = nil
        
        // 1. Önce URL field'a bak
        if let urlString = postData["url"] as? String,
           let url = URL(string: urlString),
           (urlString.contains("i.redd.it") || urlString.contains("i.imgur.com")) {
            imageURL = url
        }
        
        // 2. Preview'a bak
        if imageURL == nil,
           let preview = postData["preview"] as? [String: Any],
           let images = preview["images"] as? [[String: Any]],
           let firstImage = images.first,
           let source = firstImage["source"] as? [String: Any],
           let urlString = source["url"] as? String {
            // HTML entities decode
            let decoded = urlString
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
            imageURL = URL(string: decoded)
        }
        
        return RedditPost(
            title: title,
            author: author,
            subreddit: subreddit,
            selfText: selftext,
            imageURL: imageURL,
            score: score,
            commentCount: numComments,
            originalURL: URL(string: "https://reddit.com\(permalink)")!
        )
    }
    
    private func extractPostID(from urlString: String) -> String? {
        // reddit.com/r/subreddit/comments/POST_ID/...
        let patterns = [
            #"/comments/([a-z0-9]+)"#,
            #"redd\.it/([a-z0-9]+)"#
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
    
    enum RedditError: Error {
        case invalidURL
        case parseError
        case networkError
    }
}

// MARK: - Reddit Post Model

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

// MARK: - ShareExtensionView

/// Safari Extension'dan açılan SwiftUI view
struct ShareExtensionView: View {
    // MARK: - Properties
    
    let url: URL
    let repository: BookmarkRepositoryProtocol
    let onSave: () -> Void
    let onCancel: () -> Void
    
    // MARK: - State
    
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var selectedSource: BookmarkSource = .other
    @State private var tagsInput: String = ""
    
    @State private var isLoadingMetadata = false
    @State private var isSaving = false
    
    @State private var fetchedTweet: TwitterService.Tweet?
    @State private var tweetImagesData: [Data] = []
    
    @State private var fetchedRedditPost: RedditPost?
    @State private var redditImageData: Data?
    
    @State private var fetchedMetadata: URLMetadataService.URLMetadata?
    
    @FocusState private var focusedField: Field?
    
    // MARK: - Computed
    
    private var tweetImages: [UIImage] {
        tweetImagesData.compactMap { UIImage(data: $0) }
    }
    
    private var redditImage: UIImage? {
        guard let data = redditImageData else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                urlSection
                
                if let tweet = fetchedTweet {
                    tweetPreviewSection(tweet: tweet)
                }
                
                if let reddit = fetchedRedditPost {
                    redditPreviewSection(reddit: reddit)
                }
                
                basicInfoSection
                detailsSection
                tagsSection
            }
            .navigationTitle("Bookmark Kaydet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .disabled(isSaving)
            .task { await fetchContent() }
        }
    }
    
    // MARK: - Sections
    
    private var urlSection: some View {
        Section {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.blue)
                
                Text(url.absoluteString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                if TwitterService.shared.isTwitterURL(url.absoluteString) {
                    Image(systemName: "bird.fill")
                        .foregroundStyle(.blue)
                } else if RedditService.shared.isRedditURL(url.absoluteString) {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Kaynak")
        }
    }
    
    @ViewBuilder
    private func tweetPreviewSection(tweet: TwitterService.Tweet) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bird.fill").foregroundStyle(.blue)
                    Text("Tweet Önizleme").font(.headline)
                    Spacer()
                    if tweetImagesData.count > 1 {
                        Text("\(tweetImagesData.count) görsel")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                
                Divider()
                
                Text(tweet.text)
                    .font(.body)
                    .lineLimit(8)
                
                if !tweetImages.isEmpty {
                    tweetImagesGallery
                }
                
                HStack(spacing: 20) {
                    Label(formatCount(tweet.likeCount), systemImage: "heart.fill")
                        .foregroundStyle(.red)
                    Label(formatCount(tweet.retweetCount), systemImage: "arrow.2.squarepath")
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private var tweetImagesGallery: some View {
        let images = tweetImages
        
        if images.count == 1 {
            Image(uiImage: images[0])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if images.count >= 2 {
            HStack(spacing: 4) {
                ForEach(0..<min(2, images.count), id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    @ViewBuilder
    private func redditPreviewSection(reddit: RedditPost) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "circle.fill").foregroundStyle(.orange)
                    Text("Reddit Önizleme").font(.headline)
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                
                Divider()
                
                HStack {
                    Text("r/\(reddit.subreddit)")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(reddit.authorDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(reddit.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if !reddit.selfText.isEmpty {
                    Text(reddit.selfText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
                
                if let image = redditImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                HStack(spacing: 16) {
                    Label(formatCount(reddit.score), systemImage: "arrow.up")
                        .foregroundStyle(.orange)
                    Label("\(formatCount(reddit.commentCount)) yorum", systemImage: "bubble.right")
                        .foregroundStyle(.blue)
                }
                .font(.caption)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
    
    private var basicInfoSection: some View {
        Section("Temel Bilgiler") {
            TextField("Başlık", text: $title, axis: .vertical)
                .lineLimit(2...4)
            
            Picker("Kaynak", selection: $selectedSource) {
                ForEach(BookmarkSource.allCases) { source in
                    Text(source.displayName).tag(source)
                }
            }
            
            if fetchedTweet != nil || fetchedRedditPost != nil {
                HStack {
                    Label("İçerik çekildi", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }
        }
    }
    
    private var detailsSection: some View {
        Section("Notlar") {
            TextField("Notlarınızı buraya ekleyin", text: $note, axis: .vertical)
                .lineLimit(3...10)
        }
    }
    
    private var tagsSection: some View {
        Section {
            TextField("Etiketler (virgülle ayır)", text: $tagsInput)
        } header: {
            Text("Etiketler")
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("İptal") { onCancel() }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button("Kaydet") { saveBookmark() }
                .disabled(title.isEmpty || isSaving)
        }
    }
    
    // MARK: - Actions
    
    private func fetchContent() async {
        isLoadingMetadata = true
        selectedSource = BookmarkSource.detect(from: url.absoluteString)
        
        if TwitterService.shared.isTwitterURL(url.absoluteString) {
            await fetchTwitterContent()
        } else if RedditService.shared.isRedditURL(url.absoluteString) {
            await fetchRedditContent()
        } else {
            await fetchGenericMetadata()
        }
        
        isLoadingMetadata = false
    }
    
    private func fetchTwitterContent() async {
        do {
            let tweet = try await TwitterService.shared.fetchTweet(from: url.absoluteString)
            await MainActor.run {
                fetchedTweet = tweet
                if title.isEmpty { title = "@\(tweet.authorUsername): \(tweet.shortSummary)" }
                if note.isEmpty { note = tweet.fullText }
                selectedSource = .twitter
            }
            if !tweet.mediaURLs.isEmpty {
                await downloadTweetImages(from: tweet.mediaURLs)
            }
        } catch {
            await fetchGenericMetadata()
        }
    }
    
    private func downloadTweetImages(from urls: [URL]) async {
        var images: [Data] = []
        for url in urls.prefix(4) {
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                images.append(data)
            }
        }
        await MainActor.run {
            tweetImagesData = images
        }
    }
    
    private func fetchRedditContent() async {
        do {
            let post = try await RedditService.shared.fetchPost(from: url.absoluteString)
            await MainActor.run {
                fetchedRedditPost = post
                if title.isEmpty { title = post.title }
                if note.isEmpty { note = !post.selfText.isEmpty ? post.selfText : post.subtitle }
                selectedSource = .reddit
            }
            if let imageURL = post.imageURL {
                if let (data, _) = try? await URLSession.shared.data(from: imageURL) {
                    await MainActor.run {
                        redditImageData = data
                    }
                }
            }
        } catch {
            await fetchGenericMetadata()
        }
    }
    
    private func fetchGenericMetadata() async {
        // Basit fallback
        await MainActor.run {
            if title.isEmpty {
                title = url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
            }
        }
    }
    
    private func saveBookmark() {
        isSaving = true
        
        let parsedTags = tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let finalImageData = tweetImagesData.first ?? redditImageData
        let finalImagesData = !tweetImagesData.isEmpty ? tweetImagesData : nil
        
        let newBookmark = Bookmark(
            title: title.trimmingCharacters(in: .whitespaces),
            url: url.absoluteString,
            note: note.trimmingCharacters(in: .whitespaces),
            source: selectedSource,
            tags: parsedTags,
            imageData: finalImageData,
            imagesData: finalImagesData
        )
        
        repository.create(newBookmark)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSave()
        }
    }
    
    enum Field: Hashable {
        case title, note, tags
    }
}
