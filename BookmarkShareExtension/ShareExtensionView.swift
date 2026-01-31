import SwiftUI

// MARK: - ShareExtensionView

/// Safari Extension'dan açılan SwiftUI view
/// Ana uygulama ile birebir aynı tasarım ve servisler
struct ShareExtensionView: View {
    // MARK: - Properties
    
    let url: URL
    let repository: BookmarkRepositoryProtocol?
    let categoryRepository: CategoryRepositoryProtocol?
    let onSave: () -> Void
    let onCancel: () -> Void
    
    // MARK: - State
    
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var selectedSource: BookmarkSource = .other
    @State private var tagsInput: String = ""
    @State private var selectedCategoryId: UUID?
    @State private var categories: [Category] = []
    
    // Loading & Error States
    @State private var isLoadingMetadata = false
    @State private var isSaving = false
    @State private var serviceError: ServiceError?
    
    // Twitter State
    @State private var fetchedTweet: TwitterService.Tweet?
    @State private var tweetImagesData: [Data] = []
    
    // Reddit State
    @State private var fetchedRedditPost: RedditPost?
    @State private var redditImagesData: [Data] = []
    
    // LinkedIn State
    @State private var fetchedLinkedInPost: LinkedInPost?
    @State private var linkedInImageData: Data?
    
    // Medium State
    @State private var fetchedMediumPost: MediumPost?
    @State private var mediumImageData: Data?
    
    // Generic Metadata
    @State private var fetchedMetadata: URLMetadataService.URLMetadata?
    
    @FocusState private var focusedField: Field?
    @Environment(\.openURL) private var openURL
    
    // IAP State
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    @State private var paywallReason: String? = nil
    
    // MARK: - Computed Properties
    
    private var tweetImages: [UIImage] {
        tweetImagesData.compactMap { UIImage(data: $0) }
    }
    
    private var redditImages: [UIImage] {
        redditImagesData.compactMap { UIImage(data: $0) }
    }
    
    private var linkedInImage: UIImage? {
        guard let data = linkedInImageData else { return nil }
        return UIImage(data: data)
    }
    
    private var mediumImage: UIImage? {
        guard let data = mediumImageData else { return nil }
        return UIImage(data: data)
    }
    
    private var hasContent: Bool {
        fetchedTweet != nil || fetchedRedditPost != nil ||
        fetchedLinkedInPost != nil || fetchedMediumPost != nil
    }
    
