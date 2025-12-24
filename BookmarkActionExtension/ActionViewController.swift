import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UniformTypeIdentifiers

// MARK: - ActionViewController

/// Action Extension entry point
/// "Eylemler" listesinde görünür ve bookmark kaydetme UI'ını açar
class ActionViewController: UIViewController {
    
    // MARK: - Constants
    
    private let appGroupId = "group.com.unal.socialbookmark"
    private let loadingTimeoutSeconds: TimeInterval = 10.0
    
    // MARK: - Properties
    
    private var hostingController: UIViewController?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Background color
        view.backgroundColor = .systemBackground
        
        // Loading indicator göster
        showLoadingIndicator()
        
        // URL'yi yükle
        Task {
            await loadSharedURL()
        }
        
        // Global timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + loadingTimeoutSeconds) { [weak self] in
            guard let self = self, self.hostingController == nil else { return }
            print("⚠️ Action Extension timeout")
            self.close()
        }
    }
    
    // MARK: - Loading Indicator
    
    private func showLoadingIndicator() {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        activityIndicator.tag = 999
        view.addSubview(activityIndicator)
    }
    
    private func hideLoadingIndicator() {
        view.viewWithTag(999)?.removeFromSuperview()
    }
    
    // MARK: - Load Shared URL
    
    private func loadSharedURL() async {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProviders = extensionItem.attachments,
              !itemProviders.isEmpty else {
            print("❌ No extension items found")
            await MainActor.run { close() }
            return
        }
        
        print("📱 Action Extension: \(itemProviders.count) item provider(s) found")
        
        // URL'yi bul
        var foundURL: URL?
        
        for provider in itemProviders {
            // 1. Property List (Safari'den gelen JavaScript data)
            if provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier as String) {
                if let url = await loadURLFromPropertyList(provider: provider) {
                    foundURL = url
                    break
                }
            }
            
            // 2. URL type
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url = await loadURL(from: provider) {
                    foundURL = url
                    break
                }
            }
            
            // 3. Plain text (URL içerebilir)
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = await loadPlainText(from: provider),
                   let url = parseURL(from: text) {
                    foundURL = url
                    break
                }
            }
        }
        
        guard let url = foundURL else {
            print("❌ No URL found in shared items")
            await MainActor.run { close() }
            return
        }
        
        print("✅ URL found: \(url.absoluteString)")
        
        await MainActor.run {
            hideLoadingIndicator()
            setupSwiftUIView(with: url)
        }
    }
    
    // MARK: - Load from Property List (Safari JavaScript)
    
    private func loadURLFromPropertyList(provider: NSItemProvider) async -> URL? {
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier as String, options: nil) { item, error in
                guard error == nil,
                      let dictionary = item as? NSDictionary,
                      let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary,
                      let urlString = results["URL"] as? String,
                      let url = URL(string: urlString) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: url)
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
    
    // MARK: - Setup SwiftUI View
    
    private func setupSwiftUIView(with url: URL) {
        print("🔧 Setting up SwiftUI view for Action Extension...")
        
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
                    print("💾 Bookmark saved from Action Extension")
                    self?.close()
                },
                onCancel: { [weak self] in
                    print("❌ Action Extension cancelled")
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
            print("❌ Action Extension container error: \(error)")
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
}
