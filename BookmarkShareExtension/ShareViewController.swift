//
//  ShareViewController.swift
//  BookmarkShareExtension
//
//  Optimize edilmiş versiyon - Daha hızlı başlatma
//

import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Combine

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            VStack(spacing: 16) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.blue)
                
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Hazırlanıyor...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - ShareViewController

/// Share Extension'ın entry point'i
/// Safari ve diğer uygulamalardan gelen URL, text ve image'ları alıp işler

class ShareViewController: UIViewController {
    
    // MARK: - Constants
    
    private let appGroupId = APIConstants.appGroupId
    private let inboxKey = "share_inbox_payloads"
    private let extensionTimeoutSeconds: TimeInterval = 5.0
    private let imageDirectory = "SharedImages"
    
    // MARK: - Properties
    
    private var hostingController: UIViewController?
    private var modelContainer: ModelContainer?
    private let extensionState = ShareExtensionState()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Show loading view immediately
        showInitialLoadingView()
        
        // 2. Safety timeout - prevent watchdog kills
        let timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(5.0 * 1_000_000_000))
            guard let self = self, !self.extensionState.isReady else { return }
            print("⏰ [Share] Timeout reached, showing UI with available data")
        }
        
        Task {
            // 3. Collect payload (fast, no network)
            async let payload = collectPayloadSafe()
            
            // 4. Start SessionStore init in background (no auth listener in extension)
            async let sessionInit: () = SessionStore.shared.initializeOnce()
            
            // 5. Start ModelContainer in background
            let containerTask = Task.detached(priority: .userInitiated) {
                await self.createModelContainerAsync()
            }
            
            // 6. Wait for payload FIRST (this is the fastest)
            guard let collectedPayload = await payload else {
                print("❌ [Share] No payload found, closing")
                timeoutTask.cancel()
                close()
                return
            }
            
            // 7. Show UI immediately with payload (no repos yet)
            await MainActor.run {
                self.setupSwiftUIView(with: collectedPayload)
            }
            
            // 8. Wait for SessionStore and ModelContainer in background
            await sessionInit
            let container = await containerTask.value
            timeoutTask.cancel()
            
            // 9. Inject repositories via shared state (no view recreation)
            await MainActor.run {
                self.modelContainer = container
                self.injectRepositories(container: container)
            }
        }
    }
    
    private func showInitialLoadingView() {
        let loadingView = UIHostingController(rootView: LoadingView())
        addChild(loadingView)
        view.addSubview(loadingView.view)
        loadingView.view.frame = view.bounds
        loadingView.didMove(toParent: self)
        self.hostingController = loadingView
    }
    
    // MARK: - UI Logic
    
    /// Inject repositories into the shared state object (no view recreation needed)
    private func injectRepositories(container: ModelContainer?) {
        print("🔄 [Share] Injecting repositories (Container: \(container != nil))")
        
        let (bookmarkRepo, categoryRepo) = createRepositories(with: container)
        extensionState.repository = bookmarkRepo
        extensionState.categoryRepository = categoryRepo
        extensionState.isReady = true
        
        print("✅ [Share] Repositories injected successfully")
    }
    
    private func createRepositories(with container: ModelContainer?) -> (BookmarkRepositoryProtocol?, CategoryRepositoryProtocol?) {
        guard let container = container else { return (nil, nil) }
        
        let baseBookmarkRepo = BookmarkRepository(modelContext: container.mainContext)
        let baseCategoryRepo = CategoryRepository(modelContext: container.mainContext)
        
        return (
            SyncableBookmarkRepository(baseRepository: baseBookmarkRepo),
            SyncableCategoryRepository(baseRepository: baseCategoryRepo)
        )
    }
    
    // MARK: - Legacy Loading View
    
    private var hintLabel: UILabel?
    
    private func showLoadingView() {
        view.backgroundColor = .systemBackground
        
        // İlk açılış mı kontrol et
        let isFirstLaunch = !UserDefaults(suiteName: appGroupId)!.bool(forKey: "extension_launched_before")
        
        // İlk açılışta üstte banner göster
        if isFirstLaunch {
            showFirstLaunchBanner()
        }
        
        // Container view
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 16
        view.addSubview(containerView)
        
        // App icon
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = UIImage(systemName: "bookmark.fill")
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        containerView.addSubview(iconImageView)
        
        // Loading spinner
        let loadingView = UIActivityIndicatorView(style: .medium)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.startAnimating()
        loadingView.color = .secondaryLabel
        containerView.addSubview(loadingView)
        
        // Label
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("extension.loading")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        containerView.addSubview(label)
        
        // Hint label (ilk açılış için)
        let hint = UILabel()
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.text = L("extension.loading.hint")
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .tertiaryLabel
        hint.textAlignment = .center
        hint.numberOfLines = 0
        hint.alpha = 0
        containerView.addSubview(hint)
        self.hintLabel = hint
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 200),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
            
            // Icon
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            // Spinner
            loadingView.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            loadingView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            // Label
            label.topAnchor.constraint(equalTo: loadingView.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Hint
            hint.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            hint.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            hint.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        
        // 2 saniye sonra hint göster (ilk açılış yavaşsa)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            UIView.animate(withDuration: 0.3) {
                self?.hintLabel?.alpha = 1
            }
        }
    }
    
    // MARK: - First Launch Banner
    
    private func showFirstLaunchBanner() {
        let bannerView = UIView()
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.95)
        bannerView.layer.cornerRadius = 12
        bannerView.layer.shadowColor = UIColor.black.cgColor
        bannerView.layer.shadowOpacity = 0.15
        bannerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        bannerView.layer.shadowRadius = 8
        bannerView.tag = 888
        view.addSubview(bannerView)
        
        // Icon
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "info.circle.fill")
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        bannerView.addSubview(iconView)
        
        // Message
        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = L("extension.firstLaunch.message")
        messageLabel.font = .systemFont(ofSize: 13, weight: .medium)
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 2
        bannerView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bannerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            iconView.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: bannerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            messageLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -12),
            messageLabel.topAnchor.constraint(equalTo: bannerView.topAnchor, constant: 12),
            messageLabel.bottomAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: -12)
        ])
        
        // Animate in
        bannerView.alpha = 0
        bannerView.transform = CGAffineTransform(translationX: 0, y: -20)
        
        UIView.animate(withDuration: 0.4, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            bannerView.alpha = 1
            bannerView.transform = .identity
        }
        
        // 5 saniye sonra kaybol
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            UIView.animate(withDuration: 0.3) {
                bannerView.alpha = 0
                bannerView.transform = CGAffineTransform(translationX: 0, y: -20)
            } completion: { _ in
                bannerView.removeFromSuperview()
            }
        }
        
        // İlk açılış flag'ini kaydet
        UserDefaults(suiteName: appGroupId)?.set(true, forKey: "extension_launched_before")
    }
    
    // MARK: - Model Container (Async)
    
    private func createModelContainerAsync() async -> ModelContainer? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            print("❌ App Group container bulunamadı")
            return nil
        }
        
        let storeURL = containerURL.appendingPathComponent("bookmark.sqlite")
        
        do {
            let configuration = ModelConfiguration(url: storeURL, allowsSave: true)
            let container = try ModelContainer(for: Bookmark.self, Category.self, configurations: configuration)
            print("✅ ModelContainer created (background)")
            return container
        } catch {
            print("❌ ModelContainer error: \(error)")
            return nil
        }
    }
    
    // MARK: - Legacy Show UI (REMOVED)
    
    // MARK: - Collect Payload (Safe)
    
    private func collectPayloadSafe() async -> SharedInboxPayload? {
        do {
            return try await collectPayload()
        } catch {
            print("❌ [Share] Payload collection error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func collectPayload() async throws -> SharedInboxPayload {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            throw NSError(domain: "ShareExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: "No attachments"])
        }
        
        print("📱 [Share] \(attachments.count) attachment(s) found")
        
        // Use structured concurrency to collect results without data races
        return await withTaskGroup(of: AttachmentResult.self) { group in
            for provider in attachments {
                group.addTask {
                    await self.processAttachmentSafe(provider)
                }
            }
            
            var urls: Set<String> = []
            var texts: [String] = []
            var imageFileNames: [String] = []
            
            for await result in group {
                switch result {
                case .url(let url):
                    urls.insert(url)
                case .text(let text):
                    texts.append(text)
                case .image(let fileName):
                    imageFileNames.append(fileName)
                case .none:
                    break
                }
            }
            
            return SharedInboxPayload(
                urls: Array(urls),
                texts: texts,
                imageFileNames: imageFileNames
            )
        }
    }
    
    private enum AttachmentResult {
        case url(String)
        case text(String)
        case image(String)
        case none
    }
    
    private func processAttachmentSafe(_ provider: NSItemProvider) async -> AttachmentResult {
        // URL kontrolü (öncelikli - en hızlı)
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = await loadURL(from: provider) {
                print("   ✅ [Share] URL: \(url.absoluteString)")
                return .url(url.absoluteString)
            }
        }
        
        // Plain text kontrolü
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = await loadText(from: provider) {
                // URL içeriyor mu kontrol et
                if let extractedURL = parseURL(from: text) {
                    print("   ✅ [Share] URL from text: \(extractedURL.absoluteString)")
                    return .url(extractedURL.absoluteString)
                } else {
                    print("   ✅ [Share] Text: \(text.prefix(50))...")
                    return .text(text)
                }
            }
        }
        
        // Image kontrolü (en yavaş - sona bırak)
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let fileName = await loadAndSaveImage(from: provider) {
                print("   ✅ [Share] Image saved: \(fileName)")
                return .image(fileName)
            }
        }
        
        return .none
    }
    
    // MARK: - Load Helpers
    // (Existing loadURL, loadText, loadAndSaveImage remain same)
    
    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func loadAndSaveImage(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, error in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var imageData: Data?
                var originalExtension = "jpg"
                
                if let url = item as? URL {
                    imageData = try? Data(contentsOf: url)
                    originalExtension = url.pathExtension
                } else if let image = item as? UIImage {
                    imageData = image.jpegData(compressionQuality: 0.8)
                } else if let data = item as? Data {
                    imageData = data
                }
                
                if let data = imageData {
                    let fileName = self.saveImageToAppGroup(data: data, originalExtension: originalExtension)
                    continuation.resume(returning: fileName)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func saveImageToAppGroup(data: Data, originalExtension: String) -> String? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        
        let imagesDir = containerURL.appendingPathComponent(imageDirectory)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        
        let ext = originalExtension.isEmpty ? "jpg" : originalExtension.lowercased()
        let fileName = "\(UUID().uuidString).\(ext)"
        let fileURL = imagesDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("❌ [Share] Failed to save image: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Persist to App Group
    
    private func persistToAppGroup(payload: SharedInboxPayload) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            print("❌ [Share] Failed to access App Group UserDefaults")
            return
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var payloads: [SharedInboxPayload] = []
        if let existingData = defaults.data(forKey: inboxKey) {
            payloads = (try? decoder.decode([SharedInboxPayload].self, from: existingData)) ?? []
        }
        
        payloads.append(payload)
        
        if let data = try? encoder.encode(payloads) {
            defaults.set(data, forKey: inboxKey)
            defaults.synchronize()
            print("✅ [Share] Payload persisted to App Group (\(payloads.count) total)")
        }
    }
    
    // MARK: - Setup SwiftUI View
    
    private func setupSwiftUIView(with payload: SharedInboxPayload) {
        print("🔧 [Share] Setting up SwiftUI view...")
        
        // Eski view'ları temizle
        view.subviews.forEach { $0.removeFromSuperview() }
        children.forEach { $0.removeFromParent() }
        
        let urlString = payload.urls.first ?? payload.texts.first ?? ""
        guard let url = URL(string: urlString) ?? parseURL(from: urlString) else {
            close()
            return
        }
        
        let swiftUIView = ShareExtensionView(
            url: url,
            extensionState: extensionState,
            onSave: { [weak self] in
                if self?.extensionState.repository == nil {
                    self?.persistToAppGroup(payload: payload)
                }
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        
        let hosting = UIHostingController(rootView: AnyView(
            swiftUIView
                .environmentObject(SessionStore.shared)
        ))
        self.hostingController = hosting
        
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        hosting.didMove(toParent: self)
    }
    
    // MARK: - Helpers
    
    private func parseURL(from text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        
        return matches.first?.url
    }
    
    private func close() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