    private var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryId }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // URL Section
                urlSection
                
                // Error Banner (if any)
                if let error = serviceError {
                    errorBannerSection(error: error)
                }
                
                // Platform-specific previews
                if let tweet = fetchedTweet {
                    tweetPreviewSection(tweet: tweet)
                }
                
                if let reddit = fetchedRedditPost {
                    redditPreviewSection(reddit: reddit)
                }
                
                if let linkedin = fetchedLinkedInPost {
                    linkedInPreviewSection(linkedin: linkedin)
                }
                
                if let medium = fetchedMediumPost {
                    mediumPreviewSection(medium: medium)
                }
                
                // Basic Info
                basicInfoSection
                
                // Category Selection
                categorySection
                
                // Notes
                detailsSection
                
                // Tags
                tagsSection
            }
            .navigationTitle(L("extension.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .disabled(isSaving)
            .task {
                subscriptionManager.configure(shouldFetch: false)
                if repository != nil {
                    loadCategories()
                }
                await fetchContent()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(reason: paywallReason)
            }
        }
    }
    
    // MARK: - Load Categories
    
    private func loadCategories() {
        guard let categoryRepository = categoryRepository else { return }
        categories = categoryRepository.fetchAll()
    }
    
    // MARK: - URL Section
    
    private var urlSection: some View {
        Section {
            HStack(spacing: 12) {
                // Platform icon
                platformIcon
                    .frame(width: 32, height: 32)
                    .background(selectedSource.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.host ?? "URL")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Loading indicator
                if isLoadingMetadata {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        } header: {
            Text(L("extension.source"))
        }
    }
    
    @ViewBuilder
    private var platformIcon: some View {
        switch selectedSource {
        case .twitter:
            Image(systemName: "bird.fill")
                .foregroundStyle(.blue)
        case .reddit:
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundStyle(.orange)
        case .linkedin:
            Image(systemName: "briefcase.fill")
                .foregroundStyle(.cyan)
        case .medium:
            Image(systemName: "doc.text.fill")
                .foregroundStyle(.green)
        default:
            Image(systemName: "link")
                .foregroundStyle(.blue)
        }
    }
    
    // MARK: - Error Banner Section
    
    @ViewBuilder
    private func errorBannerSection(error: ServiceError) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: error.icon)
                        .foregroundStyle(error.color)
                    
                    Text(error.localizedTitle)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        serviceError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(error.localizedMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if error.canOpenInBrowser {
                    Button {
                        openURL(url)
                    } label: {
                        HStack {
                            Image(systemName: "safari")
                            Text(L("extension.error.openInBrowser"))
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Tweet Preview Section
    
    @ViewBuilder
    private func tweetPreviewSection(tweet: TwitterService.Tweet) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "bird.fill")
                        .foregroundStyle(.blue)
                    Text(L("extension.preview.tweet"))
                        .font(.headline)
                    Spacer()
                    
                    if tweetImagesData.count > 1 {
                        Text(L("extension.stats.images", tweetImagesData.count))
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
                
                // Author
                HStack {
                    Text("@\(tweet.authorUsername)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                    
                    Text(tweet.authorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Content
                Text(tweet.text)
                    .font(.body)
                    .lineLimit(8)
                
                // Images
                if !tweetImages.isEmpty {
                    tweetImagesGallery
                }
                
                // Stats
                HStack(spacing: 20) {
                    Label(formatCount(tweet.likeCount), systemImage: "heart.fill")
                        .foregroundStyle(.red)
                    Label(formatCount(tweet.retweetCount), systemImage: "arrow.2.squarepath")
                        .foregroundStyle(.green)
                    Label(formatCount(tweet.replyCount), systemImage: "bubble.right")
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
            
            if images.count > 2 {
                HStack(spacing: 4) {
                    ForEach(2..<min(4, images.count), id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
    
    // MARK: - Reddit Preview Section
    
    @ViewBuilder
    private func redditPreviewSection(reddit: RedditPost) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(.orange)
                    Text(L("extension.preview.reddit"))
                        .font(.headline)
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                
                Divider()
                
                // Subreddit & Author
                HStack {
                    Text("r/\(reddit.subreddit)")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(reddit.authorDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Title
                Text(reddit.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                // Self text
                if !reddit.selfText.isEmpty {
                    Text(reddit.selfText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
                
                // Image
                if let image = redditImages.first {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Stats
                HStack(spacing: 16) {
                    Label(formatCount(reddit.score), systemImage: "arrow.up")
                        .foregroundStyle(.orange)
                    Label(L("extension.stats.comments", formatCount(reddit.commentCount)), systemImage: "bubble.right")
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
    
    // MARK: - LinkedIn Preview Section
    
    @ViewBuilder
    private func linkedInPreviewSection(linkedin: LinkedInPost) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "briefcase.fill")
                        .foregroundStyle(.cyan)
                    Text(L("extension.preview.linkedin"))
                        .font(.headline)
                    Spacer()
                    
                    if linkedin.isPartial {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                
                Divider()
                
                // Error message for partial data
                if linkedin.isPartial, let errorMessage = linkedin.userFacingErrorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Author
                VStack(alignment: .leading, spacing: 4) {
                    Text(linkedin.authorName)
                        .font(.headline)
                    
                    if !linkedin.authorTitle.isEmpty {
                        Text(linkedin.authorTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Content (if not error message)
                if linkedin.hasContent && !linkedin.content.contains("⚠️") {
                    Text(linkedin.displayText)
                        .font(.body)
                        .lineLimit(8)
                }
                
                // Image
                if let image = linkedInImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Open in browser button for partial data
                if linkedin.isPartial {
                    Button {
                        openURL(url)
                    } label: {
                        HStack {
                            Image(systemName: "safari")
                            Text(L("extension.error.openInBrowser"))
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                // Footer
                HStack {
                    Image(systemName: "link.circle.fill")
                        .foregroundStyle(.cyan)
                    Text("LinkedIn")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(linkedin.isPartial ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Medium Preview Section
    
    @ViewBuilder
    private func mediumPreviewSection(medium: MediumPost) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.green)
                    Text(L("extension.preview.medium"))
                        .font(.headline)
                    Spacer()
                    
                    if medium.isPaywalled {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                            Text(L("extension.stats.membersOnly"))
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                    }
                    
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                
                Divider()
                
                // Image
                if let image = mediumImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Title
                Text(medium.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(3)
                
                // Author & Stats
                HStack {
                    Text(medium.authorName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if medium.readTime > 0 {
                        Text(L("extension.stats.readTime", medium.readTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Subtitle
                if medium.hasSubtitle {
                    Text(medium.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
                
                // Open in Medium button
                Button {
                    openURL(medium.originalURL)
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.right.square.fill")
                        Text(L("extension.medium.readOn"))
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Footer
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(.green)
                    Text("Medium")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        Section(L("extension.basicInfo")) {
            TextField(L("extension.title.placeholder"), text: $title, axis: .vertical)
                .lineLimit(2...4)
                .focused($focusedField, equals: .title)
            
            Picker(L("extension.source.label"), selection: $selectedSource) {
                ForEach(BookmarkSource.allCases) { source in
                    HStack {
                        Text(source.emoji)
                        Text(source.displayName)
                    }
                    .tag(source)
                }
            }
            
            // Content status
            if hasContent {
                HStack {
                    Label(L("extension.contentFetched"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    
                    Spacer()
                    
                    if !tweetImagesData.isEmpty {
                        Text(L("extension.stats.images", tweetImagesData.count))
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else if !redditImagesData.isEmpty {
                        Text(L("extension.stats.images", redditImagesData.count))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
            }
        }
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        Section {
            if categories.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("extension.category.empty"))
                            .font(.subheadline)
                        Text(L("extension.category.emptyHint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Picker(L("extension.category"), selection: $selectedCategoryId) {
                    // None option
                    Label(L("extension.category.none"), systemImage: "tray")
                        .tag(nil as UUID?)
                    
                    Divider()
                    
                    // Categories
                    ForEach(categories) { category in
                        Label {
                            Text(category.name)
                        } icon: {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                        }
                        .tag(category.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text(L("extension.category"))
        } footer: {
            if let category = selectedCategory {
                Label(category.name, systemImage: category.icon)
                    .font(.caption)
                    .foregroundStyle(category.color)
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        Section(L("extension.notes")) {
            TextField(L("extension.notes.placeholder"), text: $note, axis: .vertical)
                .lineLimit(3...10)
                .focused($focusedField, equals: .note)
        }
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        Section {
            TextField(L("extension.tags.placeholder"), text: $tagsInput)
                .focused($focusedField, equals: .tags)
        } header: {
            Text(L("extension.tags"))
        } footer: {
            Text(L("extension.tags.hint"))
                .font(.caption)
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L("extension.cancel")) {
                onCancel()
            }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            if isSaving {
                ProgressView()
            } else {
                Button(L("extension.save")) {
                    saveBookmark()
                }
                .fontWeight(.semibold)
                .disabled(title.isEmpty)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
    
    // MARK: - Field Enum
    
    enum Field: Hashable {
        case title, note, tags
    }
}

// MARK: - Service Error

extension ShareExtensionView {
    enum ServiceError {
        case twitter(String)
        case reddit(String)
        case linkedin(LinkedInService.LinkedInError)
        case medium(String)
        case network(String)
        
        var localizedTitle: String {
            switch self {
            case .twitter: return L("extension.error.twitter")
            case .reddit: return L("extension.error.reddit")
            case .linkedin: return L("extension.error.linkedin")
            case .medium: return L("extension.error.medium")
            case .network: return L("extension.error.network")
            }
        }
        
        var localizedMessage: String {
            switch self {
            case .twitter(let msg): return msg
            case .reddit(let msg): return msg
            case .linkedin(let error):
                switch error {
                case .authRequired:
                    return L("extension.linkedin.authRequired")
                case .botDetected:
                    return L("extension.linkedin.botDetected")
                default:
                    return error.localizedDescription
                }
            case .medium(let msg): return msg
            case .network(let msg): return msg
            }
        }
        
        var icon: String {
            switch self {
            case .twitter: return "bird"
            case .reddit: return "bubble.left.and.bubble.right"
            case .linkedin: return "briefcase.fill"
            case .medium: return "doc.text"
            case .network: return "wifi.slash"
            }
        }
        
        var color: Color {
            switch self {
            case .twitter: return .blue
            case .reddit: return .orange
            case .linkedin: return .cyan
            case .medium: return .green
            case .network: return .red
            }
        }
        
        var canOpenInBrowser: Bool {
            switch self {
            case .linkedin(let error):
                return error == .authRequired || error == .botDetected
            default:
                return false
            }
        }
    }
}

// MARK: - Fetch Content

extension ShareExtensionView {
    
    private func fetchContent() async {
        await MainActor.run {
            isLoadingMetadata = true
            selectedSource = BookmarkSource.detect(from: url.absoluteString)
        }
        
        print("🔍 Share Extension: URL tespit edildi: \(url.absoluteString)")
        print("📊 Share Extension: Kaynak: \(selectedSource.displayName)")
        
        // Platform-specific fetch
        if TwitterService.shared.isTwitterURL(url.absoluteString) {
            await fetchTwitterContent()
        } else if RedditService.shared.isRedditURL(url.absoluteString) {
            await fetchRedditContent()
        } else if LinkedInService.shared.isLinkedInURL(url.absoluteString) {
            await fetchLinkedInContent()
        } else if MediumService.shared.isMediumURL(url.absoluteString) {
            await fetchMediumContent()
        } else {
            await fetchGenericMetadata()
        }
        
        await MainActor.run {
            isLoadingMetadata = false
        }
    }
    
    /// Metinden akıllıca bir başlık çıkarır (ilk cümle veya satır)
    private func smartTitle(from text: String, maxLength: Int = 100) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.isEmpty { return "" }
        
        // İlk satır sonunu veya cümle sonunu bul
        let delimiters: Set<Character> = [".", "!", "?", "\n"]
        var firstDelimiterIndex: String.Index? = nil
        
        for index in cleanText.indices {
            if delimiters.contains(cleanText[index]) {
                // Eğer "." ise ve sayıların arasındaysa (örn 1.5) ayırma
                if cleanText[index] == "." {
                    let nextIndex = cleanText.index(after: index)
                    if nextIndex < cleanText.endIndex, cleanText[nextIndex].isNumber {
                        continue
                    }
                }
                firstDelimiterIndex = index
                break
            }
        }
        
        if let delimiterIndex = firstDelimiterIndex {
            let sentence = cleanText[...delimiterIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count <= maxLength + 20 { // Biraz esneme payı
                return String(sentence)
            }
        }
        
        // Eğer cümle çok uzunsa veya ayraç yoksa, kelime bazlı truncate et
        if cleanText.count <= maxLength {
            return cleanText
        }
        
        let truncated = cleanText.prefix(maxLength)
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }
        
        return String(truncated) + "..."
    }
    
    /// Başlık ve not bilgilerini akıllıca ayarlar, dublikasyonu önler
    @MainActor
    private func updateMetadata(title: String, note: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var finalNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Başlığı ayarla
        if self.title.isEmpty && !trimmedTitle.isEmpty {
            self.title = trimmedTitle
        }
        
        // Notu ayarla ve dublikasyonu önle
        if self.note.isEmpty && !finalNote.isEmpty {
            let currentTitle = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 1. Başlığı notun başından çıkar
            if !currentTitle.isEmpty && finalNote.hasPrefix(currentTitle) {
                finalNote = String(finalNote.dropFirst(currentTitle.count))
            } 
            // 1b. Başlık truncated ise (... ile bitiyorsa) stem kontrolü yap
            else if currentTitle.hasSuffix("...") {
                let stem = String(currentTitle.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !stem.isEmpty && finalNote.hasPrefix(stem) {
                    finalNote = String(finalNote.dropFirst(stem.count))
                }
            }
            
            // 2. Başta kalan ayraçları ve boşlukları TEMİZLE (Döngü ile ardışık olanları temizle)
            let separators: Set<Character> = [":", "-", "—", "|", "•", "·", ".", " ", "\n", "\r"]
            while !finalNote.isEmpty && separators.contains(finalNote.first!) {
                finalNote.removeFirst()
            }
            
            self.note = finalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    // MARK: - Twitter
    
    private func fetchTwitterContent() async {
        do {
            print("🐦 TwitterService çağrılıyor...")
            let tweet = try await TwitterService.shared.fetchTweet(from: url.absoluteString)
            
            await MainActor.run {
                fetchedTweet = tweet
                
                // 1. Akıllı başlık oluştur (ilk cümle)
                let cleanTitle = smartTitle(from: tweet.text)
                updateMetadata(title: cleanTitle, note: tweet.text)
                
                // 2. Kullanıcı adını EN ALTA ekle
                if !note.isEmpty {
                    note += "\n\n— @\(tweet.authorUsername)"
                } else {
                    note = "@\(tweet.authorUsername)"
                }
                
                selectedSource = .twitter
            }
            
            print("✅ Tweet çekildi: @\(tweet.authorUsername)")
            
            // Download images
            if !tweet.mediaURLs.isEmpty {
                await downloadImages(from: tweet.mediaURLs) { data in
                    await MainActor.run {
                        tweetImagesData = data
                    }
                }
            }
            
        } catch {
            print("❌ Twitter hatası: \(error.localizedDescription)")
            await MainActor.run {
                serviceError = .twitter(error.localizedDescription)
            }
            await fetchGenericMetadata()
        }
    }
    
    // MARK: - Reddit
    
    private func fetchRedditContent() async {
        do {
            print("🔴 RedditService çağrılıyor...")
            let post = try await RedditService.shared.fetchPost(from: url.absoluteString)
            
            await MainActor.run {
                fetchedRedditPost = post
                updateMetadata(title: post.title, note: !post.selfText.isEmpty ? post.selfText : post.subtitle)
                selectedSource = .reddit
            }
            
            print("✅ Reddit çekildi: r/\(post.subreddit)")
            
            // Download image
            if let imageURL = post.imageURL {
                await downloadSingleImage(from: imageURL) { data in
                    await MainActor.run {
                        redditImagesData = [data]
                    }
                }
            }
            
        } catch {
            print("❌ Reddit hatası: \(error.localizedDescription)")
            await MainActor.run {
                serviceError = .reddit(error.localizedDescription)
            }
            await fetchGenericMetadata()
        }
    }
    
    // MARK: - LinkedIn
    
    private func fetchLinkedInContent() async {
        do {
            print("🔵 LinkedInService çağrılıyor...")
            let post = try await LinkedInService.shared.fetchPost(from: url.absoluteString)
            
            await MainActor.run {
                fetchedLinkedInPost = post
                updateMetadata(title: post.title, note: post.displayText)
                selectedSource = .linkedin
                
                // Show error for partial data
                if post.isPartial, let error = post.errorType {
                    serviceError = .linkedin(error)
                }
            }
            
            print("✅ LinkedIn çekildi: \(post.authorName) (partial: \(post.isPartial))")
            
            // Download image (if not partial)
            if !post.isPartial, let imageURL = post.imageURL {
                await downloadSingleImage(from: imageURL) { data in
                    await MainActor.run {
                        linkedInImageData = data
                    }
                }
            }
            
        } catch let error as LinkedInService.LinkedInError {
            print("❌ LinkedIn hatası: \(error.localizedDescription)")
            await MainActor.run {
                serviceError = .linkedin(error)
            }
            // Don't fallback to generic for auth errors - we have partial data
            if error != .authRequired && error != .botDetected {
                await fetchGenericMetadata()
            }
        } catch {
            print("❌ LinkedIn hatası: \(error.localizedDescription)")
            await fetchGenericMetadata()
        }
    }
    
    // MARK: - Medium
    
    private func fetchMediumContent() async {
        do {
            print("📗 MediumService çağrılıyor...")
            let post = try await MediumService.shared.fetchPost(from: url.absoluteString)
            
            await MainActor.run {
                fetchedMediumPost = post
                
                var combinedNote = post.subtitle
                if post.hasFullContent {
                    if !combinedNote.isEmpty {
                        combinedNote += "\n\n"
                    }
                    combinedNote += post.fullContent
                }
                
                updateMetadata(title: post.title, note: combinedNote)
                selectedSource = .medium
            }
            
            print("✅ Medium çekildi: \(post.title.prefix(50))...")
            
            // Download image
            if let imageURL = post.imageURL {
                await downloadSingleImage(from: imageURL) { data in
                    await MainActor.run {
                        mediumImageData = data
                    }
                }
            }
            
        } catch {
            print("❌ Medium hatası: \(error.localizedDescription)")
            await MainActor.run {
                serviceError = .medium(error.localizedDescription)
            }
            await fetchGenericMetadata()
        }
    }
    
    // MARK: - Generic Metadata
    
    private func fetchGenericMetadata() async {
        print("📄 Generic metadata çekiliyor...")
        
        do {
            let metadata = try await URLMetadataService.shared.fetchMetadata(from: url.absoluteString)
            
            await MainActor.run {
                fetchedMetadata = metadata
                updateMetadata(title: metadata.title ?? "", note: metadata.description ?? "")
            }
            
            print("✅ Metadata çekildi: \(metadata.title ?? "no title")")
            
        } catch {
            print("⚠️ Metadata hatası: \(error.localizedDescription)")
            
            // Fallback: URL'den basit bilgi çıkar
            await MainActor.run {
                if title.isEmpty {
                    title = url.lastPathComponent
                        .replacingOccurrences(of: "-", with: " ")
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized
                }
            }
        }
    }
    
    // MARK: - Image Download Helpers
    
    private func downloadImages(from urls: [URL], completion: @escaping ([Data]) async -> Void) async {
        print("⬇️ \(urls.count) görsel indiriliyor...")
        
        var results: [(Int, Data)] = []
        
        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, url) in urls.prefix(4).enumerated() {
                group.addTask {
                    do {
                        let (data, response) = try await URLSession.shared.data(from: url)
                        if let httpResponse = response as? HTTPURLResponse,
                           httpResponse.statusCode == 200,
                           data.count > 1000 {
                            return (index, data)
                        }
                    } catch {
                        print("   ❌ Görsel \(index + 1) hatası: \(error.localizedDescription)")
                    }
                    return (index, nil)
                }
            }
            
            for await (index, data) in group {
                if let data = data {
                    results.append((index, data))
                }
            }
        }
        
        results.sort { $0.0 < $1.0 }
        let sortedData = results.map { $0.1 }
        
        print("✅ \(sortedData.count) görsel indirildi")
        await completion(sortedData)
    }
    
    private func downloadSingleImage(from url: URL, completion: @escaping (Data) async -> Void) async {
        print("⬇️ Görsel indiriliyor: \(url.lastPathComponent)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               data.count > 1000 {
                print("✅ Görsel indirildi: \(data.count) bytes")
                await completion(data)
            }
        } catch {
            print("❌ Görsel hatası: \(error.localizedDescription)")
        }
    }
}

// MARK: - Save Bookmark

extension ShareExtensionView {
    
    private func saveBookmark() {
        guard let repository = repository else {
            print("⚠️ Repository not ready, saving to App Group fallback...")
            onSave() // Bu aşamada ShareViewController fallback'i tetiklemeli veya burada yapılmalı
            return
        }
        
        // PRO Kontrolü - Bookmark Sınırı (Free: 50)
        if !subscriptionManager.isPro {
            let count = repository.fetchAll().count
            if count >= 50 {
                paywallReason = String(localized: "pro.limit.message")
                showingPaywall = true
                return
            }
        }
        
        isSaving = true
        
        let parsedTags = tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Prepare image data
        let finalImageData: Data? = {
            if let first = tweetImagesData.first { return first }
            if let first = redditImagesData.first { return first }
            if let linkedin = linkedInImageData { return linkedin }
            if let medium = mediumImageData { return medium }
            return nil
        }()
        
        let finalImagesData: [Data]? = {
            if !tweetImagesData.isEmpty { return tweetImagesData }
            if !redditImagesData.isEmpty { return redditImagesData }
            return nil
        }()
        
        let newBookmark = Bookmark(
            title: title.trimmingCharacters(in: .whitespaces),
            url: url.absoluteString,
            note: note.trimmingCharacters(in: .whitespaces),
            source: selectedSource,
            categoryId: selectedCategoryId,
            tags: parsedTags,
            imageData: finalImageData,
            imagesData: finalImagesData
        )
        
        repository.create(newBookmark)
        
        print("💾 Bookmark kaydedildi: \(newBookmark.title)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSave()
        }
    }
}
