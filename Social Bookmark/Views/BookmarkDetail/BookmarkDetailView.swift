import SwiftUI
import QuickLook

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
    @AppStorage("readerFontSize") private var fontSize: Double = 14
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
    
    // Document State
    @State private var signedURL: URL?
    @State private var isLoadingDocument = false
    @State private var showingQuickLook = false
    
    // Immersive Mode State
    @State private var isMenuVisible = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isCopied = false
    
    // Linking State
    @State private var showingLinkSheet = false
    @State private var selectedLinkedBookmark: Bookmark?
    
    // Readability State
    @State private var isFocusMode = false
    @State private var contentHeight: CGFloat = 0
    @State private var viewHeight: CGFloat = 0
    @State private var aiSummary: String? = nil
    @State private var isSummarizing = false
    
    private var readingProgress: Double {
        let diff = contentHeight - viewHeight
        guard diff > 0 else { return 0 }
        let progress = -scrollOffset / diff
        return min(max(progress, 0), 1)
    }
    
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
        
        // Eğer cloud'dan daha fazla/güncel görsel geldiyse onu tercih et
        if !loadedImages.isEmpty && (loadedImages.count > localImages.count) {
            return loadedImages
        }
        
        return localImages.isEmpty ? loadedImages : localImages
    }
    
    private var hasImages: Bool {
        !bookmark.allImagesData.isEmpty || !(bookmark.imageUrls?.isEmpty ?? true)
    }
    
    private var wordCount: Int {
        bookmark.note.split(separator: " ").count
    }
    
    private var readingTime: String {
        let wpm = 200
        let minutes = max(1, wordCount / wpm)
        return LanguageManager.shared.localized("common.min_read %lld", Int64(minutes))
    }
    
    private var currentUIFont: UIFont {
        let size = CGFloat(fontSize)
        let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
        let design: UIFontDescriptor.SystemDesign = {
            switch selectedFont {
            case .system: return .default
            case .serif: return .serif
            case .mono: return .monospaced
            case .rounded: return .rounded
            }
        }()
        
        if let designDescriptor = descriptor.withDesign(design) {
            return UIFont(descriptor: designDescriptor, size: size)
        }
        return UIFont.systemFont(ofSize: size)
    }
    
    private var titleUIFont: UIFont {
        let size = CGFloat(fontSize * 1.5)
        let descriptor = UIFont.systemFont(ofSize: size, weight: .bold).fontDescriptor
        let design: UIFontDescriptor.SystemDesign = {
            switch selectedFont {
            case .system: return .default
            case .serif: return .serif
            case .mono: return .monospaced
            case .rounded: return .rounded
            }
        }()
        
        if let designDescriptor = descriptor.withDesign(design) {
            return UIFont(descriptor: designDescriptor, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: .bold)
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
                        if !allImages.isEmpty && !isFocusMode {
                            coverImageSection
                        }
                        
                        VStack(alignment: .leading, spacing: 24) {
                            // 2. Header (Title & Meta)
                            if !isFocusMode {
                                headerSection
                            }
                            
                            // 3. Tags
                            if bookmark.hasTags && !isFocusMode {
                                tagsSection
                            }
                            
                            Divider()
                                .overlay(currentSecondaryTextColor.opacity(0.2))
                            
                            // 5. Content Body
                            if bookmark.hasNote {
                                contentBodySection
                            } else {
                                emptyContentPlaceholder
                            }
                            
                            // 5. Document Preview
                            if bookmark.hasFile && !isFocusMode {
                                documentPreviewSection
                            }
                            
                            // 6. Source Link
                            if bookmark.hasURL && !isFocusMode {
                                sourceLinkCard
                            }
                            
                            // 7. Linked Bookmarks
                            if !isFocusMode {
                                LinkedBookmarksSection(
                                    linkedBookmarkIds: bookmark.linkedBookmarkIds ?? [],
                                    onBookmarkSelected: { linkedBookmark in
                                        // Use hidden navigation trigger
                                        navigateToBookmark(linkedBookmark)
                                    },
                                    onAddLink: {
                                        showingLinkSheet = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, allImages.isEmpty ? 16 : 24)
                        .padding(.bottom, 16)
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { contentHeight = geo.size.height }
                                .onChange(of: geo.size.height) { _, newValue in contentHeight = newValue }
                        }
                    )
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
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { viewHeight = geo.size.height }
                    }
                )
                
                if isMenuVisible {
                    // Sticky Action Bar
                    stickyActionBar
                }
            }
            
            // Reading Progress Bar
            VStack {
                Rectangle()
                    .fill(selectedTheme.accentColor)
                    .frame(width: UIScreen.main.bounds.width * readingProgress, height: 3)
                    .animation(.linear, value: readingProgress)
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedLinkedBookmark) { bookmark in
            BookmarkDetailView(bookmark: bookmark, viewModel: viewModel)
        }
        .toolbar {
            // Focus Mode Toggle
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    withAnimation { isFocusMode.toggle() }
                    if isFocusMode { isMenuVisible = false } else { isMenuVisible = true }
                }) {
                    Image(systemName: isFocusMode ? "eye.fill" : "eye.slash")
                        .foregroundStyle(isFocusMode ? selectedTheme.accentColor : currentSecondaryTextColor)
                }
            }
            
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
                        Label(LanguageManager.shared.localized("common.edit"), systemImage: "pencil")
                    }
                    
                    Button(action: { showingShareSheet = true }) {
                        Label(LanguageManager.shared.localized("bookmarkDetail.share"), systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label(LanguageManager.shared.localized("common.delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
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
        .alert(LanguageManager.shared.localized("bookmarkDetail.delete_title"), isPresented: $showingDeleteAlert) {
            Button(LanguageManager.shared.localized("common.cancel"), role: .cancel) {}
            Button(LanguageManager.shared.localized("common.delete"), role: .destructive) {
                Task { await deleteBookmark() }
            }
        } message: {
            Text(LanguageManager.shared.localized("bookmarkDetail.delete_confirmation"))
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [
                bookmark.title,
                bookmark.note,
                URL(string: bookmark.url ?? "") as Any
            ].compactMap { $0 })
        }
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            FullScreenImageGalleryView(
                images: allImages,
                selectedIndex: $selectedImageIndex
            )
        }
        .sheet(isPresented: $showingLinkSheet) {
            BookmarkSelectionSheet(
                currentBookmark: bookmark,
                selectedBookmarkIds: Binding(
                    get: { bookmark.linkedBookmarkIds ?? [] },
                    set: { newIds in
                        bookmark.linkedBookmarkIds = newIds
                        // Trigger save if needed (SwiftData autosaves usually)
                    }
                )
            )
        }
        .task {
            await loadImagesFromStorage()
            if bookmark.hasFile {
                await loadSignedURL()
            }
        }
        .quickLookPreview($signedURL)
    }
    
    // MARK: - Sections
    
    private var coverImageSection: some View {
        TabView(selection: $selectedImageIndex) {
            if isLoadingImages && loadedImages.isEmpty {
                ZStack {
                    Color(.systemGray6)
                    ProgressView()
                }
                .frame(height: 300)
                .tag(0)
            } else if !allImages.isEmpty {
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
            HStack(spacing: 8) {
                Label {
                    Text(bookmark.source.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .fontWeight(.medium)
                } icon: {
                    Text(bookmark.source.emoji)
                }
                .foregroundStyle(currentSecondaryTextColor)
                
                Text("•")
                    .foregroundStyle(currentSecondaryTextColor.opacity(0.6))
                
                Text(bookmark.relativeDate)
                    .font(.system(size: 14))
                    .foregroundStyle(currentSecondaryTextColor)
            }
            .fontDesign(currentFontDesign)
            
            SelectableTextView(
                text: bookmark.title,
                font: titleUIFont,
                color: UIColor(currentTextColor),
                lineSpacing: 4
            )
            
            if bookmark.hasNote {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(readingTime)
                    
                    Text("•")
                        .padding(.horizontal, 4)
                    
                    Image(systemName: "text.alignleft")
                    Text(LanguageManager.shared.localized("common.words_count %lld", Int64(wordCount)))
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
    
    private var aiSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = aiSummary {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(LanguageManager.shared.localized("bookmarkDetail.summary_title"), systemImage: "sparkles")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.purple)
                        
                        Spacer()
                        
                        Button {
                            aiSummary = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(currentSecondaryTextColor.opacity(0.3))
                        }
                    }
                    
                    Text(summary)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(currentTextColor)
                        .lineSpacing(4)
                }
                .padding(16)
                .background(Color.purple.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                )
            } else {
                Button(action: generateAISummary) {
                    HStack {
                        if isSummarizing {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text(LanguageManager.shared.localized("common.loading"))
                        } else {
                            Image(systemName: "sparkles")
                            Text(LanguageManager.shared.localized("bookmarkDetail.summarize"))
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.purple)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Capsule())
                }
                .disabled(isSummarizing)
            }
        }
    }
    
    private var contentBodySection: some View {
        SelectableTextView(
            text: bookmark.note,
            font: currentUIFont,
            color: UIColor(currentTextColor),
            lineSpacing: fontSize * 0.4
        )
    }
    
    
    private var emptyContentPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "text.justify.left")
                    .font(.largeTitle)
                    .foregroundStyle(currentSecondaryTextColor.opacity(0.3))
                Text(LanguageManager.shared.localized("bookmark.no_content"))
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
                    Text(LanguageManager.shared.localized("bookmarkDetail.openInBrowser"))
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
    
    private var documentPreviewSection: some View {
        Button {
            if let _ = signedURL {
                showingQuickLook = true
            } else {
                Task {
                    await loadSignedURL()
                    if signedURL != nil {
                        showingQuickLook = true
                    }
                }
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.emerald.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    if isLoadingDocument {
                        ProgressView()
                    } else {
                        Image(systemName: bookmark.fileExtension == "pdf" ? "doc.richtext.fill" : "doc.fill")
                            .font(.headline)
                            .foregroundStyle(Color.emerald)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bookmark.fileName ?? LanguageManager.shared.localized("bookmarkDetail.document"))
                        .font(.headline)
                        .foregroundStyle(currentTextColor)
                        .lineLimit(1)
                    
                    if let size = bookmark.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(currentSecondaryTextColor)
                    } else {
                        Text(LanguageManager.shared.localized("bookmarkDetail.openDocument"))
                            .font(.caption)
                            .foregroundStyle(currentSecondaryTextColor)
                    }
                }
                
                Spacer()
                
                Image(systemName: "hand.tap")
                    .font(.subheadline)
                    .foregroundStyle(currentSecondaryTextColor)
            }
            .padding(16)
            .background(Color.emerald.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.emerald.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Sticky Action Bar
    
    private var stickyActionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(currentSecondaryTextColor.opacity(0.2))
            
            HStack {
                Button(action: toggleReadStatus) {
                    HStack(spacing: 8) {
                        Image(systemName: bookmark.isRead ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                        Text(bookmark.isRead ? LanguageManager.shared.localized("bookmarkDetail.status.read") : LanguageManager.shared.localized("bookmarkDetail.markRead"))
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(bookmark.isRead ? .green : currentTextColor)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(bookmark.isRead ? Color.green.opacity(0.1) : currentSecondaryTextColor.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                Button(action: toggleFavorite) {
                    Image(systemName: bookmark.isFavorite ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(bookmark.isFavorite ? .yellow : currentSecondaryTextColor)
                        .frame(width: 44, height: 44)
                        .background(currentSecondaryTextColor.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Button(action: copyContent) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.title3)
                        .foregroundStyle(isCopied ? .green : currentSecondaryTextColor)
                        .frame(width: 44, height: 44)
                        .background(currentSecondaryTextColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .sensoryFeedback(.success, trigger: isCopied)
                
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
            .background(selectedTheme == .light ? .regularMaterial : .thickMaterial)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4)
        }
    }
    
    // MARK: - Logic
    
    private func handleScroll(offset: CGFloat) {
        let diff = offset - lastScrollOffset
        
        if abs(diff) < 10 { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if diff < 0 && offset < -50 {
                isMenuVisible = false
            } else if diff > 0 {
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
    
    private func navigateToBookmark(_ bookmark: Bookmark) {
        selectedLinkedBookmark = bookmark
    }
    
    private func deleteBookmark() async {
        viewModel.deleteBookmark(bookmark)
        dismiss()
    }
    
    private func generateAISummary() {
        isSummarizing = true
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                let summary = LanguageManager.shared.localized("bookmarkDetail.summary_mock %@", bookmark.title)
                
                withAnimation {
                    self.aiSummary = summary
                    self.isSummarizing = false
                }
            }
        }
    }
    
    private func loadImagesFromStorage() async {
        guard let imageUrls = bookmark.imageUrls, !imageUrls.isEmpty else { return }
        
        // Eğer yerel görseller eksikse veya hiç yoksa buluttan çek
        let localCount = bookmark.allImagesData.count
        guard localCount < imageUrls.count else { return }
        
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
    
    private func loadSignedURL() async {
        guard let path = bookmark.fileURL else { return }
        
        await MainActor.run { isLoadingDocument = true }
        
        if let url = await DocumentUploadService.shared.getSignedURL(for: path) {
            await MainActor.run {
                self.signedURL = url
                self.isLoadingDocument = false
            }
        } else {
            await MainActor.run { isLoadingDocument = false }
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


