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

        Task { await loadSharedURL() }
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
            close()
            return
        }

        guard let shareURL = await firstAvailableURL(from: itemProviders) else {
            close()
            return
        }

        await MainActor.run { setupSwiftUIView(with: shareURL) }
    }

    private func firstAvailableURL(from providers: [NSItemProvider]) async -> URL? {
        await withTaskGroup(of: URL?.self) { group in
            for provider in providers {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    return await self.loadURL(from: provider)
                }
            }

            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }

            return nil
        }
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        if provider.canLoadObject(ofClass: NSURL.self),
           let url = try? await loadObject(ofClass: NSURL.self, from: provider) {
            return url as URL
        }

        if provider.canLoadObject(ofClass: NSString.self),
           let text = try? await loadObject(ofClass: NSString.self, from: provider) {
            return parseURL(from: text as String)
        }

        if provider.canLoadObject(ofClass: NSAttributedString.self),
           let text = try? await loadObject(ofClass: NSAttributedString.self, from: provider) {
            return parseURL(from: text.string)
        }

        if provider.canLoadObject(ofClass: NSData.self),
           let data = try? await loadObject(ofClass: NSData.self, from: provider) {
            return URL(dataRepresentation: data as Data, relativeTo: nil)
        }

        return nil
    }

    private func loadObject<T>(ofClass aClass: T.Type, from provider: NSItemProvider) async throws -> T? where T: _ObjectiveCBridgeable, T._ObjectiveCType: NSItemProviderReading {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: aClass) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: object)
                }
            }
        }
    }
}
