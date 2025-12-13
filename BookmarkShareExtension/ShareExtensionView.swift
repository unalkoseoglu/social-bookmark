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
    @State private var metadataTitle: String?
    @State private var metadataDescription: String?
    @State private var metadataError: String?
    
    /// Loading state
    @State private var isLoadingMetadata = false
    @State private var isSaving = false
    
    /// Klavye focus
    @FocusState private var focusedField: Field?

    private var backgroundColor: Color { Color(.systemGroupedBackground) }
    private var cardBackground: Color { Color(.secondarySystemGroupedBackground) }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                urlSection
                    .listRowBackground(cardBackground)

                metadataSection
                    .listRowBackground(cardBackground)

                basicInfoSection
                    .listRowBackground(cardBackground)

                detailsSection
                    .listRowBackground(cardBackground)

                tagsSection
                    .listRowBackground(cardBackground)
            }
            .navigationTitle("Bookmark Kaydet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .scrollContentBackground(.hidden)
            .background(backgroundColor)
            .listSectionSpacing(12)
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
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(url.absoluteString)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "link")
                        .foregroundStyle(.blue)
                }

                sourceBadge
            }
            .padding(.vertical, 4)
        } header: {
            Label("Kaynak", systemImage: "globe")
                .foregroundStyle(.secondary)
        }
    }

    /// Metadata önizleme
    @ViewBuilder
    private var metadataSection: some View {
        if isLoadingMetadata || metadataTitle != nil || metadataDescription != nil || metadataError != nil {
            Section("Önizleme") {
                if isLoadingMetadata {
                    Label("Sayfa bilgileri getiriliyor", systemImage: "sparkle.magnifyingglass")
                        .foregroundStyle(.blue)
                }

                if let metaTitle = metadataTitle {
                    Label(metaTitle, systemImage: "text.book.closed")
                        .labelStyle(.titleAndIcon)
                }

                if let metaDescription = metadataDescription {
                    Text(metaDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let metadataError {
                    Label(metadataError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                }
            }
        }
    }
    
    /// Başlık ve kaynak
    private var basicInfoSection: some View {
        Section("Temel Bilgiler") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    TextField("Başlık", text: $title, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .title)

                    if isLoadingMetadata {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }

                Picker("Kaynak", selection: $selectedSource) {
                    ForEach(BookmarkSource.allCases) { source in
                        Text(source.displayName)
                            .tag(source)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.vertical, 4)
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
                .foregroundStyle(.secondary)
        }
    }

    private var sourceBadge: some View {
        HStack {
            Label(selectedSource.displayName, systemImage: "bookmark")
                .font(.footnote)
                .foregroundStyle(selectedSource.color)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(selectedSource.color.opacity(0.1))
                .clipShape(Capsule())

            Spacer()

            Button {
                selectedSource = .other
            } label: {
                Text("Kaynağı değiştir")
                    .font(.caption)
            }
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
        metadataError = nil
        metadataTitle = nil
        metadataDescription = nil

        // Kaynak otomatik tespit et
        selectedSource = BookmarkSource.detect(from: url.absoluteString)

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
            metadataError = error.localizedDescription

            // Metadata çekilemezse URL'den tahmin et
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
            }
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
            .reduce(into: [String]()) { uniqueTags, tag in
                if !uniqueTags.contains(tag) {
                    uniqueTags.append(tag)
                }
            }

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
