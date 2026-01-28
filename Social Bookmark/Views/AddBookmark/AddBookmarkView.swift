import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Yeni bookmark ekleme ekranı (Modal sheet olarak açılır)
struct AddBookmarkView: View {
    // MARK: - Properties

    @State private var viewModel: AddBookmarkViewModel
    @Binding var selectedTab: AppTab
    private let onSaved: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    @State private var paywallReason: String? = nil
    @FocusState private var focusedField: Field?
    
    // OCR Image States
    @State private var showingOCRImagePicker = false
    @State private var showingOCRImageCrop = false
    @State private var ocrImage: UIImage?
    @State private var isProcessingOCR = false
    
    // Bookmark Cover Image States
    @State private var showingCoverImagePicker = false
    @State private var showingCoverImageCrop = false
    @State private var coverImage: UIImage?
    
    // Sheet states for pickers
    @State private var showingCategoryPicker = false
    @State private var showingSourcePicker = false
    @State private var showingFileImporter = false
    
    // MARK: - Computed Properties
    
    /// Form'da herhangi bir içerik var mı kontrol eder
    private var hasAnyContent: Bool {
        !viewModel.url.isEmpty ||
        !viewModel.title.isEmpty ||
        !viewModel.note.isEmpty ||
        viewModel.selectedFileData != nil ||
        viewModel.fetchedTweet != nil ||
        viewModel.fetchedRedditPost != nil ||
        viewModel.fetchedLinkedInContent != nil ||
        viewModel.fetchedMetadata != nil
    }
    
    // MARK: - Initialization
    
    init(viewModel: AddBookmarkViewModel, onSaved: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
        _selectedTab = .constant(.add)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                linkedinPreviewSection
                redditPreviewSection
                tweetPreviewSection
                detailsSection
                organizationSection
                tagsSection
                fileSection
                coverImageSection
                ocrSection
                
                if !viewModel.validationErrors.isEmpty {
                    validationErrorsSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(localized: "addBookmark.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button(String(localized: "common.done")) {
                            hideKeyboard()
                        }
                        .fontWeight(.semibold)
                    }
                }
                
