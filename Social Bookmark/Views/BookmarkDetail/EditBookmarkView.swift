import SwiftUI
import PhotosUI

/// Mevcut yer işaretini düzenleme ekranı
/// AddBookmarkView'a benzer şekilde çalışır ve mevcut verileri doldurur
struct EditBookmarkView: View {
    // MARK: - Properties
    
    /// Düzenlenecek yer işareti
    let bookmark: Bookmark
    
    /// Veri depoları (Repository)
    let repository: BookmarkRepositoryProtocol
    let categoryRepository: CategoryRepositoryProtocol
    
    /// Görünümü kapatmak için çevre değişkeni
    @Environment(\.dismiss) private var dismiss
    
    /// Form alanları - başlangıç değerleri mevcut yer işaretinden alınır
    @State private var title: String
    @State private var url: String
    @State private var note: String
    @State private var selectedSource: BookmarkSource
    @State private var tagsInput: String
    @State private var selectedCategoryId: UUID?
    @State private var categories: [Category] = []
    
    // Görsel Durumları
    @State private var existingImagesData: [Data]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var newImagesData: [Data] = []
    @State private var isLoadingImages = false
    @State private var showingImageOptions = false
    @State private var selectedImageIndex: Int?
    @State private var showingFullScreenImage = false
    
    // ✅ YENİ: Kaydetme durumu
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingSaveError = false
    
    /// Klavye odağı kontrolü
    @FocusState private var focusedField: Field?
    
    // MARK: - Computed Properties
    
