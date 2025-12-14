import SwiftUI

/// Bookmark detay ekranı - Tek bookmark'ın tüm bilgilerini gösterir
struct BookmarkDetailView: View {
    // MARK: - Properties
    
    let bookmark: Bookmark
    let repository: BookmarkRepositoryProtocol
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingFullScreenImage = false
    @State private var selectedImageIndex = 0
    
    // MARK: - Computed Properties
    
    /// Tüm görselleri al (çoklu veya tek)
    private var allImages: [UIImage] {
        // Bookmark modelindeki allImagesData computed property'sini kullan
        return bookmark.allImagesData.compactMap { UIImage(data: $0) }
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Hero Section - Başlık ve Ana Bilgiler
                VStack(alignment: .leading, spacing: 16) {
                    // Source + Read Status
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text(bookmark.source.emoji)
                                .font(.system(size: 18))
                            Text(bookmark.source.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                        
                        Spacer()
                        
                        if bookmark.isRead {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                Text("Okundu")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    
                    // Başlık - Büyük ve belirgin
                    Text(bookmark.title)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Kategori ve Tarih
                    HStack(spacing: 16) {
                        if let categoryId = bookmark.categoryId {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .font(.caption)
                                Text("Kategori")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(bookmark.formattedDate)
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                }
                .padding(20)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(.systemBackground),
                            Color(.systemGray6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
                
                // Görsel Bölümü
                if !allImages.isEmpty {
                    imageSection
                        .padding(.horizontal, 16)
                }
                
                // URL Bölümü - URL'yi kopyalanabilir yap
                if bookmark.hasURL {
                    urlSection
                        .padding(.horizontal, 16)
                }
                
                // Not Bölümü - Okuma için optimize
                if bookmark.hasNote {
                    readableNoteSection
                        .padding(.horizontal, 16)
                }
                
                // Etiketler
                if bookmark.hasTags {
                    tagsSection
                        .padding(.horizontal, 16)
                }
                
                // Metadata
                metadataSection
                    .padding(.horizontal, 16)
                
                // Action Buttons
                actionButtons
                    .padding(.horizontal, 16)
                
                Spacer(minLength: 20)
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Detaylar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingEditSheet) {
            EditBookmarkView(
                bookmark: bookmark,
                repository: repository
            )
        }
        .alert("Bookmark Silinsin mi?", isPresented: $showingDeleteAlert) {
            Button("İptal", role: .cancel) {}
            Button("Sil", role: .destructive) {
                deleteBookmark()
            }
        } message: {
            Text("Bu işlem geri alınamaz.")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = bookmark.url {
                ShareSheet(items: [url])
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            FullScreenImageGalleryView(
                images: allImages,
                selectedIndex: $selectedImageIndex
            )
        }
    }
    
    // MARK: - Sections
    
    // Eski headerSection'ı kaldırdık, hero section şimdi body'de
    
    
    /// Görsel bölümü - yatay scroll galeri
    @ViewBuilder
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Görsel", systemImage: "photo.fill")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if allImages.count > 1 {
                    Text("\(allImages.count) görsel")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            
            // Görsel galerisi - yatay scroll
            if allImages.count == 1 {
                // Tek görsel - scroll yok
                singleImageView(allImages[0], index: 0)
            } else {
                // Çoklu görsel - yatay scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<allImages.count, id: \.self) { index in
                            Image(uiImage: allImages[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 280, height: 200)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    selectedImageIndex = index
                                    showingFullScreenImage = true
                                }
                                .overlay(alignment: .topTrailing) {
                                    Text("\(index + 1)/\(allImages.count)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                        .padding(8)
                                }
                        }
                    }
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
    
    /// Tek görsel view
    private func singleImageView(_ image: UIImage, index: Int) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .onTapGesture {
                selectedImageIndex = index
                showingFullScreenImage = true
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(8)
            }
    }
    
    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Kaynak", systemImage: "link")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if let urlString = bookmark.url, let url = URL(string: urlString) {
                // Open in browser
                Link(destination: url) {
                    HStack(spacing: 12) {
                        Image(systemName: "safari")
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tarayıcıda Aç")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(url.host ?? urlString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Copy URL button
                Button(action: {
                    UIPasteboard.general.string = urlString
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("URL'yi Kopyala")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(urlString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
    
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notlar", systemImage: "note.text")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(bookmark.note)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    /// Okuma için optimize edilmiş not bölümü
    private var readableNoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("İçerik", systemImage: "doc.text")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(bookmark.note.split(separator: " ").count) kelime")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            // Okunabilir text bölümü
            Text(bookmark.note)
                .font(.system(.body, design: .default))
                .lineSpacing(6)
                .tracking(0.3)
                .foregroundStyle(.primary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.systemBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Copy to clipboard button
            Button(action: {
                UIPasteboard.general.string = bookmark.note
            }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                    Text("Metni Kopyala")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Etiketler", systemImage: "tag.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(bookmark.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Bilgiler", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                MetadataRow(
                    icon: "calendar",
                    title: "Oluşturulma",
                    value: bookmark.formattedDate
                )
                
                MetadataRow(
                    icon: "clock",
                    title: "Süre",
                    value: bookmark.relativeDate
                )
                
                if bookmark.hasImage {
                    MetadataRow(
                        icon: "photo",
                        title: "Görsel",
                        value: "\(bookmark.imageCount) adet"
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: toggleReadStatus) {
                    HStack(spacing: 8) {
                        Image(systemName: bookmark.isRead ? "circle" : "checkmark.circle.fill")
                        Text(bookmark.isRead ? "Okunmadı" : "Okundu")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(bookmark.isRead ? Color.orange : Color.green)
                    .foregroundStyle(.white)
                    .fontWeight(.medium)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                Button(action: { showingEditSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                        Text("Düzenle")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple.opacity(0.9))
                    .foregroundStyle(.white)
                    .fontWeight(.medium)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            if bookmark.hasURL, let urlString = bookmark.url, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "safari")
                        Text("Tarayıcıda Aç")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .fontWeight(.medium)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("Sil")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.9))
                .foregroundStyle(.white)
                .fontWeight(.medium)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.top, 12)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { showingShareSheet = true }) {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(!bookmark.hasURL)
        }
    }
    
    // MARK: - Actions
    
    private func toggleReadStatus() {
        withAnimation {
            bookmark.isRead.toggle()
            repository.update(bookmark)
        }
    }
    
    private func deleteBookmark() {
        repository.delete(bookmark)
        dismiss()
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        } else if bytes >= 1_000 {
            return String(format: "%.1f KB", Double(bytes) / 1_000)
        }
        return "\(bytes) B"
    }
}

// MARK: - Full Screen Image Gallery View

/// Tam ekran görsel galerisi - swipe ile geçiş
struct FullScreenImageGalleryView: View {
    let images: [UIImage]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Görsel galerisi (swipe ile geçiş)
            TabView(selection: $selectedIndex) {
                ForEach(0..<images.count, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(selectedIndex == index ? scale : 1.0)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    if selectedIndex == index {
                                        scale = lastScale * value
                                    }
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                            lastScale = 1.0
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                if scale > 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                }
                            }
                        }
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            // Üst bar
            VStack {
                HStack {
                    // Sayfa göstergesi
                    if images.count > 1 {
                        Text("\(selectedIndex + 1) / \(images.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Kapat butonu
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                    }
                }
                .padding()
                
                Spacer()
                
                // Zoom bilgisi
                if scale != 1.0 {
                    Text("\(Int(scale * 100))%")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 60)
                }
            }
        }
        .onChange(of: selectedIndex) { _, _ in
            // Sayfa değişince zoom resetle
            withAnimation {
                scale = 1.0
                lastScale = 1.0
            }
        }
    }
}

// MARK: - Supporting Views

struct MetadataRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.positions[index].x,
                           y: bounds.minY + result.positions[index].y),
                proposal: .unspecified
            )
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: width, height: y + lineHeight)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        BookmarkDetailView(
            bookmark: Bookmark(
                title: "SwiftUI Best Practices",
                url: "https://developer.apple.com/documentation/swiftui",
                note: "Great article covering advanced patterns.",
                source: .twitter,
                tags: ["Swift", "iOS"]
            ),
            repository: PreviewMockRepository.shared
        )
    }
}
