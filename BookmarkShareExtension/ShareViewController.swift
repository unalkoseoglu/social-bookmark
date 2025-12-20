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
    
    /// Lazy ModelContainer - sadece ihtiyaç olduğunda oluşturulur
    private lazy var modelContainer: ModelContainer? = {
        createModelContainer()
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hemen loading göster
        showLoadingView()
        
        // Arka planda işlemleri yap
        Task(priority: .userInitiated) {
            await processExtensionInput()
        }
        
        // Global timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + loadingTimeoutSeconds) { [weak self] in
            guard let self = self, self.hostingController == nil else { return }
            print("⚠️ Share Extension timeout")
            self.close()
        }
    }
    
    // MARK: - Loading View
    
    private func showLoadingView() {
        view.backgroundColor = .systemBackground
        
        let loadingView = UIActivityIndicatorView(style: .large)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.startAnimating()
        
        let label = UILabel()
        label.text = "Yükleniyor..."
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(loadingView)
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: loadingView.bottomAnchor, constant: 12)
        ])
    }
    
    // MARK: - Process Input
    
    private func processExtensionInput() async {
        do {
            let payload = try await collectPayload()
            
            // URL varsa SwiftUI view'ı göster
            if let firstURL = payload.urls.first, let url = URL(string: firstURL) {
                await MainActor.run {
                    setupSwiftUIView(with: url, payload: payload)
                }
            } else if let text = payload.texts.first, let url = parseURL(from: text) {
                await MainActor.run {
                    setupSwiftUIView(with: url, payload: payload)
                }
            } else {
                // URL yok, App Group'a kaydet ve kapat
                persistToAppGroup(payload: payload)
                await MainActor.run { close() }
            }
        } catch {
            print("❌ Share Extension error: \(error.localizedDescription)")
            await MainActor.run { close() }
        }
    }
    
    // MARK: - Model Container (Lazy)
    
    private func createModelContainer() -> ModelContainer? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            print("❌ App Group container bulunamadı")
            return nil
        }
        
        let storeURL = containerURL.appendingPathComponent("bookmark.sqlite")
        
        do {
            let configuration = ModelConfiguration(url: storeURL, allowsSave: true)
            let container = try ModelContainer(for: Bookmark.self, Category.self, configurations: configuration)
            print("✅ ModelContainer created")
            return container
        } catch {
            print("❌ ModelContainer error: \(error)")
            return nil
        }
    }
    
    // MARK: - Collect Payload
    
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
        // URL kontrolü
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = await loadURL(from: provider) {
                collectedURLs.insert(url.absoluteString)
                print("   ✅ URL: \(url.absoluteString)")
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
        
        // Image kontrolü
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
        
        // Loading view'ı temizle
        view.subviews.forEach { $0.removeFromSuperview() }
        
        guard let container = modelContainer else {
            print("❌ ModelContainer not available")
            // Fallback: App Group'a kaydet ve ana uygulamaya yönlendir
            if let payload = payload {
                persistToAppGroup(payload: payload)
            }
            showFallbackAlert(url: url)
            return
        }
        
        let bookmarkRepository = BookmarkRepository(modelContext: container.mainContext)
        let categoryRepository = CategoryRepository(modelContext: container.mainContext)
        
        print("📂 Categories loaded: \(categoryRepository.fetchAll().count)")
        
        let swiftUIView = ShareExtensionView(
            url: url,
            repository: bookmarkRepository,
            categoryRepository: categoryRepository,
            onSave: { [weak self] in
                print("💾 Bookmark saved from Share Extension")
                self?.close()
            },
            onCancel: { [weak self] in
                print("❌ Share Extension cancelled")
                self?.close()
            }
        )
        .modelContainer(container)
        
        let hosting = UIHostingController(rootView: swiftUIView)
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
        print("✅ SwiftUI view setup complete")
    }
    
    // MARK: - Fallback Alert
    
    private func showFallbackAlert(url: URL) {
        let alert = UIAlertController(
            title: "Bağlantı Kaydedildi",
            message: "Bu bağlantı ana uygulamada işlenecek.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Tamam", style: .default) { [weak self] _ in
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
