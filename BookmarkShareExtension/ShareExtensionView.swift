import SwiftUI

/// Safari Extension'dan açılan SwiftUI view
/// Kullanıcı buradan bookmark'ı kaydeder
struct ShareExtensionView: View {
    // MARK: - Properties
    
    /// Safari'den gelen URL
    let url: URL
    
    /// Repository
    let repository: BookmarkRepositoryProtocol
    
    /// Callbacks
    let onSave: () -> Void
    let onCancel: () -> Void
    
    // MARK: - State
    
    /// Form alanları
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var selectedSource: BookmarkSource = .other
    @State private var tagsInput: String = ""
    
    /// Loading state
    @State private var isLoadingMetadata = false
    @State private var isSaving = false
    
    /// Klavye focus
    @FocusState private var focusedField: Field?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // URL bölümü
                urlSection
                
                // Temel bilgiler
                basicInfoSection
                
                // Detaylar
                detailsSection
                
                // Etiketler
                tagsSection
            }
            .navigationTitle("Bookmark Kaydet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .disabled(isSaving)
            .task {
                // View açılınca metadata çek
                await fetchMetadata()
            }
        }
    }
    
    // MARK: - Sections
    
    /// URL gösterimi
    private var urlSection: some View {
        Section {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.blue)
                
                Text(url.absoluteString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } header: {
            Text("Kaynak")
        }
    }
    
    /// Başlık ve kaynak
    private var basicInfoSection: some View {
        Section("Temel Bilgiler") {
            // Başlık
            HStack {
                TextField("Başlık", text: $title, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .title)
                
                if isLoadingMetadata {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            
            // Kaynak
            Picker("Kaynak", selection: $selectedSource) {
                ForEach(BookmarkSource.allCases) { source in
                    Text(source.displayName)
                        .tag(source)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    /// Notlar
    private var detailsSection: some View {
        Section("Notlar") {
            TextField("Notlarınızı buraya ekleyin", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .focused($focusedField, equals: .note)
        }
    }
    
    /// Etiketler
    private var tagsSection: some View {
        Section {
            TextField("Etiketler (virgülle ayır)", text: $tagsInput)
                .focused($focusedField, equals: .tags)
        } header: {
            Text("Etiketler")
        } footer: {
            Text("Örnek: Swift, iOS, Tutorial")
                .font(.caption)
        }
    }
    
    /// Toolbar
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
    
    /// Metadata çek
    private func fetchMetadata() async {
        isLoadingMetadata = true
        
        // Kaynak otomatik tespit et
        selectedSource = BookmarkSource.detect(from: url.absoluteString)
        
        do {
            let metadata = try await URLMetadataService.shared.fetchMetadata(from: url.absoluteString)
            
            if let metaTitle = metadata.title {
                title = cleanMetaTitle(metaTitle)
            } else {
                // Fallback: URL'in son path component'i
                title = url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
            }
            
            if let metaDescription = metadata.description {
                note = String(metaDescription.prefix(500))
            }
        } catch {
            // Metadata çekilemezse URL'den tahmin et
            title = url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
        }
        
        isLoadingMetadata = false
    }
    
    /// Bookmark kaydet
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
        
        // Kısa bir gecikme ile UI feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSave()
        }
    }
    
    /// Meta title temizle
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
        url: URL(string: "https://developer.apple.com/documentation/swiftui")!,
        repository: PreviewMockRepository.shared,
        onSave: {},
        onCancel: {}
    )
}
