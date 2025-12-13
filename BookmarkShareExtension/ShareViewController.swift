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
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                DispatchQueue.main.async {
                    if let shareURL = url as? URL {
                        self?.setupSwiftUIView(with: shareURL)
                    } else {
                        self?.close()
                    }
                }
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
}
