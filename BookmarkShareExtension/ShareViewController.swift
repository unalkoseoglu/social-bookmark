import UIKit
import SwiftUI
import Social
import SwiftData
import UniformTypeIdentifiers

/// Share Extension'ın entry point'i
/// Safari'den gelen URL'i alıp SwiftUI view'a geçirir
class ShareViewController: UIViewController {
    // MARK: - Properties
    
    private var hostingController: UIViewController?
    private let loadingTimeoutSeconds: TimeInterval = 8.0
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Timeout'u ayarla
        DispatchQueue.main.asyncAfter(deadline: .now() + loadingTimeoutSeconds) { [weak self] in
            guard let self = self, self.hostingController == nil else { return }
            print("⚠️ Share Extension URL loading timeout")
            self.close()
        }

        Task { await loadSharedURL() }
    }
    
    // MARK: - Setup
    
    private func setupSwiftUIView(with url: URL) {
        print("🔧 Setting up SwiftUI view...")
        
        // SwiftData container oluştur
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.unal.socialbookmark" // DEĞIŞTIR!
        ) else {
            print("❌ App Group container bulunamadı")
            close()
            return
        }
        
        let storeURL = containerURL.appendingPathComponent("bookmark.sqlite")
        
        do {
            let configuration = ModelConfiguration(
                url: storeURL,
                allowsSave: true
            )
            
            let container = try ModelContainer(
                for: Bookmark.self,
                configurations: configuration
            )
            
            print("✅ ModelContainer created successfully")
            
            let repository = BookmarkRepository(modelContext: container.mainContext)
            
            // SwiftUI view oluştur
            let swiftUIView = ShareExtensionView(
                url: url,
                repository: repository,
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
            
            // Hosting controller
            let hosting = UIHostingController(rootView: swiftUIView)
            self.hostingController = hosting
            
            // Child view controller olarak ekle
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

    // MARK: - Actions
    
    private func close() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    // MARK: - Helpers

    private func parseURL(from text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.firstMatch(in: text, options: [], range: range),
              let urlRange = Range(match.range, in: text) else {
            return nil
        }

        return URL(string: String(text[urlRange]))
    }

    // MARK: - Async loaders

    private func loadSharedURL() async {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProviders = extensionItem.attachments,
              !itemProviders.isEmpty else {
            await MainActor.run { self.close() }
            return
        }
        
        print("📱 Share Extension: \(itemProviders.count) item provider(s) found")

        // URL'yi paralel olarak ara (timeout ile)
        do {
            let shareURL = try await withThrowingTaskGroup(of: URL?.self) { group -> URL in
                // Her provider için task ekle
                for provider in itemProviders {
                    group.addTask { [weak self] in
                        await self?.loadURL(from: provider)
                    }
                }
                
                // İlk başarılı URL'yi döndür
                for try await result in group {
                    if let result {
                        group.cancelAll()
                        return result
                    }
                }
                
                throw NSError(domain: "ShareExt", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL bulunamadı"])
            }
            
            print("✅ URL found: \(shareURL.absoluteString)")
            await MainActor.run { self.setupSwiftUIView(with: shareURL) }
        } catch {
            print("❌ URL loading failed: \(error.localizedDescription)")
            await MainActor.run { self.close() }
        }
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        // Sıra önemli: URL -> String (Plain text)
        
        // 1. URL type olarak kontrol et
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            do {
                if let url = try await loadItem(for: UTType.url, from: provider) as? URL {
                    print("✅ URL loaded via UTType.url")
                    return url
                }
            } catch {
                print("⚠️ UTType.url loading failed: \(error.localizedDescription)")
            }
        }
        
        // 2. Plain text olarak kontrol et
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            do {
                if let text = try await loadItem(for: UTType.plainText, from: provider) as? String {
                    if let url = parseURL(from: text) {
                        print("✅ URL parsed from plain text")
                        return url
                    }
                }
            } catch {
                print("⚠️ Plain text loading failed: \(error.localizedDescription)")
            }
        }
        
        // 3. String sınıfından yükle
        if provider.canLoadObject(ofClass: String.self) {
            do {
                if let text = try await loadObject(ofClass: String.self, from: provider) as? String {
                    if let url = parseURL(from: text) {
                        print("✅ URL parsed from String object")
                        return url
                    }
                }
            } catch {
                print("⚠️ String object loading failed: \(error.localizedDescription)")
            }
        }
        
        print("⚠️ No URL found in item provider")
        return nil
    }

    private func loadObject<T>(ofClass aClass: T.Type, from provider: NSItemProvider) async throws -> T? where T: _ObjectiveCBridgeable, T._ObjectiveCType: NSItemProviderReading {
        var completed = false
        var progressRef: Progress?
        
        return try await withCheckedThrowingContinuation { continuation in
            let progress = provider.loadObject(ofClass: aClass) { [weak provider] object, error in
                guard !completed else { return }
                completed = true
                
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: object)
                }
            }
            
            progressRef = progress
            
            // Timeout: 5 saniye
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                guard !completed, let progress = progressRef else { return }
                
                completed = true
                progress.cancel()
                continuation.resume(throwing: NSError(
                    domain: "ShareExt",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Load timeout"]
                ))
            }
        }
    }

    private func loadItem(for type: UTType, from provider: NSItemProvider) async throws -> NSSecureCoding? {
        var completed = false
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NSSecureCoding?, Error>) in
            _ = provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { [weak provider] item, error in
                guard !completed else { return }
                completed = true
                
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let result = item
                    continuation.resume(returning: result)
                }
            }
            
            // Timeout: 5 saniye
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                guard !completed else { return }
                
                completed = true
                continuation.resume(throwing: NSError(
                    domain: "ShareExt",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Load timeout"]
                ))
            }
        }
    }
}
