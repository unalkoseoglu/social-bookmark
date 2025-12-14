import SwiftUI

/// Yeni bookmark ekleme ekranı
/// URL girişi, otomatik kaynak tespiti ve kategori seçimi
struct AddBookmarkView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var urlInput = ""
    @State private var title = ""
    @State private var note = ""
    @State private var tagsInput = ""
    @State private var selectedSource: BookmarkSource = .other
    @State private var selectedCategoryId: UUID?
    @State private var isFavorite = false
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Preview states
    @State private var fetchedTweet: TwitterService.Tweet?
    @State private var fetchedRedditPost: RedditPost?
    @State private var tweetImagesData: [Data] = []
    @State private var redditImageData: Data?
    
    @FocusState private var focusedField: Field?
    
    private var isValid: Bool {
        !urlInput.trimmingCharacters(in: .whitespaces).isEmpty ||
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // URL girişi
                urlSection
                
                // Twitter önizlemesi
                if let tweet = fetchedTweet {
                    TweetPreviewView(tweet: tweet, imageData: tweetImagesData.first)
                }
                
                // Reddit önizlemesi
                if let reddit = fetchedRedditPost {
                    RedditPreviewView(post: reddit, imagesData: redditImageData.map { [$0] } ?? [])
                }
                
                // Başlık ve not
                detailsSection
                
                // Kategori ve kaynak
                organizationSection
                
                // Etiketler
                tagsSection
                
                // Hata mesajı
                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Yeni Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") {
                        saveBookmark()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || isLoading)
                }
            }
            .onAppear {
                focusedField = .url
            }
            .onChange(of: urlInput) { _, newValue in
                // URL değişince kaynağı otomatik tespit et
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    selectedSource = BookmarkSource.detect(from: trimmed)
                    // Metadata çekmeyi denetle (500ms delay)
                    fetchMetadataWithDelay(trimmed)
                } else {
                    // URL temizlenirse preview'ları da temizle
                    fetchedTweet = nil
                    fetchedRedditPost = nil
                    tweetImagesData = []
                    redditImageData = nil
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var urlSection: some View {
        Section {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                
                TextField("URL yapıştır", text: $urlInput)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .url)
                
                if !urlInput.isEmpty {
                    Button {
                        urlInput = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Yapıştır butonu
            if urlInput.isEmpty {
                Button {
                    if let clipboard = UIPasteboard.general.string {
                        urlInput = clipboard
                    }
                } label: {
                    Label("Panodan Yapıştır", systemImage: "doc.on.clipboard")
                }
            }
        } header: {
            Text("URL")
        } footer: {
            if !urlInput.isEmpty && selectedSource != .other {
                Label("\(selectedSource.emoji) \(selectedSource.displayName) olarak algılandı", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
    
    private var detailsSection: some View {
        Section("Detaylar") {
            TextField("Başlık", text: $title)
                .focused($focusedField, equals: .title)
            
            TextField("Not (opsiyonel)", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .focused($focusedField, equals: .note)
        }
    }
    
    private var organizationSection: some View {
        Section("Organizasyon") {
            // Kategori seçici
            CategoryPickerView(
                selectedCategoryId: $selectedCategoryId,
                categories: viewModel.categories
            )
            
            // Kaynak seçici
            Picker("Kaynak", selection: $selectedSource) {
                ForEach(BookmarkSource.allCases) { source in
                    HStack {
                        Text(source.emoji)
                        Text(source.displayName)
                    }
                    .tag(source)
                }
            }
            
            // Favori toggle
            Toggle(isOn: $isFavorite) {
                Label("Favorilere Ekle", systemImage: isFavorite ? "star.fill" : "star")
            }
        }
    }
    
    private var tagsSection: some View {
        Section {
            TextField("swift, ios, development", text: $tagsInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .tags)
        } header: {
            Text("Etiketler")
        } footer: {
            Text("Virgülle ayırarak birden fazla etiket ekleyebilirsin")
        }
    }
    
    // MARK: - Actions
    
    private func fetchMetadataWithDelay(_ urlString: String) {
        // 500ms sonra metadata çek (typing'i bitmesini bekle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard urlString == urlInput.trimmingCharacters(in: .whitespaces) else {
                return  // URL değişmişse iptal et
            }
            
            isLoading = true
            
            Task {
                print("🔍 Metadata fetching başlıyor: \(urlString)")
                
                // Twitter
                if TwitterService.shared.isTwitterURL(urlString) {
                    print("🐦 Twitter URL tespit edildi")
                    await fetchTwitterMetadata(urlString)
                }
                // Reddit
                else if RedditService.shared.isRedditURL(urlString) {
                    print("🔴 Reddit URL tespit edildi")
                    await fetchRedditMetadata(urlString)
                }
                // Genel metadata
                else {
                    print("📄 Genel metadata fetching...")
                    await fetchGenericMetadata(urlString)
                }
                
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func fetchTwitterMetadata(_ urlString: String) async {
        do {
            let tweet = try await TwitterService.shared.fetchTweet(from: urlString)
            await MainActor.run {
                fetchedTweet = tweet
                if title.isEmpty {
                    title = "@\(tweet.authorUsername): \(tweet.shortSummary)"
                }
                if note.isEmpty {
                    note = tweet.fullText
                }
                print("✅ Tweet çekildi: @\(tweet.authorUsername)")
            }
            
            // Görselleri indir
            if !tweet.mediaURLs.isEmpty {
                await downloadTweetImages(from: tweet.mediaURLs)
            }
        } catch {
            print("❌ Twitter hatası: \(error.localizedDescription)")
            await fetchGenericMetadata(urlString)
        }
    }
    
    private func downloadTweetImages(from urls: [URL]) async {
        var images: [Data] = []
        
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
                        print("❌ Tweet görsel hatası: \(error.localizedDescription)")
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
            images = results.map { $0.1 }
        }
        
        await MainActor.run {
            tweetImagesData = images
            print("✅ \(images.count) tweet görseli indirildi")
        }
    }
    
    private func fetchRedditMetadata(_ urlString: String) async {
        do {
            let post = try await RedditService.shared.fetchPost(from: urlString)
            await MainActor.run {
                fetchedRedditPost = post
                if title.isEmpty {
                    title = post.title
                }
                if note.isEmpty {
                    note = !post.selfText.isEmpty ? post.selfText : "r/\(post.subreddit)"
                }
                print("✅ Reddit post çekildi: r/\(post.subreddit)")
            }
            
            // Görseli indir
            if let imageURL = post.imageURL {
                await downloadRedditImage(from: imageURL)
            }
        } catch {
            print("❌ Reddit hatası: \(error.localizedDescription)")
            await fetchGenericMetadata(urlString)
        }
    }
    
    private func downloadRedditImage(from url: URL) async {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               data.count > 1000 {
                await MainActor.run {
                    redditImageData = data
                    print("✅ Reddit görseli indirildi: \(data.count) bytes")
                }
            }
        } catch {
            print("❌ Reddit görsel hatası: \(error.localizedDescription)")
        }
    }
    
    private func fetchGenericMetadata(_ urlString: String) async {
        do {
            let metadata = try await URLMetadataService.shared.fetchMetadata(from: urlString)
            await MainActor.run {
                if title.isEmpty, let metaTitle = metadata.title {
                    title = metaTitle
                    print("✅ Başlık çekildi: \(metaTitle)")
                }
                if note.isEmpty, let metaDescription = metadata.description {
                    note = metaDescription
                    print("✅ Açıklama çekildi")
                }
            }
        } catch {
            print("⚠️ Metadata çekilemedi: \(error.localizedDescription)")
        }
    }
    
    private func saveBookmark() {
        // Validasyon
        let trimmedURL = urlInput.trimmingCharacters(in: .whitespaces)
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        
        // En az bir bilgi gerekli
        guard !trimmedURL.isEmpty || !trimmedTitle.isEmpty else {
            errorMessage = "URL veya başlık gerekli"
            return
        }
        
        // URL varsa formatla
        var finalURL = trimmedURL
        if !finalURL.isEmpty && !finalURL.hasPrefix("http") {
            finalURL = "https://\(finalURL)"
        }
        
        // Başlık yoksa URL'den oluştur
        let finalTitle = trimmedTitle.isEmpty ? (URL(string: finalURL)?.host ?? "Adsız Bookmark") : trimmedTitle
        
        // Etiketleri parse et
        let tags = tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Bookmark oluştur
        let bookmark = Bookmark(
            title: finalTitle,
            url: finalURL,
            note: note.trimmingCharacters(in: .whitespaces),
            source: selectedSource,
            categoryId: selectedCategoryId, tags: tags
        )
        
        // Kaydet
        viewModel.bookmarkRepository.create(bookmark)
        viewModel.refresh()
        
        // Kapat
        dismiss()
    }
    
    // MARK: - Field Enum
    
    enum Field: Hashable {
        case url, title, note, tags
    }
}

// MARK: - Preview

#Preview {
    AddBookmarkView(
        viewModel: HomeViewModel(
            bookmarkRepository: PreviewMockRepository.shared,
            categoryRepository: PreviewMockCategoryRepository.shared
        )
    )
}