                toolbarContent
            }
            .onAppear {
                if viewModel.categories.isEmpty {
                    viewModel.loadCategories()
                }
            }
            // OCR Image Sheets
            .sheet(isPresented: $showingOCRImagePicker) {
                ImagePickerView { image in
                    ocrImage = image
                    showingOCRImageCrop = true
                }
            }
            .sheet(isPresented: $showingOCRImageCrop) {
                if let image = ocrImage {
                    ImageCropView(image: image) { croppedImage in
                        ocrImage = croppedImage
                        performOCR(on: croppedImage)
                    }
                }
            }
            // Cover Image Sheets
            .sheet(isPresented: $showingCoverImagePicker) {
                ImagePickerView { image in
                    coverImage = image
                    showingCoverImageCrop = true
                }
            }
            .sheet(isPresented: $showingCoverImageCrop) {
                if let image = coverImage {
                    ImageCropView(image: image) { croppedImage in
                        coverImage = croppedImage
                    }
                }
            }
            // Picker Sheets
            .sheet(isPresented: $showingCategoryPicker) {
                SelectionPickerSheet(
                    title: String(localized: "addBookmark.field.category"),
                    items: buildCategoryItems(),
                    selectedId: viewModel.selectedCategoryId?.uuidString,
                    onSelect: { id in
                        viewModel.selectedCategoryId = id.flatMap { UUID(uuidString: $0) }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingSourcePicker) {
                SelectionPickerSheet(
                    title: String(localized: "addBookmark.field.source"),
                    items: buildSourceItems(),
                    selectedId: viewModel.selectedSource.rawValue,
                    onSelect: { id in
                        if let id = id, let source = BookmarkSource(rawValue: id) {
                            viewModel.selectedSource = source
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(reason: paywallReason)
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.pdf, .text, .plainText, .rtf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.selectedFileURL = url
                    }
                case .failure(let error):
                    print("❌ [AddBookmarkView] File selection failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Build Picker Items
    
    private func buildCategoryItems() -> [SelectionPickerItem] {
        var items: [SelectionPickerItem] = [
            SelectionPickerItem(
                id: nil,
                icon: "tray.fill",
                iconColor: .gray,
                title: String(localized: "addBookmark.no_category"),
                subtitle: String(localized: "addBookmark.category.no_category_hint")
            )
        ]
        
        items += viewModel.categories.map { category in
            SelectionPickerItem(
                id: category.id.uuidString,
                icon: category.icon,
                iconColor: category.color,
                title: category.name,
                subtitle: nil
            )
        }
        
        return items
    }
    
    private func buildSourceItems() -> [SelectionPickerItem] {
        BookmarkSource.allCases.map { source in
            SelectionPickerItem(
                id: source.rawValue,
                emoji: source.emoji,
                iconColor: source.color,
                title: source.displayName,
                subtitle: source.sourceDescription
            )
        }
    }
    
    // MARK: - Hide Keyboard
    
    private func hideKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Sections
    
    private var basicInfoSection: some View {
        Section(String(localized: "addBookmark.section.basic")) {
            TextField(String(localized: "addBookmark.field.title"), text: $viewModel.title, axis: .vertical)
                .lineLimit(2...4)
                .focused($focusedField, equals: .title)
            
            HStack {
                TextField(String(localized: "addBookmark.field.url"), text: $viewModel.url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .url)
                
                Button {
                    pasteFromClipboard()
                } label: {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }.padding(4)

                if viewModel.isLinkedInURL(viewModel.url) {
                    Image(systemName: "link")
                        .foregroundStyle(.cyan)
                        .transition(.scale.combined(with: .opacity))
                }

                if viewModel.isRedditURL(viewModel.url) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }

                if TwitterService.shared.isTwitterURL(viewModel.url) {
                    Image(systemName: "bird.fill")
                        .foregroundStyle(.blue)
                        .transition(.scale.combined(with: .opacity))
                }
                
                if viewModel.isLoadingMetadata {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else if !viewModel.url.isEmpty && viewModel.isURLValid {
                    Button(action: {
                        Task { await viewModel.fetchMetadata() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.url)
            
            // Clear butonu - içerik varsa göster
            if hasAnyContent {
                Button(role: .destructive) {
                    clearAllContent()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(String(localized: "addBookmark.clearAll"))
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
            }
            
            if !viewModel.url.isEmpty && !viewModel.isURLValid {
                Label(String(localized: "addBookmark.error.invalid_url"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            if let linkedInContent = viewModel.fetchedLinkedInContent {
                Label(
                    String(localized: "addBookmark.status.linkedin_fetched"),
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.cyan)
                .font(.caption)
                .accessibilityLabel(linkedInContent.title)
            } else if let redditPost = viewModel.fetchedRedditPost {
                Label(
                    String(localized: "addBookmark.status.reddit_fetched"),
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.orange)
                .font(.caption)
                .accessibilityLabel(redditPost.title)
            } else if viewModel.fetchedTweet != nil {
                HStack {
                    Label(String(localized: "addBookmark.status.tweet_fetched"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    if viewModel.tweetImagesData.count > 0 {
                        Text(String(localized: "addBookmark.status.images_count \(viewModel.tweetImagesData.count)"))
                            .foregroundStyle(.blue)
                    }
                }
                .font(.caption)
            } else if let metadata = viewModel.fetchedMetadata, metadata.hasTitle {
                Label(String(localized: "addBookmark.status.page_filled"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var linkedinPreviewSection: some View {
        if let content = viewModel.fetchedLinkedInContent {
            Section {
                LinkedInPreviewView(post: content, imageData: viewModel.linkedInImageData)
            } header: {
                Label(String(localized: "addBookmark.preview.linkedin"), systemImage: "link")
                    .foregroundStyle(.cyan)
            }
        }
    }

    @ViewBuilder
    private var redditPreviewSection: some View {
        if let post = viewModel.fetchedRedditPost {
            Section {
                RedditPreviewView(post: post, imagesData: viewModel.redditImagesData)
            } header: {
                Label(String(localized: "addBookmark.preview.reddit"), systemImage: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var tweetPreviewSection: some View {
        if let tweet = viewModel.fetchedTweet {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // Başlık
                    HStack {
                        Image(systemName: "bird.fill")
                            .foregroundStyle(.blue)
                        Text(String(localized: "addBookmark.preview.tweet"))
                            .font(.headline)
                        Spacer()
                        
                        // Görsel sayısı badge
                        if viewModel.tweetImagesData.count > 1 {
                            Text(String(localized: "addBookmark.preview.images \(viewModel.tweetImagesData.count)"))
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
                    
                    // Yazar bilgisi
                    HStack(spacing: 12) {
                        if let avatarURL = tweet.authorAvatarURL {
                            AsyncImage(url: avatarURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    avatarPlaceholder(for: tweet)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                        } else {
                            avatarPlaceholder(for: tweet)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tweet.authorName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("@\(tweet.authorUsername)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Tweet metni
                    Text(tweet.text)
                        .font(.body)
                        .lineLimit(8)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // ÇOKLU GÖRSEL GALERİ
                    if !viewModel.tweetImagesData.isEmpty {
                        tweetImagesGallery
                    } else if tweet.hasMedia {
                        // Görseller yükleniyor
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 100)
                            .overlay {
                                VStack(spacing: 8) {
                                    ProgressView()
                                    Text(String(localized: "addBookmark.loading.images \(tweet.mediaURLs.count)"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }
                    
                    // İstatistikler
                    HStack(spacing: 20) {
                        Label(formatCount(tweet.likeCount), systemImage: "heart.fill")
                            .foregroundStyle(.red)
                        Label(formatCount(tweet.retweetCount), systemImage: "arrow.2.squarepath")
                            .foregroundStyle(.green)
                        Label(formatCount(tweet.replyCount), systemImage: "bubble.right.fill")
                            .foregroundStyle(.blue)
                    }
                    .font(.caption)
                    
                    if let date = tweet.createdAt {
                        HStack {
                            Image(systemName: "calendar")
                            Text(date, style: .relative)
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    
    @ViewBuilder
    private var tweetImagesGallery: some View {
        let images = viewModel.tweetImages
        
        if images.count == 1 {
            Image(uiImage: images[0])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if images.count == 2 {
            HStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        } else if images.count == 3 {
            HStack(spacing: 4) {
                Image(uiImage: images[0])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(spacing: 4) {
                    ForEach(1..<3, id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 98)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } else if images.count >= 4 {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<2, id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                HStack(spacing: 4) {
                    ForEach(2..<min(4, images.count), id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                if index == 3 && images.count > 4 {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.black.opacity(0.5))
                                    Text("+\(images.count - 4)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
        }
    }
    
    private func avatarPlaceholder(for tweet: TwitterService.Tweet) -> some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay {
                Text(String(tweet.authorName.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
    
    private var detailsSection: some View {
        Section(String(localized: "addBookmark.section.notes")) {
            TextField(String(localized: "addBookmark.field.notes"), text: $viewModel.note, axis: .vertical)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .lineLimit(3...10)
                .focused($focusedField, equals: .note)
        }
    }
    
    // MARK: - Organization Section
    
    private var organizationSection: some View {
        Section(String(localized: "addBookmark.section.organization")) {
            // Kategori Seçici
            SelectionRowButton(
                icon: viewModel.selectedCategoryId.flatMap { id in
                    viewModel.categories.first { $0.id == id }?.icon
                } ?? "folder.fill",
                iconColor: viewModel.selectedCategoryId.flatMap { id in
                    viewModel.categories.first { $0.id == id }?.color
                } ?? .gray,
                label: String(localized: "addBookmark.field.category"),
                value: viewModel.selectedCategoryId.flatMap { id in
                    viewModel.categories.first { $0.id == id }?.name
                } ?? String(localized: "addBookmark.no_category")
            ) {
                showingCategoryPicker = true
            }
            
            // Kaynak Seçici
            SelectionRowButton(
                emoji: viewModel.selectedSource.emoji,
                iconColor: viewModel.selectedSource.color,
                label: String(localized: "addBookmark.field.source"),
                value: viewModel.selectedSource.displayName
            ) {
                showingSourcePicker = true
            }
        }
    }
    
    private var tagsSection: some View {
        Section {
            TextField(String(localized: "addBookmark.tags.placeholder"), text: $viewModel.tagsInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .tags)
        } header: {
            Text(String(localized: "addBookmark.section.tags"))
        } footer: {
            Text(String(localized: "addBookmark.tags.hint"))
        }
    }
    
    // MARK: - Cover Image Section (Bookmark Kapak Görseli)
    
    private var coverImageSection: some View {
        Section {
            if let image = coverImage {
                VStack(spacing: 12) {
                    // Görsel önizleme
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    
                    // Aksiyonlar
                    HStack(spacing: 16) {
                        Button {
                            showingCoverImageCrop = true
                        } label: {
                            Label(String(localized: "addBookmark.coverImage.edit"), systemImage: "crop")
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        Button {
                            showingCoverImagePicker = true
                        } label: {
                            Label(String(localized: "addBookmark.coverImage.change"), systemImage: "arrow.triangle.2.circlepath.camera")
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            withAnimation {
                                coverImage = nil
                            }
                        } label: {
                            Label(String(localized: "addBookmark.coverImage.remove"), systemImage: "trash")
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                // Görsel ekleme butonu
                Button {
                    showingCoverImagePicker = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "photo.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "addBookmark.coverImage.add"))
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            Text(String(localized: "addBookmark.coverImage.hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Label(String(localized: "addBookmark.section.coverImage"), systemImage: "photo.on.rectangle")
        } footer: {
            if coverImage == nil {
                Text(String(localized: "addBookmark.coverImage.footer"))
            }
        }
    }
    
    // MARK: - File Section (Doküman Seçme)
    
    private var fileSection: some View {
        Section {
            if let fileName = viewModel.fileName {
                VStack(spacing: 12) {
                    HStack(spacing: 14) {
                        Image(systemName: viewModel.fileExtension == "pdf" ? "doc.richtext.fill" : "doc.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.emerald)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileName)
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            if let fileSize = viewModel.fileSize {
                                Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if viewModel.isProcessingFile {
                            ProgressView()
                        } else {
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.selectedFileURL = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if viewModel.fileExtension == "pdf" && !viewModel.isProcessingFile {
                        Text(String(localized: "addBookmark.file.pdf_processed"))
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    if subscriptionManager.isPro {
                        showingFileImporter = true
                    } else {
                        paywallReason = String(localized: "pro.document.message")
                        showingPaywall = true
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    colors: [Color.emerald, .teal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "addBookmark.file.add"))
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            Text(String(localized: "addBookmark.file.hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.emerald)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Label(String(localized: "addBookmark.section.file"), systemImage: "doc.on.doc")
        } footer: {
            if viewModel.fileName == nil {
                Text(String(localized: "addBookmark.file.footer"))
            }
        }
    }
    
    // MARK: - OCR Section (Metin Çıkarma)
    
    private var ocrSection: some View {
        Section {
            if let image = ocrImage {
                VStack(spacing: 12) {
                    // Görsel önizleme
                    HStack(spacing: 12) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if isProcessingOCR {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(String(localized: "addBookmark.ocr.processing"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Label(String(localized: "addBookmark.ocr.completed"), systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                                
                                Text(String(localized: "addBookmark.ocr.completedHint"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Aksiyonlar
                    HStack(spacing: 16) {
                        Button {
                            showingOCRImageCrop = true
                        } label: {
                            Label(String(localized: "addBookmark.ocr.recrop"), systemImage: "crop")
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            withAnimation {
                                ocrImage = nil
                            }
                        } label: {
                            Label(String(localized: "addBookmark.ocr.remove"), systemImage: "trash")
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                // OCR ekleme butonu
                Button {
                    if subscriptionManager.isPro {
                        showingOCRImagePicker = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "addBookmark.ocr.add"))
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            Text(String(localized: "addBookmark.ocr.hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Label(String(localized: "addBookmark.section.ocr"), systemImage: "text.viewfinder")
        } footer: {
            if ocrImage == nil {
                Text(String(localized: "addBookmark.ocr.footer"))
            }
        }
    }
    
    private var validationErrorsSection: some View {
        Section {
            ForEach(viewModel.validationErrors, id: \.self) { error in
                Label(error, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
        } header: {
            Text(String(localized: "addBookmark.errors")).foregroundStyle(.red)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                onSaved?()
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .font(.body)
            }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "common.save")) { saveBookmark() }
                .disabled(!viewModel.isValid)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Actions
    
    private func saveBookmark() {
        // PRO Kontrolü - Bookmark Sınırı (Free: 50)
        if !subscriptionManager.isPro {
            let count = (try? modelContext.fetchCount(FetchDescriptor<Bookmark>())) ?? 0
            if count >= 50 {
                paywallReason = String(localized: "pro.limit.message")
                showingPaywall = true
                return
            }
        }
        
        // Cover image öncelikli, yoksa tweet/platform görseli
        let coverImageData = coverImage?.jpegData(compressionQuality: 0.8)
        let finalImageData = coverImageData ?? viewModel.tweetImagesData.first
        
        Task {
            if await viewModel.saveBookmark(withImage: finalImageData, extractedText: viewModel.note) {
                onSaved?()
                dismiss()
            }
        }
    }
    
    private func performOCR(on image: UIImage) {
        isProcessingOCR = true
        
        Task {
            do {
                let result = try await OCRService.shared.recognizeText(from: image)
                
                await MainActor.run {
                    if viewModel.title.isEmpty {
                        let lines = result.text.components(separatedBy: "\n")
                        if let firstLine = lines.first, !firstLine.isEmpty {
                            viewModel.title = String(firstLine.prefix(100))
                        }
                    }
                    
                    if viewModel.note.isEmpty {
                        viewModel.note = result.cleanText
                    } else {
                        viewModel.note += "\n\n---\n\n" + result.cleanText
                    }
                    
                    isProcessingOCR = false
                }
            } catch {
                await MainActor.run {
                    print("❌ OCR Error: \(error.localizedDescription)")
                    isProcessingOCR = false
                }
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let pastedString = UIPasteboard.general.string {
            viewModel.url = pastedString
        }
    }
    
    private func clearAllContent() {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.clearAll()
        }
    }
    
    enum Field: Hashable {
        case title, url, note, tags
    }
}

// MARK: - Selection Picker Item

struct SelectionPickerItem: Identifiable {
    let id: String?
    var icon: String?
    var emoji: String?
    let iconColor: Color
    let title: String
    let subtitle: String?
    
    init(id: String?, icon: String, iconColor: Color, title: String, subtitle: String?) {
        self.id = id
        self.icon = icon
        self.emoji = nil
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
    }
    
    init(id: String?, emoji: String, iconColor: Color, title: String, subtitle: String?) {
        self.id = id
        self.icon = nil
        self.emoji = emoji
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
    }
}

// MARK: - Selection Picker Sheet (Ortak Tasarım)

struct SelectionPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    let items: [SelectionPickerItem]
    let selectedId: String?
    let onSelect: (String?) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    Button {
                        onSelect(item.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            // İkon veya Emoji
                            Group {
                                if let icon = item.icon {
                                    Image(systemName: icon)
                                        .font(.body)
                                        .foregroundStyle(.white)
                                } else if let emoji = item.emoji {
                                    Text(emoji)
                                        .font(.title3)
                                }
                            }
                            .frame(width: 40, height: 40)
                            .background(item.icon != nil ? item.iconColor : item.iconColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            // Başlık ve Alt başlık
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                
                                if let subtitle = item.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Seçim işareti
                            if selectedId == item.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Selection Row Button (Tekrar Kullanılabilir)

struct SelectionRowButton: View {
    var icon: String?
    var emoji: String?
    let iconColor: Color
    let label: String
    let value: String
    let action: () -> Void
    
    init(icon: String, iconColor: Color, label: String, value: String, action: @escaping () -> Void) {
        self.icon = icon
        self.emoji = nil
        self.iconColor = iconColor
        self.label = label
        self.value = value
        self.action = action
    }
    
    init(emoji: String, iconColor: Color, label: String, value: String, action: @escaping () -> Void) {
        self.icon = nil
        self.emoji = emoji
        self.iconColor = iconColor
        self.label = label
        self.value = value
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // İkon
                Group {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(iconColor)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if let emoji = emoji {
                        Text(emoji)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(iconColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                // Label ve Değer
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(value)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BookmarkSource Extension

extension BookmarkSource {
    var sourceDescription: String? {
        switch self {
        case .twitter: return String(localized: "source.twitter.description")
        case .reddit: return String(localized: "source.reddit.description")
        case .linkedin: return String(localized: "source.linkedin.description")
        case .medium: return String(localized: "source.medium.description")
        case .youtube: return String(localized: "source.youtube.description")
        case .instagram: return String(localized: "source.instagram.description")
        case .github: return String(localized: "source.github.description")
        case .article: return String(localized: "source.article.description")
        case .document: return String(localized: "source.document.description")
        case .other: return nil
        }
    }
}

#Preview {
    AddBookmarkView(
        viewModel: AddBookmarkViewModel(
            repository: PreviewMockRepository.shared,
            categoryRepository: PreviewMockCategoryRepository.shared
        )
    )
}