    private var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryId }
    }
    
    /// Tüm görseller (mevcut + yeni eklenenler)
    private var allImages: [ImageItem] {
        var items: [ImageItem] = []
        
        // Mevcut kayıtlı resimler
        for (index, data) in existingImagesData.enumerated() {
            if let image = UIImage(data: data) {
                items.append(ImageItem(id: "existing_\(index)", image: image, isExisting: true, dataIndex: index))
            }
        }
        
        // Yeni seçilen resimler
        for (index, data) in newImagesData.enumerated() {
            if let image = UIImage(data: data) {
                items.append(ImageItem(id: "new_\(index)", image: image, isExisting: false, dataIndex: index))
            }
        }
        
        return items
    }
    
    private var totalImageCount: Int {
        existingImagesData.count + newImagesData.count
    }
    
    private var canAddMoreImages: Bool {
        totalImageCount < 4
    }
    
    // MARK: - Initialization
    
    init(bookmark: Bookmark, repository: BookmarkRepositoryProtocol, categoryRepository: CategoryRepositoryProtocol) {
        self.bookmark = bookmark
        self.repository = repository
        self.categoryRepository = categoryRepository
        
        // Başlangıç değerlerini atama
        _title = State(initialValue: bookmark.title)
        _url = State(initialValue: bookmark.url ?? "")
        _note = State(initialValue: bookmark.note)
        _selectedSource = State(initialValue: bookmark.source)
        _tagsInput = State(initialValue: bookmark.tags.joined(separator: ", "))
        _selectedCategoryId = State(initialValue: bookmark.categoryId)
        
        // Görsel verilerini yükle
        if let imagesData = bookmark.imagesData, !imagesData.isEmpty {
            _existingImagesData = State(initialValue: imagesData)
        } else if let imageData = bookmark.imageData {
            _existingImagesData = State(initialValue: [imageData])
        } else {
            _existingImagesData = State(initialValue: [])
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Temel bilgiler
                basicInfoSection
                
                // Görseller
                imagesSection
                
                // Kategori seçimi
                categorySection
                
                // Detaylar
                detailsSection
                
                // Etiketler
                tagsSection
            }
            .navigationTitle(String(localized: "editBookmark.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .onAppear {
                loadCategories()
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task {
                    await loadNewImages(from: newItems)
                }
            }
            .confirmationDialog(String(localized: "editBookmark.imageOptions"), isPresented: $showingImageOptions, presenting: selectedImageIndex) { index in
                Button(String(localized: "editBookmark.viewFullScreen")) {
                    showingFullScreenImage = true
                }
                
                Button(String(localized: "common.delete"), role: .destructive) {
                    deleteImage(at: index)
                }
                
                Button(String(localized: "common.cancel"), role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showingFullScreenImage) {
                if let index = selectedImageIndex, index < allImages.count {
                    FullScreenImageViewer(images: allImages.map { $0.image }, initialIndex: index)
                }
            }
            .alert(String(localized: "common.error"), isPresented: $showingSaveError) {
                Button(String(localized: "common.done"), role: .cancel) {}
            } message: {
                Text(saveError ?? String(localized: "editBookmark.saveError"))
            }
            .disabled(isSaving)
        }
    }
    
    // MARK: - Load Categories
    
    private func loadCategories() {
        categories = categoryRepository.fetchAll()
    }
    
    // MARK: - Sections
    
    private var basicInfoSection: some View {
        Section(String(localized: "editBookmark.section.basic")) {
            TextField(String(localized: "editBookmark.field.title"), text: $title, axis: .vertical)
                .lineLimit(2...4)
                .focused($focusedField, equals: .title)
            
            TextField(String(localized: "editBookmark.field.url"), text: $url)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .url)
            
            if !url.isEmpty && !isURLValid {
                Label(String(localized: "validation.invalid_url"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Images Section
    
    private var imagesSection: some View {
        Section {
            if allImages.isEmpty {
                // Resim yok - ekleme butonu
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 4,
                    matching: .images
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("editBookmark.addImage")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("editBookmark.maxImages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                // Görsel Listesi
                VStack(alignment: .leading, spacing: 12) {
                    // Resim grid'i
                    imageGrid
                    
                    // Alt bilgi ve ekleme butonu
                    HStack {
                        Text("editBookmark.imageCount \(totalImageCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if canAddMoreImages {
                            PhotosPicker(
                                selection: $selectedPhotoItems,
                                maxSelectionCount: 4 - totalImageCount,
                                matching: .images
                            ) {
                                Label(String(localized: "common.add"), systemImage: "plus")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Yükleme göstergesi
            if isLoadingImages {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("editBookmark.processingImages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("editBookmark.section.images")
        } footer: {
            if !allImages.isEmpty {
                Text("editBookmark.tapToEdit")
                    .font(.caption)
            }
        }
    }
    
    private var imageGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(allImages.enumerated()), id: \.element.id) { index, item in
                imageCell(for: item, at: index)
            }
        }
    }
    
    private func imageCell(for item: ImageItem, at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: item.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 100)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    selectedImageIndex = index
                    showingImageOptions = true
                }
            
            // Silme butonu
            Button {
                deleteImage(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .padding(6)
            
            // Yeni eklenen rozeti
            if !item.isExisting {
                VStack {
                    Spacer()
                    HStack {
                        Text("editBookmark.newBadge")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                        Spacer()
                    }
                    .padding(6)
                }
            }
        }
    }
    
    private var categorySection: some View {
        Section {
            if categories.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("editBookmark.noCategories")
                            .font(.subheadline)
                        Text("editBookmark.createCategoryHint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Picker(String(localized: "editBookmark.category"), selection: $selectedCategoryId) {
                    // Hiçbiri seçeneği
                    Label(String(localized: "editBookmark.uncategorized"), systemImage: "tray")
                        .tag(nil as UUID?)
                    
                    Divider()
                    
                    // Mevcut kategoriler
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
            Text("editBookmark.section.category")
        } footer: {
            if let category = selectedCategory {
                Label(category.name, systemImage: category.icon)
                    .font(.caption)
                    .foregroundStyle(category.color)
            }
        }
    }
    
    private var detailsSection: some View {
        Section(String(localized: "editBookmark.section.details")) {
            Picker(String(localized: "editBookmark.source"), selection: $selectedSource) {
                ForEach(BookmarkSource.allCases) { source in
                    HStack {
                        Text(source.emoji)
                        Text(source.displayName)
                    }
                    .tag(source)
                }
            }
            .pickerStyle(.menu)
            
            TextField(String(localized: "editBookmark.field.notes"), text: $note, axis: .vertical)
                .lineLimit(3...10)
                .focused($focusedField, equals: .note)
        }
    }
    
    private var tagsSection: some View {
        Section {
            TextField(String(localized: "editBookmark.field.tags"), text: $tagsInput)
                .focused($focusedField, equals: .tags)
        } header: {
            Text("editBookmark.section.tags")
        } footer: {
            Text("editBookmark.tagsHint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "common.cancel")) {
                dismiss()
            }
            .disabled(isSaving)
        }
        
        ToolbarItem(placement: .confirmationAction) {
            if isSaving {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(String(localized: "common.save")) {
                    Task {
                        await saveChanges()
                    }
                }
                .disabled(!isValid || isLoadingImages)
                .fontWeight(.semibold)
            }
        }
    }
    
    // MARK: - Image Loading
    
    private func loadNewImages(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        
        await MainActor.run {
            isLoadingImages = true
        }
        
        var loadedData: [Data] = []
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Resmi optimize et
                if let optimizedData = optimizeImage(data: data) {
                    loadedData.append(optimizedData)
                }
            }
        }
        
        await MainActor.run {
            // Toplam 4'ü geçmeyecek şekilde ekle
            let remainingSlots = 4 - existingImagesData.count - newImagesData.count
            let itemsToAdd = Array(loadedData.prefix(remainingSlots))
            newImagesData.append(contentsOf: itemsToAdd)
            
            selectedPhotoItems = []
            isLoadingImages = false
        }
    }
    
    private func optimizeImage(data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        
        // Maksimum boyut
        let maxSize: CGFloat = 1200
        var targetSize = image.size
        
        if image.size.width > maxSize || image.size.height > maxSize {
            let ratio = min(maxSize / image.size.width, maxSize / image.size.height)
            targetSize = CGSize(
                width: image.size.width * ratio,
                height: image.size.height * ratio
            )
        }
        
        // Yeniden Boyutlandır
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        // JPEG olarak sıkıştır
        return resizedImage.jpegData(compressionQuality: 0.8)
    }
    
    private func deleteImage(at index: Int) {
        let item = allImages[index]
        
        withAnimation {
            if item.isExisting {
                existingImagesData.remove(at: item.dataIndex)
            } else {
                newImagesData.remove(at: item.dataIndex)
            }
        }
    }
    
    // MARK: - Validation
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var isURLValid: Bool {
        url.isEmpty || URLValidator.isValid(url)
    }
    
    // MARK: - Actions
    
    /// ✅ DÜZELTME: Async save with Supabase Storage upload
    private func saveChanges() async {
        await MainActor.run {
            isSaving = true
            saveError = nil
        }
        
        defer {
            Task { @MainActor in
                isSaving = false
            }
        }
        
        // Bookmark verilerini güncelle
        bookmark.title = title.trimmingCharacters(in: .whitespaces)
        
        var sanitizedURL = url.isEmpty ? nil : URLValidator.sanitize(url)
        var finalSource = selectedSource
        
        // ✅ URL Extraction: Eğer URL boşsa ama title veya note içinde varsa onu al
        if sanitizedURL == nil {
            if let extractedURL = URLValidator.findFirstURL(in: title) ?? URLValidator.findFirstURL(in: note) {
                sanitizedURL = URLValidator.sanitize(extractedURL)
                // Kaynağı otomatik tespit et
                finalSource = BookmarkSource.detect(from: sanitizedURL!)
                print("🔗 [EditBookmark] Extracted URL: \(sanitizedURL!) from content")
            }
        }
        
        bookmark.url = sanitizedURL
        bookmark.note = note.trimmingCharacters(in: .whitespaces)
        bookmark.source = finalSource
        bookmark.tags = parseTags(from: tagsInput)
        bookmark.categoryId = selectedCategoryId
        
        // ✅ YENİ: Görselleri Supabase Storage'a yükle
        var uploadedImageUrls: [String] = []
        
        // Mevcut cloud URL'lerini koru (eğer local görsel silinmediyse)
        if let existingUrls = bookmark.imageUrls {
            // Mevcut görseller hala varsa URL'leri koru
            let existingCount = existingImagesData.count
            uploadedImageUrls = Array(existingUrls.prefix(existingCount))
        }
        
        // Yeni görselleri Supabase'e yükle
        if !newImagesData.isEmpty {
            print("📤 [EditBookmark] Uploading \(newImagesData.count) new images to Supabase...")
            
            for (index, imageData) in newImagesData.enumerated() {
                if let image = UIImage(data: imageData) {
                    do {
                        let imageUrl = try await ImageUploadService.shared.uploadImage(
                            image,
                            for: bookmark.id,
                            index: existingImagesData.count + index
                        )
                        uploadedImageUrls.append(imageUrl)
                        print("✅ [EditBookmark] Image \(index + 1) uploaded: \(imageUrl.prefix(50))...")
                    } catch {
                        print("❌ [EditBookmark] Failed to upload image \(index + 1): \(error.localizedDescription)")
                        // Hata olsa bile devam et, local kaydet
                    }
                }
            }
        }
        
        // Local resimleri güncelle
        let allImagesData = existingImagesData + newImagesData
        
        if allImagesData.isEmpty {
            bookmark.imageData = nil
            bookmark.imagesData = nil
            bookmark.imageUrls = nil
        } else {
            bookmark.imageData = allImagesData.first
            bookmark.imagesData = allImagesData.count > 1 ? allImagesData : nil
            
            // ✅ Cloud URL'lerini kaydet
            if !uploadedImageUrls.isEmpty {
                bookmark.imageUrls = uploadedImageUrls
                print("✅ [EditBookmark] Saved \(uploadedImageUrls.count) image URLs to bookmark")
            }
        }
        
        // Veritabanını güncelle (SyncableRepository otomatik sync yapacak)
        repository.update(bookmark)
        
        print("✅ [EditBookmark] Bookmark updated successfully")
        
        // Görünümü kapat
        await MainActor.run {
            dismiss()
        }
    }
    
    private func parseTags(from input: String) -> [String] {
        input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Field Enum
    
    enum Field: Hashable {
        case title, url, note, tags
    }
}

// MARK: - Image Item Model

struct ImageItem: Identifiable {
    let id: String
    let image: UIImage
    let isExisting: Bool
    let dataIndex: Int
}

// MARK: - Full Screen Image Viewer

struct FullScreenImageViewer: View {
    let images: [UIImage]
    let initialIndex: Int
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    
    init(images: [UIImage], initialIndex: Int) {
        self.images = images
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .tag(index)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value
                                }
                                .onEnded { _ in
                                    withAnimation {
                                        scale = 1.0
                                    }
                                }
                        )
                        .scaleEffect(scale)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            
            // Kapatma butonu
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding()
                }
                
                Spacer()
                
                // Resim sayacı
                if images.count > 1 {
                    Text("\(currentIndex + 1) / \(images.count)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom)
                }
            }
        }
    }
}


// MARK: - Preview

#Preview {
    EditBookmarkView(
        bookmark: Bookmark(
            title: "SwiftUI Dokümantasyonu",
            url: "https://developer.apple.com/swiftui",
            note: "Resmi belgeler",
            source: .article,
            tags: ["Swift", "iOS"]
        ),
        repository: PreviewMockRepository.shared,
        categoryRepository: PreviewMockCategoryRepository.shared
    )
}
