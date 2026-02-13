import Foundation
import SwiftData
import OSLog

/// Service to process data saved in the App Group inbox by the Share Extension
final class InboxProcessingService {
    
    // MARK: - Constants
    
    private let appGroupId = APIConstants.appGroupId
    private let inboxKey = "share_inbox_payloads"
    private let imageDirectory = "SharedImages"
    
    // MARK: - Properties
    
    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public Methods
    
    /// Processes all pending payloads in the App Group inbox
    func processPendingPayloads() async {
        guard let data = defaults.data(forKey: inboxKey) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let payloads = try? decoder.decode([SharedInboxPayload].self, from: data), !payloads.isEmpty else {
            return
        }
        
        Logger.app.info("📥 [Inbox] Found \(payloads.count) pending inbox payload(s)")
        
        for payload in payloads {
            await processPayload(payload)
        }
        
        // Clear inbox after processing
        defaults.removeObject(forKey: inboxKey)
        Logger.app.info("✅ [Inbox] Finished processing payloads and cleared inbox")
    }
    
    // MARK: - Private Helpers
    
    private func processPayload(_ payload: SharedInboxPayload) async {
        let urlString = payload.urls.first ?? payload.texts.first ?? ""
        guard !urlString.isEmpty else { return }
        
        // Basic Bookmark creation (Main App will handle metadata extraction if it's new)
        let bookmark = Bookmark(
            title: urlString, // Fallback title
            url: urlString,
            note: payload.texts.joined(separator: "\n"),
            source: .other // Manual/Other for inbox
        )
        
        // Handle images if any
        if !payload.imageFileNames.isEmpty {
            var imagesData: [Data] = []
            for fileName in payload.imageFileNames {
                if let data = loadImageData(fileName: fileName) {
                    imagesData.append(data)
                }
            }
            
            if !imagesData.isEmpty {
                bookmark.imagesData = imagesData
                bookmark.imageData = imagesData.first
            }
        }
        
        // Insert and sync
        modelContext.insert(bookmark)
        
        do {
            try modelContext.save()
            Logger.app.info("✅ [Inbox] Saved bookmark from inbox: \(urlString)")
            
            // Trigger sync in background
            Task {
                do {
                    try await SyncService.shared.syncBookmark(bookmark)
                    Logger.app.info("✅ [Inbox] Synced inbox bookmark to cloud")
                } catch {
                    Logger.app.error("❌ [Inbox] Cloud sync failed for inbox bookmark: \(error.localizedDescription)")
                }
            }
        } catch {
            Logger.app.error("❌ [Inbox] Failed to save inbox bookmark: \(error.localizedDescription)")
        }
    }
    
    private func loadImageData(fileName: String) -> Data? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        
        let fileURL = containerURL.appendingPathComponent(imageDirectory).appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }
}
