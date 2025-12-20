import SwiftUI

/// Bookmark detay ekranı - Kitap okuma uygulaması tarzı tasarım
struct BookmarkDetailView: View {
    // MARK: - Properties
    
    let bookmark: Bookmark
    
    @Environment(\.dismiss) private var dismiss

    
    @Bindable var viewModel: HomeViewModel
    
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
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Cover Image Section
                        if !allImages.isEmpty {
                            coverImageSection
                                .padding(.bottom, 24)
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
                repository: viewModel.bookmarkRepository, categoryRepository: viewModel.categoryRepository
            )
        }
        .alert("bookmarkDetail.delete_title", isPresented: $showingDeleteAlert) {
            Button("common.cancel", role: .cancel) {}
            Button("common.delete", role: .destructive)  {
                Task {
                       await deleteBookmark()
                   }
            }
        } message: {
            Text("bookmarkDetail.delete_confirmation")
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
        .navigationTitle(bookmark.source.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                }
                .disabled(!bookmark.hasURL)
            }
        }
    }
    
    // MARK: - Cover Image Section
    
    private var coverImageSection: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGray6)
            
            if allImages.count == 1 {
                // Tek görsel
                if let image = allImages.first {
                    Image(uiImage: image)
                        .resizable()
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipped()
                }
            } else {
                // Birden fazla görsel - Slider
                TabView(selection: $selectedImageIndex) {
                    ForEach(0..<allImages.count, id: \.self) { index in
                        Image(uiImage: allImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                            .clipped()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            
            // Shadow overlay for better readability
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.4)
                ]),
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            
            // Custom Page Indicator (birden fazla görsel varsa)
            if allImages.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<allImages.count, id: \.self) { index in
                        Circle()
                            .fill(selectedImageIndex == index ? Color.white : Color.white.opacity(0.5))
                            .frame(width: selectedImageIndex == index ? 8 : 6, height: selectedImageIndex == index ? 8 : 6)
                            .animation(.easeInOut(duration: 0.2), value: selectedImageIndex)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 12)
            }
        }
        .frame(height: 280)
        .clipped()
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
                    Text("bookmarkDetail.status.read")
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
                Text("bookmarkDetail.section.content")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("bookmarkDetail.word_count \(bookmark.note.split(separator: " ").count)")
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
            Text("bookmarkDetail.section.source")
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
                                Text("bookmarkDetail.openInBrowser")
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
                            Text("bookmarkDetail.copyUrl")
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
            Text("bookmarkDetail.section.tags")
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
                        Text(bookmark.isRead ? "bookmarkDetail.markUnread" : "bookmarkDetail.markRead")
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
                        Text("common.edit")
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
                        Text("common.delete")
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
            let repository = viewModel.bookmarkRepository
            repository.update(bookmark)
        }
    }
    
    private func deleteBookmark() async {
      await  viewModel.deleteBookmark(bookmark)
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
                        .scaledToFit()
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
