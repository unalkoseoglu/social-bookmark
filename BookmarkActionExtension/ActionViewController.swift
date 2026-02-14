//
//  ActionViewController.swift
//  BookmarkActionExtension
//
//  Optimize edilmiş versiyon - Daha hızlı başlatma
//

import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - ActionViewController

/// Action Extension entry point
/// "Eylemler" listesinde görünür ve bookmark kaydetme UI'ını açar
class ActionViewController: UIViewController {
    
    // MARK: - Constants
    
    private let appGroupId = "group.com.unal.socialbookmark"
    private let loadingTimeoutSeconds: TimeInterval = 15.0
    
    // MARK: - Properties
    
    private var hostingController: UIViewController?
    private var modelContainer: ModelContainer?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Hemen loading göster
        showLoadingView()
        
        // 2. Tüm ağır işleri background'da yap
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // Paralel olarak: Container oluştur + URL'yi topla
            async let containerTask = self.createModelContainerAsync()
            async let urlTask = self.loadSharedURLAsync()
            
            let (container, foundURL) = await (containerTask, urlTask)
            
            await MainActor.run {
                self.modelContainer = container
            }
            
            // UI'ı göster
            if let url = foundURL {
                await MainActor.run {
                    self.setupSwiftUIView(with: url)
                }
            } else {
                print("❌ No URL found in shared items")
                await MainActor.run {
                    self.close()
                }
            }
        }
        
        // 3. Global timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + loadingTimeoutSeconds) { [weak self] in
            guard let self = self, self.hostingController == nil else { return }
            print("⚠️ Action Extension timeout")
            self.close()
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
        containerView.tag = 999
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
    
    private func hideLoadingView() {
        view.viewWithTag(999)?.removeFromSuperview()
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
    
    // MARK: - Load Shared URL (Async)
    
    private func loadSharedURLAsync() async -> URL? {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProviders = extensionItem.attachments,
              !itemProviders.isEmpty else {
            print("❌ No extension items found")
            return nil
        }
        
        print("📱 Action Extension: \(itemProviders.count) item provider(s) found")
        
        for provider in itemProviders {
            // 1. Property List (Safari'den gelen JavaScript data)
            if provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                if let url = await loadURLFromPropertyList(provider: provider) {
                    print("✅ URL found (PropertyList): \(url.absoluteString)")
                    return url
                }
            }
            
            // 2. URL type
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url = await loadURL(from: provider) {
                    print("✅ URL found: \(url.absoluteString)")
                    return url
                }
            }
            
            // 3. Plain text (URL içerebilir)
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = await loadPlainText(from: provider),
                   let url = parseURL(from: text) {
                    print("✅ URL found (text): \(url.absoluteString)")
                    return url
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Load from Property List (Safari JavaScript)
    
    private func loadURLFromPropertyList(provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil) { item, error in
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
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
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
    
    // MARK: - Setup SwiftUI View
    
    private func setupSwiftUIView(with url: URL) {
        print("🔧 Setting up SwiftUI view for Action Extension...")
        
        // Loading view'ı temizle
        hideLoadingView()
        
        guard let container = modelContainer else {
            print("❌ ModelContainer not available")
            showFallbackAlert(url: url)
            return
        }
        
        let bookmarkRepository = BookmarkRepository(modelContext: container.mainContext)
        let categoryRepository = CategoryRepository(modelContext: container.mainContext)
        
        print("📂 Categories loaded: \(categoryRepository.fetchAll().count)")
        
        // Create shared state with repos already ready
        let state = ShareExtensionState()
        state.repository = SyncableBookmarkRepository(baseRepository: bookmarkRepository)
        state.categoryRepository = SyncableCategoryRepository(baseRepository: categoryRepository)
        state.isReady = true
        
        let swiftUIView = ShareExtensionView(
            url: url,
            extensionState: state,
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
