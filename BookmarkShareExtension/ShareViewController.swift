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

// MARK: - SharedInboxPayload Model

struct SharedInboxPayload: Codable {
    let id: String
    let createdAt: Date
    var urls: [String]
    var texts: [String]
    var imageFileNames: [String]
    
    init(id: String = UUID().uuidString, createdAt: Date = Date(), urls: [String] = [], texts: [String] = [], imageFileNames: [String] = []) {
        self.id = id
        self.createdAt = createdAt
        self.urls = urls
        self.texts = texts
        self.imageFileNames = imageFileNames
    }
}

// MARK: - ShareViewController

/// Share Extension'ın entry point'i
/// Safari ve diğer uygulamalardan gelen URL, text ve image'ları alıp işler
class ShareViewController: UIViewController {
    
    // MARK: - Constants
    
    private let appGroupId = "group.com.unal.socialbookmark"
    private let inboxKey = "share_inbox_payloads"
    private let loadingTimeoutSeconds: TimeInterval = 15.0
    private let imageDirectory = "SharedImages"
    
    // MARK: - Properties
    
    private var hostingController: UIViewController?
    private var collectedURLs: Set<String> = []
    private var collectedTexts: [String] = []
    private var collectedImageFileNames: [String] = []
    
    /// ModelContainer - background'da oluşturulacak
    private var modelContainer: ModelContainer?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Temiz arka plan
        view.backgroundColor = .clear
        
