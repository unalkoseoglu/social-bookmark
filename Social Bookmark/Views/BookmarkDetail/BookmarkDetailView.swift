import SwiftUI

/// Bookmark detay ekranı - Reader Mode Tasarımı
struct BookmarkDetailView: View {
    // MARK: - Properties
    
    let bookmark: Bookmark
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    
    @Bindable var viewModel: HomeViewModel
    
    // Reader Settings
    @AppStorage("readerFont") private var selectedFont: ReaderFont = .serif
    @AppStorage("readerFontSize") private var fontSize: Double = 18
    @AppStorage("readerTheme") private var selectedTheme: ReaderTheme = .dark
    
    // UI State
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingFullScreenImage = false
    @State private var isAppearanceMenuPresented = false
    @State private var selectedImageIndex = 0
    @State private var loadedImages: [UIImage] = []
    @State private var isLoadingImages = false
    
    // Immersive Mode State
    @State private var isMenuVisible = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isCopied = false
    
    // MARK: - Computed Properties
    
    // Theme Resolvers
    private var currentBackgroundColor: Color {
        selectedTheme.backgroundColor
    }
    
    private var currentTextColor: Color {
        selectedTheme.textColor
    }
    
    private var currentSecondaryTextColor: Color {
        selectedTheme.secondaryTextColor
    }
    
    private var currentFontDesign: Font.Design {
        selectedFont.design
    }
    
    private var allImages: [UIImage] {
        let localImages = bookmark.allImagesData.compactMap { UIImage(data: $0) }
        if !localImages.isEmpty {
            return localImages
        }
        return loadedImages
    }
    
    private var hasImages: Bool {
        !allImages.isEmpty || isLoadingImages
    }
    
    private var wordCount: Int {
        bookmark.note.split(separator: " ").count
    }
    
