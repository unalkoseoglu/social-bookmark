import SwiftUI
import UIKit

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
    private var accentColor: Color { Color(.systemBlue) }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // URL bölümü
                urlSection

                // Metadata önizleme
                metadataSection

                // Temel bilgiler
                basicInfoSection
                    .listRowBackground(cardBackground)

                metadataSection
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
    
    /// Metadata önizleme
    @ViewBuilder
    private var metadataSection: some View {
        if isLoadingMetadata || metadataTitle != nil || metadataDescription != nil || metadataError != nil {
            Section("Önizleme") {
                VStack(alignment: .leading, spacing: 10) {
                    if isLoadingMetadata {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Sayfa bilgileri getiriliyor")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let metaTitle = metadataTitle {
                        metadataCard(title: metaTitle, description: metadataDescription)
                    }

                    if let metadataError {
                        metadataErrorCard(metadataError)
                    }
                }
            }
        }
    }

    /// Metadata önizleme
    @ViewBuilder
    private var metadataSection: some View {
        if metadataTitle != nil || metadataDescription != nil || metadataError != nil {
            Section("Önizleme") {
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
            VStack(alignment: .leading, spacing: 12) {
                sourceCard

                HStack(alignment: .center, spacing: 8) {
                    TextField("Başlık", text: $title, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .title)

                    if isLoadingMetadata {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                Picker("Kaynak", selection: $selectedSource) {
                    ForEach(BookmarkSource.allCases) { source in
                        Text(source.displayName)
                            .tag(source)
                    }
                }
                .pickerStyle(.segmented)

                metadataStatusRow
            }
            .padding(.vertical, 4)
        }
    }
    
    /// Notlar
    private var detailsSection: some View {
        Section("Detaylar") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Notlarınızı buraya ekleyin", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .note)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Divider().padding(.vertical, 4)

                sourceSummary
            }
        }
    }
    
    /// Etiketler
    private var tagsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Etiketler (virgülle ayır)", text: $tagsInput)
                    .focused($focusedField, equals: .tags)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Örnek: Swift, iOS, Tutorial")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Etiketler")
        }
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(url.absoluteString)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            } icon: {
                Image(systemName: "globe")
                    .foregroundStyle(accentColor)
            }

            HStack {
                Label(selectedSource.displayName, systemImage: "bookmark")
                    .font(.footnote)
                    .foregroundStyle(selectedSource.color)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(selectedSource.color.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                Button {
                    UIPasteboard.general.string = url.absoluteString
                } label: {
                    Label("Kopyala", systemImage: "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var metadataStatusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: metadataStatusIcon)
                .foregroundStyle(metadataStatusColor)
            Text(metadataStatusText)
                .font(.caption)
                .foregroundStyle(metadataStatusColor)
            Spacer()

            Button {
                Task { await fetchMetadata() }
            } label: {
                Label("Yenile", systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(isLoadingMetadata)
        }
        .padding(10)
        .background(metadataStatusColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var sourceSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Kaynak", systemImage: "link")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(url.absoluteString)
                .font(.footnote)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            HStack(spacing: 12) {
                Image(systemName: "paperclip")
                Text(selectedSource.displayName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var metadataStatusIcon: String {
        if isLoadingMetadata { return "hourglass" }
        if metadataError != nil { return "exclamationmark.triangle.fill" }
        if metadataTitle != nil || metadataDescription != nil { return "checkmark.seal.fill" }
        return "sparkle.magnifyingglass"
    }

    private var metadataStatusText: String {
        if isLoadingMetadata { return "Metadata çekiliyor" }
        if let metadataError { return "Metadata alınamadı: \(metadataError)" }
        if metadataTitle != nil || metadataDescription != nil { return "Sayfa bilgileri dolduruldu" }
        return "Metadata bekleniyor"
    }

    private var metadataStatusColor: Color {
        if isLoadingMetadata { return .orange }
        if metadataError != nil { return .red }
        if metadataTitle != nil || metadataDescription != nil { return .green }
        return accentColor
    }

    private func metadataCard(title: String, description: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.image")
                    .foregroundStyle(accentColor)
                Text("Sayfa Özeti")
                    .font(.headline)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            Divider()

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let description, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func metadataErrorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Metadata çekilemedi")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
