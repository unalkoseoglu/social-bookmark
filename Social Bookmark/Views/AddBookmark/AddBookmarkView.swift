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