    private var readingTime: String {
        let wpm = 200
        let minutes = max(1, wordCount / wpm)
        return "\(minutes) \(String(localized: "common.min_read"))"
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            currentBackgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Scrollable Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Cover Image (Hero)
                        if hasImages {
                            coverImageSection
                        }
                        
                        VStack(alignment: .leading, spacing: 24) {
                            // 2. Header (Title & Meta)
                            headerSection
                            
                            // 3. Tags
                            if bookmark.hasTags {
                                tagsSection
                            }
                            
                            Divider()
                                .overlay(currentSecondaryTextColor.opacity(0.2))
                            
                            // 4. Content Body
                            if bookmark.hasNote {
                                contentBodySection
                            } else {
                                emptyContentPlaceholder
                            }
                            
                            // 5. Source Link
                            if bookmark.hasURL {
                                sourceLinkCard
                            }
                            
                            // Bottom padding for scroll
                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, hasImages ? 24 : 16)
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: geo.frame(in: .named("scroll")).minY
                                )
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    handleScroll(offset: value)
                }
                
                // Sticky Action Bar
                stickyActionBar
                    .offset(y: isMenuVisible ? 0 : 200) // Hide by sliding down
                    .opacity(isMenuVisible ? 1 : 0)
            }
        }
        // edgesIgnoringSafeArea removed to respect Home Indicator
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isMenuVisible)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Appearance Menu
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { isAppearanceMenuPresented = true }) {
                    Image(systemName: "textformat.size")
                }
            }
            
            // Actions Menu
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label(String(localized: "common.edit"), systemImage: "pencil")
                    }
                    
                    Button(action: { showingShareSheet = true }) {
                        Label(String(localized: "bookmarkDetail.share"), systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label(String(localized: "common.delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        // Sheets & Alerts
        .toolbar(.hidden, for: .tabBar) // Hide TabBar to prevent overlap
        .sheet(isPresented: $isAppearanceMenuPresented) {
            AppearanceSettingsView()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditBookmarkView(
                bookmark: bookmark,
                repository: viewModel.bookmarkRepository,
                categoryRepository: viewModel.categoryRepository
            )
        }
        .alert(String(localized: "bookmarkDetail.delete_title"), isPresented: $showingDeleteAlert) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) {
                Task { await deleteBookmark() }
            }
        } message: {
            Text(String(localized: "bookmarkDetail.delete_confirmation"))
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = bookmark.url, let link = URL(string: url) {
                ShareSheet(items: [link])
            } else {
                ShareSheet(items: [bookmark.title, bookmark.note])
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            FullScreenImageGalleryView(
                images: allImages,
                selectedIndex: $selectedImageIndex
            )
        }
        .task {
            await loadImagesFromStorage()
        }
    }
    
    // MARK: - Sections
    
    private var coverImageSection: some View {
        TabView(selection: $selectedImageIndex) {
            if isLoadingImages {
                ZStack {
                    Color(.systemGray6)
                    ProgressView()
                }
                .frame(height: 300)
                .tag(0)
            } else {
                ForEach(0..<allImages.count, id: \.self) { index in
                    Image(uiImage: allImages[index])
                        .resizable()
                        .scaledToFill()
                        .frame(height: 300)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingFullScreenImage = true
                        }
                        .tag(index)
                }
            }
        }
        .tabViewStyle(.page)
        .frame(height: 300)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Meta Row: Source | Date
            HStack(spacing: 8) {
                Label {
                    Text(bookmark.source.displayName)
                        .font(.custom("System", size: 14).weight(.medium)) // Fixed size for meta
                        .fontWeight(.medium)
                } icon: {
                    Text(bookmark.source.emoji)
                }
                .foregroundStyle(currentSecondaryTextColor)
                
                Text("•")
                    .foregroundStyle(currentSecondaryTextColor.opacity(0.6))
                
                Text(bookmark.relativeDate)
                    .font(.custom("System", size: 14))
                    .foregroundStyle(currentSecondaryTextColor)
            }
            .fontDesign(currentFontDesign)
            
            // Title
            Text(bookmark.title)
                .font(.system(size: fontSize * 1.5, weight: .bold, design: currentFontDesign))
                .lineSpacing(4)
                .foregroundStyle(currentTextColor)
            
            // Reading stats
            if bookmark.hasNote {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(readingTime)
                    
                    Text("•")
                        .padding(.horizontal, 4)
                    
                    Image(systemName: "text.alignleft")
                    Text("\(wordCount) \(String(localized: "common.words"))")
                }
                .font(.caption)
                .foregroundStyle(currentSecondaryTextColor)
                .textCase(.uppercase)
                .fontDesign(currentFontDesign)
            }
        }
    }
    
    private var tagsSection: some View {
        FlowLayout(spacing: 8) {
            ForEach(bookmark.tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(currentSecondaryTextColor.opacity(0.1))
                    .foregroundStyle(currentSecondaryTextColor)
                    .clipShape(Capsule())
            }
        }
    }
    
    private var contentBodySection: some View {
        Text(bookmark.note)
            .font(.system(size: fontSize, weight: .regular, design: currentFontDesign))
            .lineSpacing(fontSize * 0.6) // Dynamic line spacing based on font size
            .foregroundStyle(currentTextColor)
            .textSelection(.enabled)
    }
    
    private var emptyContentPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "text.justify.left")
                    .font(.largeTitle)
                    .foregroundStyle(currentSecondaryTextColor.opacity(0.3))
                Text(String(localized: "bookmark.no_content"))
                    .font(.body)
                    .foregroundStyle(currentSecondaryTextColor)
            }
            Spacer()
        }
        .padding(.vertical, 40)
    }
    
    private var sourceLinkCard: some View {
        Button {
            if let urlString = bookmark.url, let url = URL(string: urlString) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(selectedTheme.accentColor.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "link")
                        .font(.headline)
                        .foregroundStyle(selectedTheme.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "bookmarkDetail.openInBrowser"))
                        .font(.headline)
                        .foregroundStyle(currentTextColor)
                    
                    if let url = bookmark.url {
                        Text(url)
                            .font(.caption)
                            .foregroundStyle(currentSecondaryTextColor)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.subheadline)
                    .foregroundStyle(currentSecondaryTextColor)
            }
            .padding(16)
            .background(currentSecondaryTextColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Sticky Action Bar
    
    private var stickyActionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(currentSecondaryTextColor.opacity(0.2))
            
            HStack {
                // Read/Unread Toggle
                Button(action: toggleReadStatus) {
                    HStack(spacing: 8) {
                        Image(systemName: bookmark.isRead ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                        Text(bookmark.isRead ? String(localized: "bookmarkDetail.status.read") : String(localized: "bookmarkDetail.markRead"))
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(bookmark.isRead ? .green : currentTextColor)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(bookmark.isRead ? Color.green.opacity(0.1) : currentSecondaryTextColor.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // Favorite Toggle
                Button(action: toggleFavorite) {
                    Image(systemName: bookmark.isFavorite ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(bookmark.isFavorite ? .yellow : currentSecondaryTextColor)
                        .frame(width: 44, height: 44)
                        .background(currentSecondaryTextColor.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Copy Button
                Button(action: copyContent) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.title3)
                        .foregroundStyle(isCopied ? .green : currentSecondaryTextColor)
                        .frame(width: 44, height: 44)
                        .background(currentSecondaryTextColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .sensoryFeedback(.success, trigger: isCopied)
                
                // Share
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .background(currentSecondaryTextColor.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            // Removed hardcoded bottom padding 32, system will handle it
            .background(selectedTheme == .light ? .regularMaterial : .thickMaterial)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4)
        }
    }
    
    // MARK: - Logic
    
    private func handleScroll(offset: CGFloat) {
        // Detect scroll direction
        let diff = offset - lastScrollOffset
        
        // Tolerance for small movements
        if abs(diff) < 10 { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if diff < 0 && offset < -50 {
                // Scrolling down -> Hide menu
                isMenuVisible = false
            } else if diff > 0 {
                // Scrolling up -> Show menu
                isMenuVisible = true
            }
        }
        
        lastScrollOffset = offset
        scrollOffset = offset
    }
    
    private func copyContent() {
        let textToCopy = bookmark.note.isEmpty ? bookmark.title : bookmark.note
        UIPasteboard.general.string = textToCopy
        
        withAnimation {
            isCopied = true
        }
        
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
    
    private func toggleReadStatus() {
        withAnimation {
            viewModel.toggleReadStatus(bookmark)
        }
    }
    
    private func toggleFavorite() {
        withAnimation {
            viewModel.toggleFavorite(bookmark)
        }
    }
    
    private func deleteBookmark() async {
        viewModel.deleteBookmark(bookmark)
        dismiss()
    }
    
    private func loadImagesFromStorage() async {
        guard bookmark.allImagesData.isEmpty,
              let imageUrls = bookmark.imageUrls, !imageUrls.isEmpty else { return }
        
        await MainActor.run { isLoadingImages = true }
        
        var images: [UIImage] = []
        for path in imageUrls {
            if let image = await ImageUploadService.shared.loadImage(from: path) {
                images.append(image)
            }
        }
        
        await MainActor.run {
            loadedImages = images
            isLoadingImages = false
        }
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

// MARK: - Preference Keys

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
