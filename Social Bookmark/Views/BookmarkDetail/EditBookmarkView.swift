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
            .navigationTitle("Düzenle")
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
            .confirmationDialog("Resim Seçenekleri", isPresented: $showingImageOptions, presenting: selectedImageIndex) { index in
                Button("Tam Ekran Görüntüle") {
                    showingFullScreenImage = true
                }
                
                Button("Sil", role: .destructive) {
                    deleteImage(at: index)
                }
                
                Button("İptal", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showingFullScreenImage) {
                if let index = selectedImageIndex, index < allImages.count {
                    FullScreenImageViewer(images: allImages.map { $0.image }, initialIndex: index)
                }
            }
        }
    }
    
    // MARK: - Load Categories
    
    private func loadCategories() {
        categories = categoryRepository.fetchAll()
    }
    
    // MARK: - Sections
    
    private var basicInfoSection: some View {
        Section("Temel Bilgiler") {
            TextField("Başlık", text: $title, axis: .vertical)
                .lineLimit(2...4)
                .focused($focusedField, equals: .title)
            
            TextField("URL (isteğe bağlı)", text: $url)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .url)
            
            if !url.isEmpty && !isURLValid {
                Label("Geçersiz URL formatı", systemImage: "exclamationmark.triangle")
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
                            Text("Resim Ekle")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Maksimum 4 resim ekleyebilirsiniz")
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
                        Text("\(totalImageCount)/4 resim")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if canAddMoreImages {
                            PhotosPicker(
                                selection: $selectedPhotoItems,
                                maxSelectionCount: 4 - totalImageCount,
                                matching: .images
                            ) {
                                Label("Ekle", systemImage: "plus")
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
                    Text("Resimler işleniyor...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Resimler")
        } footer: {
            if !allImages.isEmpty {
                Text("Düzenlemek için resme dokunun")
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
                        Text("YENİ")
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
                        Text("Kategori tanımlanmamış")
                            .font(.subheadline)
                        Text("Ana ekrandan yeni bir kategori oluşturabilirsiniz")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Picker("Kategori", selection: $selectedCategoryId) {
                    // Hiçbiri seçeneği
                    Label("Kategorisiz", systemImage: "tray")
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
            Text("Kategori")
        } footer: {
            if let category = selectedCategory {
                Label(category.name, systemImage: category.icon)
                    .font(.caption)
                    .foregroundStyle(category.color)
            }
        }
    }
    
    private var detailsSection: some View {
        Section("Detaylar") {
            Picker("Kaynak", selection: $selectedSource) {
                ForEach(BookmarkSource.allCases) { source in
                    HStack {
                        Text(source.emoji)
                        Text(source.displayName)
                    }
                    .tag(source)
                }
            }
            .pickerStyle(.menu)
            
            TextField("Notlar (isteğe bağlı)", text: $note, axis: .vertical)
                .lineLimit(3...10)
                .focused($focusedField, equals: .note)
        }
    }
    
    private var tagsSection: some View {
        Section {
            TextField("Etiketler (virgülle ayırın)", text: $tagsInput)
                .focused($focusedField, equals: .tags)
        } header: {
            Text("Etiketler")
        } footer: {
            Text("Örnek: Swift, iOS, Eğitim")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("İptal") {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button("Kaydet") {
                saveChanges()
            }
            .disabled(!isValid || isLoadingImages)
            .fontWeight(.semibold)
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
    
    private func saveChanges() {
        // Bookmark verilerini güncelle
        bookmark.title = title.trimmingCharacters(in: .whitespaces)
        bookmark.url = url.isEmpty ? nil : URLValidator.sanitize(url)
        bookmark.note = note.trimmingCharacters(in: .whitespaces)
        bookmark.source = selectedSource
        bookmark.tags = parseTags(from: tagsInput)
        bookmark.categoryId = selectedCategoryId
        
        // Resimleri güncelle
        let allImagesData = existingImagesData + newImagesData
        
        if allImagesData.isEmpty {
            bookmark.imageData = nil
            bookmark.imagesData = nil
        } else {
            bookmark.imageData = allImagesData.first
            bookmark.imagesData = allImagesData.count > 1 ? allImagesData : nil
        }
        
        // Veritabanını güncelle
        repository.update(bookmark)
        
        // Görünümü kapat
        dismiss()
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
