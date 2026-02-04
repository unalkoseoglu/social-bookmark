import Foundation
import SwiftData
import Combine
import UIKit
import OSLog

/// Sync states
enum SyncState {
    case idle
    case syncing
    case uploading
    case downloading
    case error
    case offline
}

/// Synchronization Service
@MainActor
final class SyncService: ObservableObject {
    
    static let shared = SyncService()
    
    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingChangesCount: Int = 0
    @Published var syncError: String?
    
    private var modelContext: ModelContext?
    private let network = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        Logger.sync.info("SyncService initialized")
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        Logger.sync.info("ModelContext configured")
    }
    
    // MARK: - Public Sync Methods
    
    func performFullSync() async {
        guard await canSync() else { 
            Logger.sync.info("⚠️ [SYNC] Sync already in progress or cannot sync, skipping")
            return 
        }
        
        syncState = .syncing
        syncError = nil
        
        do {
            syncState = .downloading
            try await downloadFromCloud()
            
            syncState = .uploading
            try await uploadToCloud()
            
            syncState = .idle
            lastSyncDate = Date()
            print("✅ [SYNC] Full sync complete - notifying UI")
            NotificationCenter.default.post(name: .syncDidComplete, object: nil)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                print("⚠️ [SYNC] Sync task was cancelled")
                syncState = .idle
                return
            }
            
            print("❌ [SYNC] Full sync failed: \(error)")
            syncError = error.localizedDescription
            syncState = .error
            NotificationCenter.default.post(name: .syncDidFail, object: error)
        }
    }
    
    func syncChanges() async {
        await performFullSync()
    }
    
    /// Forces a full sync by clearing last sync timestamp
    /// This will cause the server to return ALL bookmarks and categories
    func forceFullSync() async {
        Logger.sync.info("🔄 [SYNC] Force full sync requested - clearing last sync timestamp")
        
        // Clear last sync to force server to return ALL data
        UserDefaults.standard.removeObject(forKey: APIConstants.Keys.lastSync)
        
        // Perform full sync
        await performFullSync()
    }
    
    func downloadFromCloud() async throws {
        let user = await AuthService.shared.getCurrentUser()
        guard let context = modelContext,
              let userId = user?.id.uuidString else {
            throw SyncError.notAuthenticated
        }
        print("🔄 [SYNC] Downloading from cloud (sync/delta)")

        let since = UserDefaults.standard.string(forKey: APIConstants.Keys.lastSync)
        
        let requestBody = DeltaSyncRequest(
            lastSyncTimestamp: since,
            bookmarks: nil, // We'll handle outgoing changes in uploadToCloud for now, or we can integrate here
            categories: nil
        )
        
        let delta: DeltaSyncResponse = try await network.request(
            endpoint: APIConstants.Endpoints.syncDelta,
            method: "POST",
            body: try JSONEncoder().encode(requestBody)
        )
        
        try await processDeltaCategories(delta.updatedCategories, deletedIds: delta.deletedIds["categories"] ?? [], context: context)
        try await processDeltaBookmarks(delta.updatedBookmarks, deletedIds: delta.deletedIds["bookmarks"] ?? [], context: context)

        try context.save()
        
        UserDefaults.standard.set(delta.currentServerTime, forKey: APIConstants.Keys.lastSync)
        
        print("✅ [SYNC] Delta download complete")
    }
    
    func uploadToCloud() async throws {
        let user = await AuthService.shared.getCurrentUser()
        guard let context = modelContext,
              let userId = user?.id.uuidString else {
            throw SyncError.notAuthenticated
        }

        try await uploadCategories(context: context)
        try await uploadBookmarks(context: context)
    }
    
    func syncBookmark(_ bookmark: Bookmark, fileData: Data? = nil) async throws {
        guard await AuthService.shared.getCurrentUser() != nil else {
            throw SyncError.notAuthenticated
        }

        let payload = createBookmarkPayload(bookmark)
        let jsonPayload = try JSONEncoder().encode(["bookmarks": [payload]])
        let jsonString = String(data: jsonPayload, encoding: .utf8) ?? ""

        var filesToUpload: [NetworkManager.FileUpload] = []

        // Add multiple images if present
        if let imagesData = bookmark.imagesData, !imagesData.isEmpty {
            for (index, imageData) in imagesData.enumerated() {
                filesToUpload.append(.init(
                    data: imageData,
                    fileName: "image_\(bookmark.id.uuidString)_\(index).jpg",
                    mimeType: "image/jpeg",
                    fieldName: "images[]" // Array format for multiple images
                ))
            }
        } else if let singleImage = bookmark.imageData {
            filesToUpload.append(.init(
                data: singleImage,
                fileName: "image_\(bookmark.id.uuidString).jpg",
                mimeType: "image/jpeg",
                fieldName: "images[]"
            ))
        }

        // Add document if present
        if let data = fileData ?? bookmark.fileData, let fileName = bookmark.fileName {
            filesToUpload.append(.init(
                data: data,
                fileName: fileName,
                mimeType: "application/octet-stream",
                fieldName: "file"
            ))
        }

        if !filesToUpload.isEmpty {
            // Multipart sync
            let _: [String: AnyCodable] = try await network.upload(
                endpoint: APIConstants.Endpoints.bookmarksUpsert,
                files: filesToUpload,
                additionalFields: ["payload": jsonString]
            )
        } else {
            // Standard JSON sync
            let _: [String: AnyCodable] = try await network.request(
                endpoint: APIConstants.Endpoints.bookmarksUpsert,
                method: "POST",
                body: jsonPayload
            )
        }
    }
    
    func syncCategory(_ category: Category) async throws {
        guard await AuthService.shared.getCurrentUser() != nil else {
            throw SyncError.notAuthenticated
        }

        let payload = createCategoryPayload(category)
        
        let _: [String: AnyCodable] = try await network.request(
            endpoint: APIConstants.Endpoints.categoriesUpsert,
            method: "POST",
            body: try JSONEncoder().encode(["categories": [payload]])
        )
    }
    
    func deleteBookmark(_ bookmark: Bookmark) async throws {
        guard await AuthService.shared.getCurrentUser() != nil else { return }
        
        _ = try await network.request(
            endpoint: "\(APIConstants.Endpoints.bookmarks)/\(bookmark.id.uuidString.lowercased())",
            method: "DELETE"
        ) as EmptyResponse
    }
    
    func deleteCategory(_ category: Category) async throws {
        guard await AuthService.shared.getCurrentUser() != nil else { return }
        
        _ = try await network.request(
            endpoint: "\(APIConstants.Endpoints.categories)/\(category.id.uuidString.lowercased())",
            method: "DELETE"
        ) as EmptyResponse
    }
    
    // MARK: - Delta Processing
    
    private func processDeltaCategories(_ cloudCategories: [CloudCategory], deletedIds: [String], context: ModelContext) async throws {
        for id in deletedIds {
            if let uuid = UUID(uuidString: id) {
                let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == uuid })
                if let local = try context.fetch(descriptor).first {
                    context.delete(local)
                }
            }
        }
        
        for cloud in cloudCategories {
            let targetUUID = cloud.localId ?? cloud.id
            
            let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == targetUUID })
            
            if let existing = try context.fetch(descriptor).first {
                existing.name = cloud.name
                existing.icon = cloud.icon
                existing.colorHex = cloud.color
                existing.order = cloud.order
            } else {
                let newCategory = Category(
                    id: targetUUID,
                    name: cloud.name,
                    icon: cloud.icon,
                    colorHex: cloud.color,
                    order: cloud.order
                )
                context.insert(newCategory)
            }
        }
    }
    
    private func processDeltaBookmarks(_ cloudBookmarks: [CloudBookmark], deletedIds: [String], context: ModelContext) async throws {
        for id in deletedIds {
            if let uuid = UUID(uuidString: id) {
                let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.id == uuid })
                if let local = try context.fetch(descriptor).first {
                    context.delete(local)
                }
            }
        }
        
        for cloud in cloudBookmarks {
            let targetUUID = cloud.localId ?? cloud.id
            
            let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.id == targetUUID })
            
            if let existing = try context.fetch(descriptor).first {
                updateBookmark(existing, with: cloud)
            } else {
                let newBookmark = Bookmark(
                    title: cloud.title,
                    url: cloud.url,
                    note: cloud.note ?? "",
                    source: BookmarkSource(rawValue: cloud.source) ?? .manual
                )
                newBookmark.id = targetUUID
                updateBookmark(newBookmark, with: cloud)
                context.insert(newBookmark)
            }
        }
    }
    
    private func updateBookmark(_ bookmark: Bookmark, with cloud: CloudBookmark) {
        bookmark.title = cloud.title
        bookmark.url = cloud.url
        bookmark.note = cloud.note ?? ""
        bookmark.isRead = cloud.isRead
        bookmark.isFavorite = cloud.isFavorite
        bookmark.imageUrls = cloud.imageUrls
        bookmark.fileURL = cloud.fileUrl
        
        if let tags = cloud.tags {
            bookmark.tags = tags
        }
        
        // Note: cloud model doesn't have updatedAt anymore
        // Tag management and category mapping...
        if let categoryId = cloud.categoryId {
            bookmark.categoryId = categoryId
        }
    }
    
    // MARK: - Upload Helpers
    
    private func uploadCategories(context: ModelContext) async throws {
        let localCategories = try context.fetch(FetchDescriptor<Category>())
        guard !localCategories.isEmpty else { return }

        let payloads = localCategories.map { createCategoryPayload($0) }
        
        let _: [String: AnyCodable] = try await network.request(
            endpoint: APIConstants.Endpoints.categoriesUpsert,
            method: "POST",
            body: try JSONEncoder().encode(["categories": payloads])
        )
    }

    private func uploadBookmarks(context: ModelContext) async throws {
        let localBookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        guard !localBookmarks.isEmpty else { return }

        var payloads: [[String: AnyEncodable]] = []
        
        for bookmark in localBookmarks {
            var payload = createBookmarkPayload(bookmark)
            
            // Only try to upload if we have local image data and NO valid cloud URLs
            let hasValidCloudImages = bookmark.imageUrls?.contains { $0.starts(with: "http") } ?? false
            
            if let imageData = bookmark.imageData, !hasValidCloudImages {
                do {
                    let url = try await ImageUploadService.shared.uploadImage(UIImage(data: imageData) ?? UIImage(), for: bookmark.id)
                    payload["image_urls"] = AnyEncodable([url])
                    bookmark.imageUrls = [url]
                } catch {
                    print("❌ [SYNC] Image upload failed for bookmark \(bookmark.id): \(error)")
                    // Continue without images rather than failing the whole batch
                }
            }
            payloads.append(payload)
        }

        do {
            let _: [String: AnyCodable] = try await network.request(
                endpoint: APIConstants.Endpoints.bookmarksUpsert,
                method: "POST",
                body: try JSONEncoder().encode(["bookmarks": payloads])
            )
        } catch {
            print("❌ [SYNC] Bookmarks upsert failed: \(error)")
            throw error
        }
    }

    // MARK: - Private Helpers
    
    private func canSync() async -> Bool {
        guard modelContext != nil else { return false }
        guard await AuthService.shared.getCurrentUser() != nil else { return false }
        // guard NetworkMonitor.shared.isConnected else { return false } // TODO: Re-enable when NetworkMonitor is available
        return syncState == .idle
    }

    private func decryptIfNeeded(_ value: String, isEncrypted: Bool) -> String {
        guard isEncrypted else { return value }
        // return (try? EncryptionService.shared.decryptOptional(value)) ?? value // TODO: Re-enable when EncryptionService is available
        return value // Temporarily return unencrypted value
    }

    private func createBookmarkPayload(_ bookmark: Bookmark) -> [String: AnyEncodable] {
        var payload: [String: AnyEncodable] = [
            "id": AnyEncodable(bookmark.id.uuidString.lowercased()),
            "local_id": AnyEncodable(bookmark.id.uuidString.lowercased()),
            "title": AnyEncodable(bookmark.title),
            "source": AnyEncodable(bookmark.source.rawValue),
            "is_read": AnyEncodable(bookmark.isRead),
            "is_favorite": AnyEncodable(bookmark.isFavorite),
            "sync_version": AnyEncodable(0) // Default for new/updated
        ]

        if let url = bookmark.url, !url.isEmpty {
            payload["url"] = AnyEncodable(url)
        }
        
        if !bookmark.note.isEmpty {
            payload["note"] = AnyEncodable(bookmark.note)
        }
        
        if !bookmark.tags.isEmpty {
            payload["tags"] = AnyEncodable(bookmark.tags)
        }

        if let categoryId = bookmark.categoryId {
            payload["category_id"] = AnyEncodable(categoryId.uuidString.lowercased())
        }
        
        if let imageUrls = bookmark.imageUrls, !imageUrls.isEmpty {
            payload["image_urls"] = AnyEncodable(imageUrls)
        }
        
        if let fileUrl = bookmark.fileURL {
            payload["file_url"] = AnyEncodable(fileUrl)
        }

        return payload
    }

    private func createCategoryPayload(_ category: Category) -> [String: AnyEncodable] {
        let payload: [String: AnyEncodable] = [
            "id": AnyEncodable(category.id.uuidString.lowercased()),
            "local_id": AnyEncodable(category.id.uuidString.lowercased()),
            "name": AnyEncodable(category.name),
            "icon": AnyEncodable(category.icon),
            "color": AnyEncodable(category.colorHex),
            "order": AnyEncodable(category.order)
        ]

        return payload
    }
}

// MARK: - Sync Errors
enum SyncError: LocalizedError {
    case notAuthenticated
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Oturum açılmadı"
        case .networkError(let msg): return msg
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let syncDidComplete = Notification.Name("syncDidComplete")
    static let syncDidFail = Notification.Name("syncDidFail")
    static let bookmarksDidSync = Notification.Name("bookmarksDidSync")
    static let categoriesDidSync = Notification.Name("categoriesDidSync")
    static let localDataCleared = Notification.Name("localDataCleared")
}
