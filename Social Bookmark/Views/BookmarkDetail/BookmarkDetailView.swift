import SwiftUI

/// Bookmark detay ekranı - Kitap okuma uygulaması tarzı tasarım
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
    
    private var allImages: [UIImage] {
        return bookmark.allImagesData.compactMap { UIImage(data: $0) }
    }
    
    // MARK: - Body
    // header ekle
    
    
    
    var body: some View {
        
       
       
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                customNavBar
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Cover Image Section
                        if !allImages.isEmpty {
                            coverImageSection
                                .frame(height: 300)
                                .padding(.bottom, 32)
                        }
                        
                        VStack(alignment: .leading, spacing: 24) {
                            // Title + Metadata
                            titleMetadataSection
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            // Main Content (Note/Description)
                            if bookmark.hasNote {
                                contentSection
                            }
                            
                            // URL Section
                            if bookmark.hasURL {
                                Divider()
                                    .padding(.vertical, 8)
                                linkSection
                            }
                            
                            // Tags
                            if bookmark.hasTags {
                                Divider()
                                    .padding(.vertical, 8)
                                tagsSection
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
                
                // Bottom Action Bar
                bottomActionBar
            }
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
    
    // MARK: - Custom Navigation
    
    private var customNavBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Back Button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                
                Spacer()
                
                // Source Badge
                HStack(spacing: 6) {
                    Text(bookmark.source.emoji)
                        .font(.system(size: 14))
                    Text(bookmark.source.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                
                Spacer()
                
                // Share Button
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .disabled(!bookmark.hasURL)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Cover Image Section
    
    private var coverImageSection: some View {
        ZStack {
            Color(.systemGray6)
            
            if let image = allImages.first {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            
            // Shadow overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .onTapGesture {
            if !allImages.isEmpty {
                showingFullScreenImage = true
            }
        }
    }
    
    // MARK: - Title & Metadata Section
    
    private var titleMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(bookmark.title)
                .font(.system(size: 24, weight: .bold, design: .default))
                .lineLimit(nil)
                .tracking(0.2)
            
            // Metadata Row
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Text(bookmark.source.emoji)
                    Text(bookmark.source.rawValue.capitalized)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                
                Text("•")
                    .foregroundStyle(.tertiary)
                
                Text(bookmark.relativeDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Spacer()
            }
            
            // Read Status Badge
            if bookmark.isRead {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
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
    }
    
    // MARK: - Content Section (Main Text)
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("İçerik")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(bookmark.note.split(separator: " ").count) kelime")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Text(bookmark.note)
                .font(.system(.body, design: .default))
                .lineSpacing(1.6)
                .tracking(0.2)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Link Section
    
    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kaynak")
                .font(.system(size: 16, weight: .semibold))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            
            if let urlString = bookmark.url, let url = URL(string: urlString) {
                VStack(spacing: 8) {
                    Link(destination: url) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(url.host ?? "Link")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Tarayıcıda Aç")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Button(action: {
                        UIPasteboard.general.string = urlString
                    }) {
                        HStack(spacing: 12) {
                            Text("URL'yi Kopyala")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Etiketler")
                .font(.system(size: 16, weight: .semibold))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(bookmark.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                Button(action: toggleReadStatus) {
                    VStack(spacing: 4) {
                        Image(systemName: bookmark.isRead ? "circle" : "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text(bookmark.isRead ? "Okunmadı" : "Okundu")
                            .font(.caption2)
                    }
                    .foregroundStyle(bookmark.isRead ? .orange : .green)
                    .frame(maxWidth: .infinity)
                }
                
                Divider()
                    .frame(height: 32)
                
                Button(action: { showingEditSheet = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18))
                        Text("Düzenle")
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                }
                
                Divider()
                    .frame(height: 32)
                
                Button(role: .destructive, action: { showingDeleteAlert = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                        Text("Sil")
                            .font(.caption2)
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .background(Color(.systemBackground))
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
}

// MARK: - Full Screen Image Gallery View

struct FullScreenImageGalleryView: View {
    let images: [UIImage]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
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
            
            VStack {
                HStack {
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
            withAnimation {
                scale = 1.0
                lastScale = 1.0
            }
        }
    }
}

// MARK: - Supporting Views

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
