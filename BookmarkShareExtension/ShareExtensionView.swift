import SwiftUI
import UIKit

/// Share Extension UI - Güncellenmiş tasarım
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
    @State private var metadataTitle: String?
    @State private var metadataDescription: String?
    @State private var metadataError: String?
    
    @State private var isLoadingMetadata = false
    @State private var isSaving = false
    @State private var tweetData: TwitterService.Tweet?
    
    
    @FocusState private var focusedField: Field?

    private var backgroundColor: Color { Color(.systemGroupedBackground) }
    private var cardBackground: Color { Color(.secondarySystemGroupedBackground) }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Başlık
                    headerSection
                    
                    // Metadata preview
                    if isLoadingMetadata {
                        loadingSection
                    } else if let tweet = tweetData {
                        tweetPreviewSection(tweet)
                    }else if metadataTitle != nil || metadataDescription != nil {
                        metadataPreviewSection
                    } else if metadataError != nil {
                        errorSection
                    }
                    
                    // Form sections
                    formSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Yeni Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .scrollContentBackground(.hidden)
            .background(backgroundColor)
            .disabled(isSaving)
            .onAppear {
                isLoadingMetadata = true
                Task {
                    await fetchMetadata()
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temel Bilgiler")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            TextField("Başlık", text: $title, axis: .vertical)
                .lineLimit(2...4)
                .font(.body.weight(.semibold))
                .focused($focusedField, equals: .title)
            
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(url.host ?? "URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let source = BookmarkSource(rawValue: selectedSource.rawValue) {
                    Text(source.emoji)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Loading
    
    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("İçerik yükleniyor...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Tweet Preview
    
    private func tweetPreviewSection(_ tweet: TwitterService.Tweet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bird.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("Tweet Önizleme")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            // Tweet metadata
            HStack(spacing: 16) {
                if let avatarURL = tweet.authorAvatarURL {
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        default:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tweet.authorName)
                            .font(.subheadline.weight(.semibold))
                        Text("@\(tweet.authorUsername)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        Label("\(tweet.likeCount)", systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        
                        Label("\(tweet.retweetCount)", systemImage: "repeat")
                            .font(.caption)
                            .foregroundStyle(.green)
                        
                        Label("\(tweet.replyCount)", systemImage: "bubble.right")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                
                Spacer()
            }
            
            // Tweet text
            Text(tweet.text)
                .font(.body)
                .lineLimit(3)
                .foregroundStyle(.primary)
            
            // Media preview
            if let imageURL = tweet.firstImageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 120)
                    }
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Reddit Preview
    
    private func redditPreviewSection(_ reddit: RedditPost) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text("Reddit Önizleme")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            // Reddit metadata
            VStack(alignment: .leading, spacing: 8) {
                Text("r/\(reddit.subreddit)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                
                Text(reddit.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label("\(reddit.score)", systemImage: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    
                    Label("\(reddit.commentCount)", systemImage: "bubble.right")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            // Post image
            if let imageURL = reddit.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 120)
                    }
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Metadata Preview
    
    private var metadataPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.image")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("Sayfa Özeti")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            if let title = metadataTitle {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }
            
            if let desc = metadataDescription {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Error
    
    private var errorSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Veriler çekilemedi")
                    .font(.subheadline.weight(.semibold))
                Text(metadataError ?? "Bilinmeyen hata")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Form
    
    private var formSection: some View {
        VStack(spacing: 16) {
            // Not
            VStack(alignment: .leading, spacing: 8) {
                Text("Detaylar")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $note)
                    .frame(height: 100)
                    .font(.body)
                    .focused($focusedField, equals: .note)
                    .padding(8)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Etiketler
            VStack(alignment: .leading, spacing: 8) {
                Text("Etiketler")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                TextField("virgülle ayırın", text: $tagsInput, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.body)
                    .focused($focusedField, equals: .tags)
                    .padding(8)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("Örnek: Swift, iOS, Tutorial")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Kaynak
            VStack(alignment: .leading, spacing: 8) {
                Text("Kaynak")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Picker("Kaynak", selection: $selectedSource) {
                    ForEach(BookmarkSource.allCases) { source in
                        Text("\(source.emoji) \(source.displayName)")
                            .tag(source)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("İptal") {
                onCancel()
            }
            .disabled(isSaving)
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button(action: saveBookmark) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text("Kaydet")
                        .fontWeight(.semibold)
                }
            }
            .disabled(title.isEmpty || isSaving)
        }
    }
    
    // MARK: - Actions
    
    private func saveBookmark() {
        isSaving = true

        let parsedTags = tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let newBookmark = Bookmark(
            title: title.trimmingCharacters(in: .whitespaces),
            url: url.absoluteString,
            note: note.trimmingCharacters(in: .whitespaces),
            source: selectedSource,
            tags: parsedTags
        )

        repository.create(newBookmark)
        onSave()
    }
    
    // MARK: - Metadata Fetching
    
    private func fetchMetadata() async {
        defer { isLoadingMetadata = false }
        
        metadataError = nil
        metadataTitle = nil
        metadataDescription = nil
        tweetData = nil
        redditData = nil

        selectedSource = BookmarkSource.detect(from: url.absoluteString)
        
        print("📝 Fetching metadata for: \(url.absoluteString)")

        // Twitter özel kontrol
        if TwitterService.shared.isTwitterURL(url.absoluteString) {
            await fetchTwitterMetadata()
            return
        }
        
        // Reddit özel kontrol
        if RedditService.shared.isRedditURL(url.absoluteString) {
            await fetchRedditMetadata()
            return
        }

        do {
            let metadata = try await URLMetadataService.shared.fetchMetadata(from: url.absoluteString)

            if let metaTitle = metadata.title {
                let cleaned = cleanMetaTitle(metaTitle)
                metadataTitle = cleaned

                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    title = cleaned
                }
            }

            if let metaDescription = metadata.description {
                metadataDescription = metaDescription

                if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    note = String(metaDescription.prefix(500))
                }
            }
        } catch {
            print("⚠️ Metadata fetch error: \(error.localizedDescription)")
            metadataError = error.localizedDescription

            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let urlPath = url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
                title = urlPath.isEmpty ? url.host ?? "Bookmark" : urlPath
            }
        }
    }
    
    private func fetchTwitterMetadata() async {
        print("🐦 Fetching Twitter metadata...")
        do {
            let tweet = try await TwitterService.shared.fetchTweet(from: url.absoluteString)
            tweetData = tweet
            title = "@\(tweet.authorUsername): \(tweet.shortSummary)"
            note = tweet.fullText
            print("✅ Twitter metadata fetched")
        } catch {
            print("⚠️ Twitter fetch failed: \(error.localizedDescription)")
            metadataError = error.localizedDescription
        }
    }
    
    private func fetchRedditMetadata() async {
        print("🔴 Fetching Reddit metadata...")
        do {
            let post = try await RedditService.shared.fetchPost(from: url.absoluteString)
            redditData = post
            title = post.title
            note = post.summary
            print("✅ Reddit metadata fetched")
        } catch {
            print("⚠️ Reddit fetch failed: \(error.localizedDescription)")
            metadataError = error.localizedDescription
        }
    }
    
    private func cleanMetaTitle(_ title: String) -> String {
        var cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
        
        if let pipeIndex = cleaned.firstIndex(of: "|") {
            let beforePipe = cleaned[..<pipeIndex].trimmingCharacters(in: .whitespaces)
            if !beforePipe.isEmpty && beforePipe.count > 10 {
                cleaned = beforePipe
            }
        }
        
        return String(cleaned.prefix(200))
    }
    
    // MARK: - Field Enum
    
    enum Field: Hashable {
        case title, note, tags
    }
}

// MARK: - Preview

#Preview {
    ShareExtensionView(
        url: URL(string: "https://twitter.com/example/status/123")!,
        repository: PreviewMockRepository.shared,
        onSave: {},
        onCancel: {}
    )
}
