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
    private let loadingTimeoutSeconds: TimeInterval = 10.0
    private let imageDirectory = "SharedImages"
    
    // MARK: - Properties
    
    private var hostingController: UIViewController?
    private var collectedURLs: Set<String> = []
    private var collectedTexts: [String] = []
    private var collectedImageFileNames: [String] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Task {
            do {
                let payload = try await collectPayload()
                persistToAppGroup(payload: payload)
                
                // URL varsa SwiftUI view'ı göster, yoksa direkt kapat
                if let firstURL = payload.urls.first, let url = URL(string: firstURL) {
                    await MainActor.run {
                        setupSwiftUIView(with: url, payload: payload)
                    }
                } else if !payload.texts.isEmpty || !payload.imageFileNames.isEmpty {
                    // Text veya image varsa da işle
                    await MainActor.run {
                        // URL yoksa placeholder URL ile aç veya direkt kaydet
                        if let text = payload.texts.first, let url = parseURL(from: text) {
                            setupSwiftUIView(with: url, payload: payload)
                        } else {
                            // Sadece text/image var, direkt kapat ve kaydet
                            close()
                        }
                    }
                } else {
                    await MainActor.run { close() }
                }
            } catch {
                print("❌ Share Extension error: \(error.localizedDescription)")
                await MainActor.run { close() }
            }
        }
        
        // Global timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + loadingTimeoutSeconds) { [weak self] in
            guard let self = self, self.hostingController == nil else { return }
            print("⚠️ Share Extension timeout")
            self.close()
        }
    }
    
    // MARK: - Collect Payload
    
    private func collectPayload() async throws -> SharedInboxPayload {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProviders = extensionItem.attachments,
              !itemProviders.isEmpty else {
            throw ShareError.noItems
        }
        
        print("📱 Share Extension: \(itemProviders.count) item provider(s) found")
        
        // Tüm provider'ları paralel olarak işle
        await withTaskGroup(of: Void.self) { group in
            for provider in itemProviders {
                group.addTask { [weak self] in
                    await self?.processItemProvider(provider)
                }
            }
        }
        
        // Payload oluştur
        let payload = SharedInboxPayload(
            urls: Array(collectedURLs),
            texts: collectedTexts,
            imageFileNames: collectedImageFileNames
        )
        
        print("✅ Payload collected: \(payload.urls.count) URLs, \(payload.texts.count) texts, \(payload.imageFileNames.count) images")
        
        return payload
    }
    
    // MARK: - Process Item Provider
    
    private func processItemProvider(_ provider: NSItemProvider) async {
        // 1. URL
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = await loadURL(from: provider) {
                let urlString = url.absoluteString
                if !urlString.isEmpty {
                    collectedURLs.insert(urlString)
                    print("✅ URL collected: \(urlString)")
                }
            }
        }
        
        // 2. Plain Text
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = await loadPlainText(from: provider) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    // Text içinde URL varsa onu da ekle
                    if let extractedURL = parseURL(from: trimmed) {
                        collectedURLs.insert(extractedURL.absoluteString)
                    }
                    // Text'i de ekle (duplicate değilse)
                    if !collectedTexts.contains(trimmed) {
                        collectedTexts.append(trimmed)
                        print("✅ Text collected: \(trimmed.prefix(50))...")
                    }
                }
            }
        }
        
        // 3. Image
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let fileName = await loadAndSaveImage(from: provider) {
                collectedImageFileNames.append(fileName)
                print("✅ Image saved: \(fileName)")
            }
        }
    }
    
    // MARK: - Load URL
    
    private func loadURL(from provider: NSItemProvider) async -> URL? {
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error = error {
                    print("⚠️ URL load error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Load Plain Text
    
    private func loadPlainText(from provider: NSItemProvider) async -> String? {
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                if let error = error {
                    print("⚠️ Text load error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
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
    
    // MARK: - Load and Save Image
    
    private func loadAndSaveImage(from provider: NSItemProvider) async -> String? {
        // Önce file representation dene (daha stabil)
        if let fileName = await loadImageViaFileRepresentation(from: provider) {
            return fileName
        }
        
        // Fallback: UIImage olarak yükle
        return await loadImageViaUIImage(from: provider)
    }
    
    private func loadImageViaFileRepresentation(from provider: NSItemProvider) async -> String? {
        return await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, error in
                guard let self = self, let url = url, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    let fileName = self.saveImageData(data, originalExtension: url.pathExtension)
                    continuation.resume(returning: fileName)
                } catch {
                    print("⚠️ Image file read error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func loadImageViaUIImage(from provider: NSItemProvider) async -> String? {
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { [weak self] item, error in
                guard let self = self, let image = item as? UIImage, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                if let data = image.jpegData(compressionQuality: 0.8) {
                    let fileName = self.saveImageData(data, originalExtension: "jpg")
                    continuation.resume(returning: fileName)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func saveImageData(_ data: Data, originalExtension: String) -> String? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            print("❌ App Group container not found")
            return nil
        }
        
        let imagesDir = containerURL.appendingPathComponent(imageDirectory)
        
        // Klasörü oluştur
        do {
            try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create images directory: \(error.localizedDescription)")
            return nil
        }
        
        // Dosya adı oluştur
        let ext = originalExtension.isEmpty ? "jpg" : originalExtension.lowercased()
        let fileName = "\(UUID().uuidString).\(ext)"
        let fileURL = imagesDir.appendingPathComponent(fileName)
        
        // Kaydet
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
        
        // Mevcut payloads'ı oku
        var payloads: [SharedInboxPayload] = []
        if let existingData = defaults.data(forKey: inboxKey) {
            do {
                payloads = try decoder.decode([SharedInboxPayload].self, from: existingData)
            } catch {
                print("⚠️ Failed to decode existing payloads: \(error.localizedDescription)")
            }
        }
        
        // Yeni payload'ı ekle
        payloads.append(payload)
        
        // Kaydet
        do {
            let data = try encoder.encode(payloads)
            defaults.set(data, forKey: inboxKey)
            defaults.synchronize()
            print("✅ Payload persisted to App Group (\(payloads.count) total)")
        } catch {
            print("❌ Failed to persist payload: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Setup SwiftUI View
    
    private func setupSwiftUIView(with url: URL, payload: SharedInboxPayload? = nil) {
        print("🔧 Setting up SwiftUI view...")
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            print("❌ App Group container bulunamadı")
            close()
            return
        }
        
        let storeURL = containerURL.appendingPathComponent("bookmark.sqlite")
        
        do {
            let configuration = ModelConfiguration(url: storeURL, allowsSave: true)
            let container = try ModelContainer(for: Bookmark.self, Category.self, configurations: configuration)
            
            print("✅ ModelContainer created successfully")
            
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
        } catch {
            print("❌ Extension container error: \(error)")
            close()
        }
    }
    
    // MARK: - Helpers
    
    private func parseURL(from text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.firstMatch(in: text, options: [], range: range),
              let urlRange = Range(match.range, in: text) else {
            return nil
        }
        return URL(string: String(text[urlRange]))
    }
    
    private func close() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    // MARK: - Error Types
    
    private enum ShareError: LocalizedError {
        case noItems
        case timeout
        case unknown(String)
        
        var errorDescription: String? {
            switch self {
            case .noItems: return "No items to share"
            case .timeout: return "Loading timeout"
            case .unknown(let msg): return msg
            }
        }
    }
}