        // Tüm ağır işleri background'da yap
        Task {
            // 1. Önce URL'i bulmaya çalış (en hızlısı)
            let payload = await collectPayloadSafe()
            
            // 2. URL bulunduysa UI'ı anında göster (ModelContainer henüz hazır değil)
            await showUIWithPayload(payload)
            
            // 3. Arka planda ModelContainer'ı oluştur
            let container = await createModelContainerAsync()
            
            await MainActor.run {
                self.modelContainer = container
                // Eğer UI açıksa repository'leri enjekte et
                if self.hostingController != nil, let payload = payload {
                    self.updateUIWithContainer(container, payload: payload)
                }
            }
        }
    }
    
    // MARK: - Loading View
    
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
    
    // MARK: - Show UI
    
    private func showUIWithPayload(_ payload: SharedInboxPayload?) async {
        guard let payload = payload else {
            await MainActor.run { close() }
            return
        }
        
        // URL bul
        var targetURL: URL?
        
        if let firstURL = payload.urls.first, let url = URL(string: firstURL) {
            targetURL = url
        } else if let text = payload.texts.first, let url = parseURL(from: text) {
            targetURL = url
        }
        
        if let url = targetURL {
            await MainActor.run {
                setupSwiftUIView(with: url, payload: payload)
            }
        } else {
            // URL yok, App Group'a kaydet ve kapat
            persistToAppGroup(payload: payload)
            await MainActor.run { close() }
        }
    }
    
    // MARK: - Collect Payload (Safe)
    
    private func collectPayloadSafe() async -> SharedInboxPayload? {
        do {
            return try await collectPayload()
        } catch {
            print("❌ Payload collection error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func collectPayload() async throws -> SharedInboxPayload {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            throw NSError(domain: "ShareExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: "No attachments"])
        }
        
        print("📱 Share Extension: \(attachments.count) attachment(s) found")
        
        // Paralel olarak tüm attachment'ları işle
        await withTaskGroup(of: Void.self) { group in
            for provider in attachments {
                group.addTask { [weak self] in
                    await self?.processAttachment(provider)
                }
            }
        }
        
        return SharedInboxPayload(
            urls: Array(collectedURLs),
            texts: collectedTexts,
            imageFileNames: collectedImageFileNames
        )
    }
    
    private func processAttachment(_ provider: NSItemProvider) async {
        // URL kontrolü (öncelikli - en hızlı)
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = await loadURL(from: provider) {
                collectedURLs.insert(url.absoluteString)
                print("   ✅ URL: \(url.absoluteString)")
                return // URL bulunca diğerlerini kontrol etme
            }
        }
        
        // Plain text kontrolü
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = await loadText(from: provider) {
                // URL içeriyor mu kontrol et
                if let extractedURL = parseURL(from: text) {
                    collectedURLs.insert(extractedURL.absoluteString)
                    print("   ✅ URL from text: \(extractedURL.absoluteString)")
                } else {
                    collectedTexts.append(text)
                    print("   ✅ Text: \(text.prefix(50))...")
                }
            }
        }
        
        // Image kontrolü (en yavaş - sona bırak)
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let fileName = await loadAndSaveImage(from: provider) {
                collectedImageFileNames.append(fileName)
                print("   ✅ Image saved: \(fileName)")
            }
        }
    }
    
    // MARK: - Load Helpers
    
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
            print("❌ Failed to save image: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Persist to App Group
    
    private func persistToAppGroup(payload: SharedInboxPayload) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            print("❌ Failed to access App Group UserDefaults")
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
            print("✅ Payload persisted to App Group (\(payloads.count) total)")
        }
    }
    
    // MARK: - Setup SwiftUI View
    
    private func setupSwiftUIView(with url: URL, payload: SharedInboxPayload? = nil) {
        print("🔧 Setting up SwiftUI view...")
        
        // Eski view'ları temizle
        view.subviews.forEach { $0.removeFromSuperview() }
        
        var bookmarkRepository: BookmarkRepositoryProtocol?
        var categoryRepository: CategoryRepositoryProtocol?
        
        if let container = modelContainer {
            bookmarkRepository = BookmarkRepository(modelContext: container.mainContext)
            categoryRepository = CategoryRepository(modelContext: container.mainContext)
        }
        
        let swiftUIView = ShareExtensionView(
            url: url,
            repository: bookmarkRepository,
            categoryRepository: categoryRepository,
            onSave: { [weak self] in
                if self?.modelContainer == nil, let payload = payload {
                    self?.persistToAppGroup(payload: payload)
                }
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        
        let hosting = UIHostingController(rootView: AnyView(swiftUIView))
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
        
        // Eğer container varsa bağla
        if let container = modelContainer {
            hosting.rootView = AnyView(swiftUIView.modelContainer(container))
        }
        
        print("✅ SwiftUI view setup complete")
    }
    
    private func updateUIWithContainer(_ container: ModelContainer?, payload: SharedInboxPayload) {
        guard let urlString = payload.urls.first, let url = URL(string: urlString) else { return }
        
        print("🔄 Updating UI with ModelContainer...")
        
        var bookmarkRepository: BookmarkRepositoryProtocol?
        var categoryRepository: CategoryRepositoryProtocol?
        
        if let container = container {
            bookmarkRepository = BookmarkRepository(modelContext: container.mainContext)
            categoryRepository = CategoryRepository(modelContext: container.mainContext)
        }
        
        let swiftUIView = ShareExtensionView(
            url: url,
            repository: bookmarkRepository,
            categoryRepository: categoryRepository,
            onSave: { [weak self] in
                if self?.modelContainer == nil {
                    self?.persistToAppGroup(payload: payload)
                }
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        
        if let hosting = hostingController as? UIHostingController<AnyView> {
            if let container = container {
                hosting.rootView = AnyView(swiftUIView.modelContainer(container))
            } else {
                hosting.rootView = AnyView(swiftUIView)
            }
        } else {
            // Re-setup if type mismatch
            setupSwiftUIView(with: url, payload: payload)
        }
    }
    
    // MARK: - Fallback Alert
    
    private func showFallbackAlert(url: URL) {
        let alert = UIAlertController(
            title: L("extension.fallback.title"),
            message: L("extension.fallback.message"),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: L("extension.fallback.ok"), style: .default) { [weak self] _ in
            self?.close()
        })
        
        present(alert, animated: true)
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
