import SwiftUI

/// Yeni bookmark ekleme ekranı (Modal sheet olarak açılır)
struct AddBookmarkView: View {
    // MARK: - Properties

    @State private var viewModel: AddBookmarkViewModel
    private let onSaved: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    @State private var showingImagePicker = false
    @State private var showingImageCrop = false
    @State private var selectedImage: UIImage?
    @State private var isProcessingOCR = false
    
    // MARK: - Initialization
    
    init(viewModel: AddBookmarkViewModel, onSaved: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                linkedinPreviewSection
                tweetPreviewSection
                detailsSection
                tagsSection
                imageSection
                
                if !viewModel.validationErrors.isEmpty {
                    validationErrorsSection
                }
            }
            .navigationTitle("Yeni Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView { image in
                    selectedImage = image
                    showingImageCrop = true
                }
            }
            .sheet(isPresented: $showingImageCrop) {
                if let image = selectedImage {
                    ImageCropView(image: image) { croppedImage in
                        selectedImage = croppedImage
                        performOCR(on: croppedImage)
                    }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var basicInfoSection: some View {
        Section("Temel Bilgiler") {
            TextField("Başlık", text: $viewModel.title, axis: .vertical)
                .lineLimit(2...4)
                .focused($focusedField, equals: .title)
            
            HStack {
                TextField("URL (opsiyonel)", text: $viewModel.url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .url)

                if viewModel.isLinkedInURL(viewModel.url) {
                    Image(systemName: "link")
                        .foregroundStyle(.cyan)
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
            
            if !viewModel.url.isEmpty && !viewModel.isURLValid {
                Label("Geçersiz URL formatı", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            if let linkedInContent = viewModel.fetchedLinkedInContent {
                Label(
                    "LinkedIn içeriği çekildi",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.cyan)
                .font(.caption)
                .accessibilityLabel(linkedInContent.title)
            } else if viewModel.fetchedTweet != nil {
                HStack {
                    Label("Tweet içeriği çekildi", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    // Görsel sayısı badge'i ← YENİ
                    if viewModel.tweetImagesData.count > 0 {
                        Text("(\(viewModel.tweetImagesData.count) görsel)")
                            .foregroundStyle(.blue)
                    }
                }
                .font(.caption)
            } else if let metadata = viewModel.fetchedMetadata, metadata.hasTitle {
                Label("Sayfa bilgileri dolduruldu", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var linkedinPreviewSection: some View {
        if let content = viewModel.fetchedLinkedInContent {
            Section {
                LinkedInPreviewView(content: content)
            } header: {
                Label("LinkedIn Önizleme", systemImage: "link")
                    .foregroundStyle(.cyan)
            }
        }
    }

    /// Tweet önizleme - çoklu görsel destekli ← GÜNCELLENDİ
    @ViewBuilder
    private var tweetPreviewSection: some View {
        if let tweet = viewModel.fetchedTweet {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // Başlık
                    HStack {
                        Image(systemName: "bird.fill")
                            .foregroundStyle(.blue)
                        Text("Tweet Önizleme")
                            .font(.headline)
                        Spacer()
                        
                        // Görsel sayısı badge
                        if viewModel.tweetImagesData.count > 1 {
                            Text("\(viewModel.tweetImagesData.count) görsel")
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
                    
                    // ÇOKLU GÖRSEL GALERİ ← YENİ
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
                                    Text("\(tweet.mediaURLs.count) görsel yükleniyor...")
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
    
    /// Çoklu görsel galerisi ← YENİ
    @ViewBuilder
    private var tweetImagesGallery: some View {
        let images = viewModel.tweetImages
        
        if images.count == 1 {
            // Tek görsel - tam genişlik
            Image(uiImage: images[0])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if images.count == 2 {
            // 2 görsel - yan yana
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
            // 3 görsel - 1 büyük + 2 küçük
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
            // 4+ görsel - 2x2 grid
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
                                // 4'ten fazla görsel varsa sayı göster
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
        Section("Detaylar") {
            Picker("Kaynak", selection: $viewModel.selectedSource) {
                ForEach(BookmarkSource.allCases) { source in
                    Text(source.displayName).tag(source)
                }
            }
            .pickerStyle(.menu)
            
            TextField("Notlar (opsiyonel)", text: $viewModel.note, axis: .vertical)
                .lineLimit(3...10)
                .focused($focusedField, equals: .note)
        }
    }
    
    private var tagsSection: some View {
        Section {
            TextField("Etiketler (virgülle ayır)", text: $viewModel.tagsInput)
                .focused($focusedField, equals: .tags)
        } header: {
            Text("Etiketler")
        } footer: {
            Text("Örnek: Swift, iOS, Tutorial")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var imageSection: some View {
        Section("Fotoğraf") {
            if let image = selectedImage {
                VStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    HStack {
                        Button(action: { showingImageCrop = true }) {
                            Label("Düzenle", systemImage: "crop")
                        }
                        
                        Spacer()
                        
                        if isProcessingOCR {
                            ProgressView().progressViewStyle(.circular)
                            Text("OCR işleniyor...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive, action: { selectedImage = nil }) {
                            Label("Kaldır", systemImage: "trash")
                        }
                    }
                    .font(.subheadline)
                }
            } else {
                Button(action: { showingImagePicker = true }) {
                    Label("Fotoğraf Ekle", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                }
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
            Text("Hatalar").foregroundStyle(.red)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("İptal") { dismiss() }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button("Kaydet") { saveBookmark() }
                .disabled(!viewModel.isValid)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Actions
    
    private func saveBookmark() {
        let manualImageData = selectedImage?.jpegData(compressionQuality: 0.8)
        let finalImageData = viewModel.tweetImagesData.first ?? manualImageData
        
        if viewModel.saveBookmark(withImage: finalImageData, extractedText: viewModel.note) {
            onSaved?()
            dismiss()
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
    
    enum Field: Hashable {
        case title, url, note, tags
    }
}

#Preview {
    AddBookmarkView(viewModel: AddBookmarkViewModel(repository: PreviewMockRepository.shared))
}
