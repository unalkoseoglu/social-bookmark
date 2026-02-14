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
    
    // IMAGE MANAGEMENT REFACTORED
    struct ImageRecord: Identifiable {
        let id = UUID()
        var data: Data?
        var cloudUrl: String?
        var isNew: Bool = false
    }
    
    @State private var imageRecords: [ImageRecord] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isLoadingImages = false
    @State private var showingImageOptions = false
    @State private var selectedImageId: UUID?
    @State private var showingFullScreenImage = false
    
    @State private var hasUserModifiedImages = false
    
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
    
    /// Tüm görseller (UI için ImageItem formatında)
    private var allImages: [ImageItem] {
        imageRecords.compactMap { record in
            guard let data = record.data, let image = UIImage(data: data) else { return nil }
            return ImageItem(
                id: record.id.uuidString,
                image: image,
                isExisting: !record.isNew,
                dataIndex: 0 // Not strictly needed anymore but kept for compatibility
            )
        }
    }
    
    private var totalImageCount: Int {
        imageRecords.count
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
        
        // Görsel verilerini yükle (ImageRecord olarak)
        var initialRecords: [ImageRecord] = []
        
        // 1. Cloud URL'lerinden kayıt oluştur
        if let urls = bookmark.imageUrls {
            for url in urls {
                initialRecords.append(ImageRecord(cloudUrl: url))
            }
        }
        
        // 2. Eğer local'de resim verisi varsa, URL'lerle eşleştir veya yeni ekle
        let localDataList: [Data]
        if let imagesData = bookmark.imagesData, !imagesData.isEmpty {
            localDataList = imagesData
        } else if let imageData = bookmark.imageData {
            localDataList = [imageData]
        } else {
            localDataList = []
        }
        
        // Local datayı mevcut recordlara dağıt (URL sırasına göre)
        for (index, data) in localDataList.enumerated() {
            if index < initialRecords.count {
                initialRecords[index].data = data
            } else if initialRecords.count < 4 {
                // Eğer URL yoksa ama data varsa (beklenmedik durum ama handle edelim)
                initialRecords.append(ImageRecord(data: data))
            }
        }
        
        _imageRecords = State(initialValue: initialRecords)
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
            .navigationTitle(LanguageManager.shared.localized("editBookmark.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .onAppear {
                loadCategories()
                Task {
                    await loadExistingImagesFromCloud()
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                if !newItems.isEmpty {
                    hasUserModifiedImages = true
                    Task {
                        await loadNewImages(from: newItems)
                    }
                }
            }
            .confirmationDialog(LanguageManager.shared.localized("editBookmark.imageOptions"), isPresented: $showingImageOptions, presenting: selectedImageId) { id in
                Button(LanguageManager.shared.localized("editBookmark.viewFullScreen")) {
                    showingFullScreenImage = true
                }
                
                Button(LanguageManager.shared.localized("common.delete"), role: .destructive) {
                    print("⚠️ [EditBookmark] Delete triggered FROM DIALOG for ID: \(id)")
                    deleteImage(with: id, source: "ConfirmationDialog")
                }
                
                Button(LanguageManager.shared.localized("common.cancel"), role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showingFullScreenImage) {
                if let id = selectedImageId, 
                   let index = allImages.firstIndex(where: { $0.id == id.uuidString }) {
                    FullScreenImageViewer(images: allImages.map { $0.image }, initialIndex: index)
                }
            }
            .alert(LanguageManager.shared.localized("common.error"), isPresented: $showingSaveError) {
                Button(LanguageManager.shared.localized("common.done"), role: .cancel) {}
            } message: {
                Text(saveError ?? LanguageManager.shared.localized("editBookmark.saveError"))
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
        Section(LanguageManager.shared.localized("editBookmark.section.basic")) {
            TextField(LanguageManager.shared.localized("editBookmark.field.title"), text: $title, axis: .vertical)
                .lineLimit(2...4)
                .focused($focusedField, equals: .title)
            
            TextField(LanguageManager.shared.localized("editBookmark.field.url"), text: $url)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .url)
            
            if !url.isEmpty && !isURLValid {
                Label(LanguageManager.shared.localized("validation.invalid_url"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Images Section
    
    private var imagesSection: some View {
        Section {
            if imageRecords.isEmpty {
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
                            Text(LanguageManager.shared.localized("editBookmark.addImage"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(LanguageManager.shared.localized("editBookmark.maxImages"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain) // Prevent form from hijacking tap
            } else {
                // Görsel Listesi
                VStack(alignment: .leading, spacing: 12) {
                    // Resim grid'i
                    imageGrid
                    
                    // Alt bilgi ve ekleme butonu
                    HStack {
                        Text(LanguageManager.shared.localized("editBookmark.imageCount %@", "\(totalImageCount)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if canAddMoreImages {
                            PhotosPicker(
                                selection: $selectedPhotoItems,
                                maxSelectionCount: 4 - totalImageCount,
                                matching: .images
                            ) {
                                Label(LanguageManager.shared.localized("common.add"), systemImage: "plus")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.plain) // Prevent form from hijacking tap
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
                    Text(LanguageManager.shared.localized("editBookmark.processingImages"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(LanguageManager.shared.localized("editBookmark.section.images"))
        } footer: {
            if !imageRecords.isEmpty {
                Text(LanguageManager.shared.localized("editBookmark.tapToEdit"))
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
            ForEach(imageRecords) { record in
                imageCell(for: record)
            }
        }
    }
    
    private func imageCell(for record: ImageRecord) -> some View {
        ZStack(alignment: .topTrailing) {
            if let data = record.data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture {
                        selectedImageId = record.id
                        showingImageOptions = true
                    }
            } else {
                // Yüklenme durumu
                ZStack {
                    Color.gray.opacity(0.1)
                    ProgressView()
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Silme butonu
            Button {
                print("⚠️ [EditBookmark] Delete triggered FROM GRID 'X' for ID: \(record.id)")
                deleteImage(with: record.id, source: "GridButton")
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .buttonStyle(.plain) // CRITICAL: Stop Form/List from aggregating taps
            .padding(6)
            
            // Yeni eklenen rozeti
            if record.isNew {
                VStack {
                    Spacer()
                    HStack {
                        Text(LanguageManager.shared.localized("editBookmark.newBadge"))
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
                        Text(LanguageManager.shared.localized("editBookmark.noCategories"))
                            .font(.subheadline)
                        Text(LanguageManager.shared.localized("editBookmark.createCategoryHint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Picker(LanguageManager.shared.localized("editBookmark.category"), selection: $selectedCategoryId) {
                    // Hiçbiri seçeneği
                    Label(LanguageManager.shared.localized("editBookmark.uncategorized"), systemImage: "tray")
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
            Text(LanguageManager.shared.localized("editBookmark.section.category"))
        } footer: {
            if let category = selectedCategory {
                Label(category.name, systemImage: category.icon)
                    .font(.caption)
                    .foregroundStyle(category.color)
            }
        }
    }
    
    private var detailsSection: some View {
        Section(LanguageManager.shared.localized("editBookmark.section.details")) {
            Picker(LanguageManager.shared.localized("editBookmark.source"), selection: $selectedSource) {
                ForEach(BookmarkSource.allCases) { source in
                    HStack {
                        Text(source.emoji)
                        Text(source.displayName)
                    }
                    .tag(source)
                }
            }
            .pickerStyle(.menu)
            
            TextField(LanguageManager.shared.localized("editBookmark.field.notes"), text: $note, axis: .vertical)
                .lineLimit(3...10)
                .focused($focusedField, equals: .note)
        }
    }
    
    private var tagsSection: some View {
        Section {
            TextField(LanguageManager.shared.localized("editBookmark.field.tags"), text: $tagsInput)
                .focused($focusedField, equals: .tags)
        } header: {
            Text(LanguageManager.shared.localized("editBookmark.section.tags"))
        } footer: {
            Text(LanguageManager.shared.localized("editBookmark.tagsHint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(LanguageManager.shared.localized("common.cancel")) {
                dismiss()
            }
            .disabled(isSaving)
        }
        
        ToolbarItem(placement: .confirmationAction) {
            if isSaving {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(LanguageManager.shared.localized("common.save")) {
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
            let remainingSlots = 4 - imageRecords.count
            let datasToAdd = Array(loadedData.prefix(remainingSlots))
            
            for data in datasToAdd {
                imageRecords.append(ImageRecord(data: data, isNew: true))
            }
            
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
    
    private func deleteImage(with id: UUID, source: String = "Unknown") {
        withAnimation {
            if let index = imageRecords.firstIndex(where: { $0.id == id }) {
                imageRecords.remove(at: index)
                hasUserModifiedImages = true
                print("🗑️ [EditBookmark] Image removed: \(id) (Source: \(source))")
            }
        }
    }
    
    /// ✅ GÜVENLİ: Cloud'daki resimleri local'e çek
    private func loadExistingImagesFromCloud() async {
        // İhtiyaç duyulan kayıtların listesini al
        let pendingTasks = imageRecords.compactMap { record in
            record.data == nil && record.cloudUrl != nil ? (record.id, record.cloudUrl!) : nil
        }
        
        guard !pendingTasks.isEmpty else { return }
        
        await MainActor.run { isLoadingImages = true }
        
        for (id, path) in pendingTasks {
            if let image = await ImageUploadService.shared.loadImage(from: path) {
                if let data = image.jpegData(compressionQuality: 0.8) {
                    await MainActor.run {
                        // ID üzerinden kontrol et, indeks kayması veya silme durumunda güvenlidir
                        if let index = imageRecords.firstIndex(where: { $0.id == id }) {
                            imageRecords[index].data = data
                            print("✅ [EditBookmark] Loaded cloud image data for ID: \(id)")
                        }
                    }
                }
            }
        }
        
        await MainActor.run {
            isLoadingImages = false
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
        
        // ✅ RESİM KAYDETME MANTIĞI ( ImageRecord ile GÜVENLİ HALE GETİRİLDİ )
        
        var finalCloudUrls: [String] = []
        var finalLocalDatas: [Data] = []
        
        for (index, record) in imageRecords.enumerated() {
            if let data = record.data {
                finalLocalDatas.append(data)
            }
            
            if record.isNew, let data = record.data, let image = UIImage(data: data) {
                // Yeni resmi yükle
                do {
                    print("📤 [EditBookmark] Uploading new image at index \(index)...")
                    let newUrl = try await ImageUploadService.shared.uploadImage(image, for: bookmark.id, index: index)
                    finalCloudUrls.append(newUrl)
                } catch {
                    print("❌ [EditBookmark] Failed to upload new image: \(error.localizedDescription)")
                    // Hata olsa bile URL listesini bozma, varsa eski/null handle et
                }
            } else if let cloudUrl = record.cloudUrl {
                // Mevcut cloud URL'ini koru
                finalCloudUrls.append(cloudUrl)
            }
        }
        
        // Bookmark verilerini güncelle
        bookmark.imageData = finalLocalDatas.first
        bookmark.imagesData = finalLocalDatas.count > 1 ? finalLocalDatas : nil
        
        // Sadece bir değişiklik varsa veya fotoğraflar silindiyse güncelle
        if hasUserModifiedImages || !finalCloudUrls.isEmpty || bookmark.imageUrls != nil {
            bookmark.imageUrls = finalCloudUrls.isEmpty ? nil : finalCloudUrls
            print("✅ [EditBookmark] Saved \(finalCloudUrls.count) image URLs to bookmark")
        }
        
        // Veritabanını güncelle (SyncableRepository otomatik sync yapacak)
        repository.update(bookmark)
        
        // ✅ HomeViewModel'i bilgilendir (kategori sayıları vs. güncellensin)
        NotificationCenter.default.post(name: .bookmarkDidUpdate, object: nil)
        
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
