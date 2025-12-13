import UIKit
import SwiftUI
import Social
import SwiftData
import UniformTypeIdentifiers

/// Share Extension'ın entry point'i
/// Safari'den gelen URL'i alıp SwiftUI view'a geçirir
class ShareViewController: UIViewController {
    // MARK: - Properties
    
    private var hostingController: UIHostingController<ShareExtensionView>?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Share edilen içeriği al
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            close()
            return
        }
        
        // URL'i çek
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] url, _ in
                self?.handleLoadedItem(url)
            }
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] text, _ in
                self?.handleLoadedItem(text)
            }
        } else {
            close()
        }
    }
    
    // MARK: - Setup
    
    private func setupSwiftUIView(with url: URL) {
        // SwiftData container oluştur
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.unal.socialbookmark" // DEĞIŞTIR!
        ) else {
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
            
            let repository = BookmarkRepository(modelContext: container.mainContext)
            
            // SwiftUI view oluştur
            let swiftUIView = ShareExtensionView(
                url: url,
                repository: repository,
                onSave: { [weak self] in
                    self?.close()
                },
                onCancel: { [weak self] in
                    self?.close()
                }
            )
            .modelContainer(container)
            
            // Hosting controller
            let hosting = UIHostingController(rootView: swiftUIView)
            hostingController = hosting as? UIHostingController<ShareExtensionView>
            
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

    private func handleLoadedItem(_ item: NSSecureCoding?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if let shareURL = item as? URL {
                setupSwiftUIView(with: shareURL)
                return
            }

            if let text = item as? String, let detectedURL = parseURL(from: text) {
                setupSwiftUIView(with: detectedURL)
                return
            }

            close()
        }
    }

    private func parseURL(from text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.firstMatch(in: text, options: [], range: range),
              let urlRange = Range(match.range, in: text) else {
            return nil
        }

        return URL(string: String(text[urlRange]))
    }
}
