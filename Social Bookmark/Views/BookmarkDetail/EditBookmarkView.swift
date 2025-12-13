import SwiftUI

/// Mevcut bookmark'ı düzenleme ekranı
/// AddBookmarkView'a çok benzer ama mevcut değerleri doldurur
struct EditBookmarkView: View {
    // MARK: - Properties
    
    /// Düzenlenecek bookmark
    let bookmark: Bookmark
    
    /// Repository
    let repository: BookmarkRepositoryProtocol
    
    /// Sheet'i kapatmak için
    @Environment(\.dismiss) private var dismiss
    
    /// Form alanları - bookmark'tan başlangıç değerleri alır
    @State private var title: String
    @State private var url: String
    @State private var note: String
    @State private var selectedSource: BookmarkSource
    @State private var tagsInput: String
    
    /// Klavye focus
    @FocusState private var focusedField: Field?
    
    // MARK: - Initialization
    
    init(bookmark: Bookmark, repository: BookmarkRepositoryProtocol) {
        self.bookmark = bookmark
        self.repository = repository
        
        // Başlangıç değerlerini bookmark'tan al
        _title = State(initialValue: bookmark.title)
        _url = State(initialValue: bookmark.url ?? "")
        _note = State(initialValue: bookmark.note)
        _selectedSource = State(initialValue: bookmark.source)
        _tagsInput = State(initialValue: bookmark.tags.joined(separator: ", "))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Temel bilgiler
                basicInfoSection
                
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
        }
    }
    
    // MARK: - Sections
    
    private var basicInfoSection: some View {
        Section("Temel Bilgiler") {
            TextField("Başlık", text: $title, axis: .vertical)
                .lineLimit(2...4)
                .focused($focusedField, equals: .title)
            
            TextField("URL (opsiyonel)", text: $url)
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
    
    private var detailsSection: some View {
        Section("Detaylar") {
            Picker("Kaynak", selection: $selectedSource) {
                ForEach(BookmarkSource.allCases) { source in
                    Text(source.displayName)
                        .tag(source)
                }
            }
            .pickerStyle(.menu)
            
            TextField("Notlar (opsiyonel)", text: $note, axis: .vertical)
                .lineLimit(3...10)
                .focused($focusedField, equals: .note)
        }
    }
    
    private var tagsSection: some View {
        Section {
            TextField("Etiketler (virgülle ayır)", text: $tagsInput)
                .focused($focusedField, equals: .tags)
        } header: {
            Text("Etiketler")
        } footer: {
            Text("Örnek: Swift, iOS, Tutorial")
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
            .disabled(!isValid)
            .fontWeight(.semibold)
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
        // Bookmark'ı güncelle
        bookmark.title = title.trimmingCharacters(in: .whitespaces)
        bookmark.url = url.isEmpty ? nil : URLValidator.sanitize(url)
        bookmark.note = note.trimmingCharacters(in: .whitespaces)
        bookmark.source = selectedSource
        bookmark.tags = parseTags(from: tagsInput)
        
        // Repository'ye kaydet
        repository.update(bookmark)
        
        // Sheet'i kapat
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

// MARK: - Preview

#Preview {
    EditBookmarkView(
        bookmark: Bookmark(
            title: "SwiftUI Documentation",
            url: "https://developer.apple.com/swiftui",
            note: "Official docs",
            source: .article,
            tags: ["Swift", "iOS"]
        ),
        repository: PreviewMockRepository.shared
    )
}
