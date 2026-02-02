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
        guard canSync() else { return }
        
        syncState = .syncing
        syncError = nil
        
        do {
            syncState = .downloading
            try await downloadFromCloud()
            
            syncState = .uploading
            try await uploadToCloud()
            
            syncState = .idle
            lastSyncDate = Date()
            print("✅ [SYNC] Full sync complete")
        } catch {
            print("❌ [SYNC] Full sync failed: \(error)")
            syncError = error.localizedDescription
            syncState = .error
            NotificationCenter.default.post(name: .syncDidFail, object: error)
        }
    }
    
    func syncChanges() async {
        await performFullSync()
    }
    
    func downloadFromCloud() async throws {
        let user = await AuthService.shared.getCurrentUser()
        guard let context = modelContext,
              let userId = user?.id.uuidString else {
            throw SyncError.notAuthenticated
        }
        print("🔄 [SYNC] Downloading from cloud (sync/delta)")

        let since = UserDefaults.standard.string(forKey: APIConstants.Keys.lastSync) ?? "1970-01-01T00:00:00Z"
        
        let delta: SyncDeltaResponse = try await network.request(
            endpoint: APIConstants.Endpoints.syncDelta + "?since=\(since.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        )
        
        try await processDeltaCategories(delta.updatedCategories, deletedIds: delta.deletedIds.categories, context: context)
        try await processDeltaBookmarks(delta.updatedBookmarks, deletedIds: delta.deletedIds.bookmarks, context: context)

        try context.save()
        
        UserDefaults.standard.set(delta.currentServerTime, forKey: APIConstants.Keys.lastSync)
        
        print("✅ [SYNC] Delta sync complete - notifying UI")
        NotificationCenter.default.post(name: .syncDidComplete, object: nil)
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

        var payload = createBookmarkPayload(bookmark)
        
        if let imageData = bookmark.imageData, (bookmark.imageUrls?.isEmpty ?? true) {
            do {
                let url = try await ImageUploadService.shared.uploadImage(UIImage(data: imageData) ?? UIImage(), for: bookmark.id)
                payload["image_urls"] = AnyEncodable([url]) 
                bookmark.imageUrls = [url]
            } catch {
                print("❌ [SYNC] Image upload failed: \(error)")
            }
        }
        
        // Document upload
        if let data = fileData, let fileName = bookmark.fileName {
             do {
                 let mimeType = "application/octet-stream" 
                 let url = try await DocumentUploadService.shared.uploadDocument(data: data, fileName: fileName, mimeType: mimeType, for: bookmark.id)
                 bookmark.fileURL = url
                 payload["file_url"] = AnyEncodable(url)
             } catch {
                 print("❌ [SYNC] Document upload failed: \(error)")
             }
        }

        let _: [String: AnyCodable] = try await network.request(
            endpoint: APIConstants.Endpoints.bookmarksUpsert,
            method: "POST",
            body: try JSONEncoder().encode(["bookmarks": [payload]])
        )
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
            let targetId = cloud.localId ?? cloud.id
            guard let targetUUID = UUID(uuidString: targetId) else { continue }
            
            let isEnc = (cloud.isEncrypted == true)
            let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == targetUUID })
            
            if let existing = try context.fetch(descriptor).first {
                existing.name = decryptIfNeeded(cloud.name, isEncrypted: isEnc)
                existing.icon = cloud.icon ?? "folder"
                existing.colorHex = cloud.color ?? "#000000"
                existing.order = cloud.order ?? 0
                if let updatedAt = cloud.updatedAt, let date = ISO8601DateFormatter().date(from: updatedAt) {
                    existing.updatedAt = date
                }
            } else {
                let newCategory = Category(
                    id: targetUUID,
                    name: decryptIfNeeded(cloud.name, isEncrypted: isEnc),
                    icon: cloud.icon ?? "folder",
                    colorHex: cloud.color ?? "#000000",
                    order: cloud.order ?? 0
                )
                if let createdAt = cloud.createdAt, let date = ISO8601DateFormatter().date(from: createdAt) {
                    newCategory.createdAt = date
                }
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
            let targetId = cloud.localId ?? cloud.id
            guard let targetUUID = UUID(uuidString: targetId) else { continue }
            
            let isEnc = (cloud.isEncrypted == true)
            let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.id == targetUUID })
            
            if let existing = try context.fetch(descriptor).first {
                updateBookmark(existing, with: cloud, isEncrypted: isEnc)
            } else {
                let newBookmark = Bookmark(
                    title: decryptIfNeeded(cloud.title, isEncrypted: isEnc),
                    url: cloud.url != nil ? decryptIfNeeded(cloud.url!, isEncrypted: isEnc) : nil,
                    note: cloud.note != nil ? decryptIfNeeded(cloud.note!, isEncrypted: isEnc) : "",
                    source: BookmarkSource(rawValue: cloud.source) ?? .manual
                )
                newBookmark.id = targetUUID
                updateBookmark(newBookmark, with: cloud, isEncrypted: isEnc)
                context.insert(newBookmark)
            }
        }
    }
    
    private func updateBookmark(_ bookmark: Bookmark, with cloud: CloudBookmark, isEncrypted: Bool) {
        bookmark.title = decryptIfNeeded(cloud.title, isEncrypted: isEncrypted)
        bookmark.url = cloud.url != nil ? decryptIfNeeded(cloud.url!, isEncrypted: isEncrypted) : nil
        bookmark.note = cloud.note != nil ? decryptIfNeeded(cloud.note!, isEncrypted: isEncrypted) : ""
        bookmark.isRead = cloud.isRead
        bookmark.isFavorite = cloud.isFavorite
        bookmark.imageUrls = cloud.imageUrls
        bookmark.fileURL = cloud.fileURL
        bookmark.fileName = cloud.fileName
        bookmark.fileExtension = cloud.fileExtension
        bookmark.fileSize = cloud.fileSize
        
        if let tags = cloud.tags {
            bookmark.tags = tags.map { decryptIfNeeded($0, isEncrypted: isEncrypted) }
        }
        
        if let updatedAtAt = cloud.updatedAt, let date = ISO8601DateFormatter().date(from: updatedAtAt) {
            bookmark.updatedAt = date
        }
        
        // Category mapping would go here if needed
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
            
            if let imageData = bookmark.imageData, (bookmark.imageUrls?.isEmpty ?? true) {
                do {
                    let url = try await ImageUploadService.shared.uploadImage(UIImage(data: imageData) ?? UIImage(), for: bookmark.id)
                    payload["image_urls"] = AnyEncodable([url])
                    bookmark.imageUrls = [url]
                } catch {
                    print("❌ [SYNC] Image upload failed for bookmark \(bookmark.id): \(error)")
                }
            }
            payloads.append(payload)
        }

        let _: [String: AnyCodable] = try await network.request(
            endpoint: APIConstants.Endpoints.bookmarksUpsert,
            method: "POST",
            body: try JSONEncoder().encode(["bookmarks": payloads])
        )
    }

    // MARK: - Private Helpers
    
    private func canSync() -> Bool {
        guard modelContext != nil else { return false }
        guard await AuthService.shared.getCurrentUser() != nil else { return false }
        guard NetworkMonitor.shared.isConnected else { return false }
        return syncState == .idle
    }

    private func decryptIfNeeded(_ value: String, isEncrypted: Bool) -> String {
        guard isEncrypted else { return value }
        return (try? EncryptionService.shared.decryptOptional(value)) ?? value
    }

    private func createBookmarkPayload(_ bookmark: Bookmark) -> [String: AnyEncodable] {
        var payload: [String: AnyEncodable] = [
            "id": AnyEncodable(bookmark.id.uuidString.lowercased()),
            "local_id": AnyEncodable(bookmark.id.uuidString.lowercased()),
            "source": AnyEncodable(bookmark.source.rawValue),
            "is_read": AnyEncodable(bookmark.isRead),
            "is_favorite": AnyEncodable(bookmark.isFavorite),
            "created_at": AnyEncodable(ISO8601DateFormatter().string(from: bookmark.createdAt)),
            "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: bookmark.lastUpdated)),
            "is_encrypted": AnyEncodable(true)
        ]

        if let categoryId = bookmark.categoryId {
            payload["category_id"] = AnyEncodable(categoryId.uuidString.lowercased())
        }

        do {
            let encryption = EncryptionService.shared
            payload["title"] = AnyEncodable(try encryption.encrypt(bookmark.title).ciphertext)
            if let url = bookmark.url, !url.isEmpty {
                payload["url"] = AnyEncodable(try encryption.encrypt(url).ciphertext)
            }
            if !bookmark.note.isEmpty {
                payload["note"] = AnyEncodable(try encryption.encrypt(bookmark.note).ciphertext)
            }
            if !bookmark.tags.isEmpty {
                let encryptedTags = try bookmark.tags.map { try encryption.encrypt($0).ciphertext }
                payload["tags"] = AnyEncodable(encryptedTags)
            }
        } catch {
            payload["title"] = AnyEncodable(bookmark.title)
            payload["is_encrypted"] = AnyEncodable(false)
        }

        return payload
    }

    private func createCategoryPayload(_ category: Category) -> [String: AnyEncodable] {
        var payload: [String: AnyEncodable] = [
            "id": AnyEncodable(category.id.uuidString.lowercased()),
            "local_id": AnyEncodable(category.id.uuidString.lowercased()),
            "icon": AnyEncodable(category.icon),
            "color_hex": AnyEncodable(category.colorHex),
            "order": AnyEncodable(category.order),
            "created_at": AnyEncodable(ISO8601DateFormatter().string(from: category.createdAt)),
            "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: category.lastUpdated)),
            "is_encrypted": AnyEncodable(true)
        ]

        do {
            let encryption = EncryptionService.shared
            payload["name"] = AnyEncodable(try encryption.encrypt(category.name).ciphertext)
        } catch {
            payload["name"] = AnyEncodable(category.name)
            payload["is_encrypted"] = AnyEncodable(false)
        }

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
}
