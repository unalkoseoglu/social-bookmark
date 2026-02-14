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
    
    private var defaults: UserDefaults {
        UserDefaults(suiteName: APIConstants.appGroupId) ?? .standard
    }
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private init() {
        Logger.sync.info("SyncService initialized")
        setupReachability()
    }

    private func setupReachability() {
        NetworkMonitor.shared.$isConnected
            .sink { [weak self] isConnected in
                guard isConnected else { return }
                Task { [weak self] in
                    await self?.syncChanges()
                }
            }
            .store(in: &cancellables)
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString, !dateString.isEmpty else { return nil }
        
        // 1. Try ISO8601 with fractional seconds
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFractional.date(from: dateString) {
            return date
        }
        
        // 2. Try standard ISO8601
        let isoStandard = ISO8601DateFormatter()
        if let date = isoStandard.date(from: dateString) {
            return date
        }
        
        // 3. Fallback for Laravel default: "yyyy-MM-dd HH:mm:ss"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.date(from: dateString)
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        Logger.sync.info("ModelContext configured")
    }
    
    // MARK: - Public Sync Methods
    
    func performFullSync() async {
        await performFullSyncWithRetry(retryCount: 0)
    }

    private func performFullSyncWithRetry(retryCount: Int) async {
        guard await canSync() else {
            Logger.sync.info("⚠️ [SYNC] Sync already in progress or cannot sync, skipping")
            return
        }
        
        syncState = .syncing
        syncError = nil
        
        do {
            Logger.sync.info("🔄 [SYNC] Starting full sync (Attempt \(retryCount + 1))...")
            syncState = .downloading
            try await downloadFromCloud()
            
            // Data consistency: fix orphaned bookmarks after download
            try? await repairOrphanedBookmarks()
            
            syncState = .uploading
            try await uploadToCloud()
            
            // Temporary: Repair any local records that might be stuck as ciphertext
            Logger.sync.info("🛠️ [SYNC] Running local encryption repair...")
            try? await repairLocalEncryption()
            
            syncState = .idle
            lastSyncDate = Date()
            Logger.sync.info("✅ [SYNC] Full sync complete - notifying UI")
            NotificationCenter.default.post(name: .syncDidComplete, object: nil)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                Logger.sync.info("⚠️ [SYNC] Sync task was cancelled")
                syncState = .idle
                return
            }
            
            Logger.sync.error("❌ [SYNC] Full sync failed: \(error)")
            
            if isRetryable(error) && retryCount < 3 {
                let delay = pow(2.0, Double(retryCount)) * 5.0 // 5, 10, 20 seconds
                Logger.sync.info("🔄 [SYNC] Retrying in \(delay) seconds...")
                syncState = .syncing // Keep it in syncing state
                
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await performFullSyncWithRetry(retryCount: retryCount + 1)
            } else {
                syncError = error.localizedDescription
                syncState = .error
                NotificationCenter.default.post(name: .syncDidFail, object: error)
            }
        }
    }

    /// Clears all local data AND sync progress, then re-downloads everything.
    func resetSync() async throws {
        Logger.sync.error("🚨 [SYNC] RESET SYNC REQUESTED! Clearing everything...")
        guard let context = modelContext else { return }
        
        syncState = .syncing
        
        // 1. Clear last sync timestamp
        defaults.removeObject(forKey: APIConstants.Keys.lastSync)
        
        // 2. Clear local data
        try await clearLocalData(context: context)
        
        // 3. Perform fresh sync
        try await downloadFromCloud()
        
        syncState = .idle
        lastSyncDate = Date()
        Logger.sync.info("✅ [SYNC] Reset sync complete.")
        NotificationCenter.default.post(name: .syncDidComplete, object: nil)
    }
    
    func syncChanges() async {
        await performFullSync()
    }
    
    /// Forces a full sync by clearing last sync timestamp
    /// This will cause the server to return ALL bookmarks and categories
    func forceFullSync() async {
        Logger.sync.info("🔄 [SYNC] Force full sync requested - clearing last sync timestamp")
        
        // Clear last sync to force server to return ALL data
        defaults.removeObject(forKey: APIConstants.Keys.lastSync)
        
        // Perform full sync
        await performFullSync()
    }
    
    func downloadFromCloud() async throws {
        let user = await AuthService.shared.getCurrentUser()
        guard let context = modelContext,
              user != nil else {
            throw SyncError.notAuthenticated
        }
        Logger.sync.info("🔄 [SYNC] Downloading from cloud (sync/delta)")

        let since = defaults.string(forKey: APIConstants.Keys.lastSync)
        
        
        // Don't automatically clear local data - only do this via manual "Reset Sync" button
        // If backend returns empty data, we don't want to lose local data
        
        
        let requestBody = DeltaSyncRequest(
            lastSyncTimestamp: since,
            bookmarks: nil, // We'll handle outgoing changes in uploadToCloud for now, or we can integrate here
            categories: nil
        )
        
        let delta: DeltaSyncResponse = try await network.request(
            endpoint: APIConstants.Endpoints.syncDelta,
            method: "POST",
            body: try encoder.encode(requestBody)
        )
        
        Logger.sync.info("📥 [SYNC] Delta received: \(delta.updatedBookmarks.count) bookmarks, \(delta.updatedCategories.count) categories")
        
        try await processDeltaCategories(delta.updatedCategories, deletedIds: delta.deletedIds["categories"] ?? [], context: context)
        try await processDeltaBookmarks(delta.updatedBookmarks, deletedIds: delta.deletedIds["bookmarks"] ?? [], context: context)

        try context.save()
        
        // Final count verification
        let finalCount = (try? context.fetchCount(FetchDescriptor<Bookmark>())) ?? 0
        Logger.sync.info("📊 [SYNC] Local bookmark count after sync: \(finalCount)")
        
        // Update sync timestamp
        defaults.set(delta.currentServerTime, forKey: APIConstants.Keys.lastSync)
        
        Logger.sync.info("✅ [SYNC] Delta sync complete. New timestamp: \(delta.currentServerTime)")
    }
    
    /// Belirli bir kategoriye ait bookmarkları sunucudan çeker
    func fetchBookmarks(categoryId: UUID? = nil) async throws {
        var queryParams: [String: String] = [:]
        if let categoryId = categoryId {
            let idString = categoryId.uuidString.lowercased()
            queryParams["category_id"] = idString
            print("🌐 [SYNC] Fetching bookmarks for category: \(idString)")
        }
        
        Logger.sync.info("🌐 [SYNC] Calling GET \(APIConstants.Endpoints.bookmarks) with params: \(queryParams)")
        
        // Explicitly decode the response to avoid scope issues if CloudListResponse is flaky
        let response: [String: [CloudBookmark]] = try await network.request(
            endpoint: APIConstants.Endpoints.bookmarks,
            method: "GET",
            queryParameters: queryParams
        )
        
        let bookmarkData = response["data"] ?? []
        
        guard let context = modelContext else {
            Logger.sync.error("❌ ModelContext not configured in SyncService")
            return
        }
        
        try await processDeltaBookmarks(bookmarkData, deletedIds: [], context: context)
        try context.save()
        
        // Refresh UI
        NotificationCenter.default.post(name: .syncDidComplete, object: nil)
        
       
    }
    
    func clearLocalData(context: ModelContext) async throws {
        // Delete all local categories
        let categoryDescriptor = FetchDescriptor<Category>()
        let categories = try context.fetch(categoryDescriptor)
        for category in categories {
            context.delete(category)
        }
        Logger.sync.info("🗑️ Cleared \(categories.count) local categories")
        
        // Delete all local bookmarks
        let bookmarkDescriptor = FetchDescriptor<Bookmark>()
        let bookmarks = try context.fetch(bookmarkDescriptor)
        for bookmark in bookmarks {
            context.delete(bookmark)
        }
        Logger.sync.info("🗑️ Cleared \(bookmarks.count) local bookmarks")
        
        try context.save()
    }
    
    /// Repairs local data by attempting to decrypt any ciphertext strings.
    /// Useful if initial sync happened while keychain was locked.
    func repairLocalEncryption() async throws {
        guard let context = modelContext else { return }
        
        // Ensure key is loaded
        _ = try? EncryptionService.shared.getOrCreateKey()
        guard EncryptionService.shared.isKeyAvailable else {
            Logger.sync.error("❌ Cannot repair encryption: Key still not available")
            return
        }
        
        Logger.sync.info("🛠️ [SYNC] Starting local encryption repair...")
        
        var totalCategoryChanges = 0
        var totalBookmarkChanges = 0
        var pass = 1
        let maxPasses = 5
        
        while pass <= maxPasses {
            var passCategoryChanges = 0
            var passBookmarkChanges = 0
            
            // Repair Categories
            let categories = try context.fetch(FetchDescriptor<Category>())
        for category in categories {
            let originalName = category.name
            let decryptedName = EncryptionService.shared.decryptOptional(originalName) ?? originalName
            if decryptedName != originalName {
                Logger.sync.info("🔍 [REPAIR][Pass \(pass)] Fixed category: '\(originalName.prefix(10))...' -> '\(decryptedName.prefix(15))...'")
                category.name = decryptedName
                passCategoryChanges += 1
            }
        }
        
        // Repair Bookmarks
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        for bookmark in bookmarks {
            var changed = false
            
            let originalTitle = bookmark.title
            let decryptedTitle = EncryptionService.shared.decryptOptional(originalTitle) ?? originalTitle
            if decryptedTitle != originalTitle {
                bookmark.title = decryptedTitle
                changed = true
            }
            
            if let originalUrl = bookmark.url {
                let decryptedUrl = EncryptionService.shared.decryptOptional(originalUrl) ?? originalUrl
                if decryptedUrl != originalUrl {
                    bookmark.url = decryptedUrl
                    changed = true
                }
            }
            
            if !bookmark.note.isEmpty {
                let originalNote = bookmark.note
                let decryptedNote = EncryptionService.shared.decryptOptional(originalNote) ?? originalNote
                if decryptedNote != originalNote {
                    Logger.sync.debug("🔍 [REPAIR][Pass \(pass)] Fixed note for bookmark: \(originalTitle.prefix(15))...")
                    bookmark.note = decryptedNote
                    changed = true
                }
            }
            
            // Repair Tags
            let originalTags = bookmark.tags
            let decryptedTags = originalTags.map { EncryptionService.shared.decryptOptional($0) ?? $0 }
            if decryptedTags != originalTags {
                Logger.sync.debug("🔍 [REPAIR][Pass \(pass)] Fixed tags for bookmark: \(originalTitle.prefix(15))...")
                bookmark.tags = decryptedTags
                changed = true
            }
            
            if decryptedTitle != originalTitle {
                Logger.sync.debug("🔍 [REPAIR][Pass \(pass)] Fixed title: '\(originalTitle.prefix(10))...' -> '\(decryptedTitle.prefix(15))...'")
            }
            
            if changed { 
                passBookmarkChanges += 1
            }
        }
        
        if passCategoryChanges == 0 && passBookmarkChanges == 0 {
            break
        }
        
        totalCategoryChanges += passCategoryChanges
        totalBookmarkChanges += passBookmarkChanges
        
        // Save intermediate pass
        try context.save()
        Logger.sync.info("📦 [REPAIR] Pass \(pass) complete. Fixed \(passCategoryChanges) categories, \(passBookmarkChanges) bookmarks.")
        pass += 1
    }
        
        if totalCategoryChanges > 0 || totalBookmarkChanges > 0 {
            Logger.sync.info("✅ [SYNC] Total repair complete. Fixed \(totalCategoryChanges) categories and \(totalBookmarkChanges) bookmarks in \(pass-1) passes.")
            
            // Fix backend by uploading the repaired data
            Logger.sync.info("📤 [SYNC] Repair complete, syncing fixed data back to cloud...")
            try? await uploadToCloud()
            
            // Refresh UI
            await MainActor.run {
                NotificationCenter.default.post(name: .syncDidComplete, object: nil)
            }
        } else {
            Logger.sync.info("ℹ️ [SYNC] No encryption repair needed.")
        }
    }
    
    /// Repairs orphaned bookmarks whose categoryId points to a non-existent category.
    /// Sets their categoryId to nil so they appear in "Uncategorized".
    func repairOrphanedBookmarks() async throws {
        guard let context = modelContext else { return }
        
        let categories = try context.fetch(FetchDescriptor<Category>())
        let validCategoryIds = Set(categories.map { $0.id })
        
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        var repairedCount = 0
        
        for bookmark in bookmarks {
            if let categoryId = bookmark.categoryId, !validCategoryIds.contains(categoryId) {
                Logger.sync.warning("🔧 [SYNC] Orphaned bookmark '\(bookmark.title)' pointed to missing category \(categoryId). Setting to nil.")
                bookmark.categoryId = nil
                bookmark.updatedAt = Date()
                repairedCount += 1
            }
        }
        
        if repairedCount > 0 {
            try context.save()
            Logger.sync.info("✅ [SYNC] Repaired \(repairedCount) orphaned bookmark(s).")
        } else {
            Logger.sync.info("ℹ️ [SYNC] No orphaned bookmarks found.")
        }
    }
    
    func uploadToCloud() async throws {
        let user = await AuthService.shared.getCurrentUser()
        guard let context = modelContext,
              user != nil else {
            throw SyncError.notAuthenticated
        }

        try await uploadCategories(context: context)
        try await uploadBookmarks(context: context)
    }
    
    func syncBookmark(_ bookmark: Bookmark, fileData: Data? = nil) async throws {
        Logger.sync.info("🔄 [SYNC] Attempting to sync bookmark: \(bookmark.title) (\(bookmark.id.uuidString))")
        
        guard await AuthService.shared.getCurrentUser() != nil else {
            Logger.sync.warning("⚠️ [SYNC] Bookmark sync failed: Not authenticated")
            throw SyncError.notAuthenticated
        }

        let payload = createBookmarkPayload(bookmark)
        let jsonPayload = try encoder.encode(["bookmarks": [payload]])
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

        do {
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
        } catch {
            Logger.sync.error("❌ [SYNC] Sync failed for bookmark \(bookmark.id): \(error.localizedDescription)")
            await MainActor.run {
                self.syncError = String(localized: "sync.error.bookmark_failed")
                NotificationCenter.default.post(name: .syncDidFail, object: error.localizedDescription)
            }
            throw error
        }
        Logger.sync.info("✅ [SYNC] Successfully synced bookmark: \(bookmark.title)")
    }
    
    func syncCategory(_ category: Category) async throws {
        Logger.sync.info("🔄 [SYNC] Attempting to sync category: \(category.name) (\(category.id.uuidString))")
        
        guard await AuthService.shared.getCurrentUser() != nil else {
            Logger.sync.warning("⚠️ [SYNC] Category sync failed: Not authenticated")
            throw SyncError.notAuthenticated
        }

        let payload = createCategoryPayload(category)
        let jsonContent = try encoder.encode(["categories": [payload]])
        
        do {
            let _: [String: AnyCodable] = try await network.request(
                endpoint: APIConstants.Endpoints.categoriesUpsert,
                method: "POST",
                body: jsonContent
            )
            Logger.sync.info("✅ [SYNC] Successfully synced category: \(category.name)")
        } catch {
            Logger.sync.error("❌ [SYNC] Sync failed for category \(category.id): \(error.localizedDescription)")
            await MainActor.run {
                self.syncError = String(localized: "sync.error.category_failed")
                NotificationCenter.default.post(name: .syncDidFail, object: error.localizedDescription)
            }
            throw error
        }
    }
    
    func deleteBookmark(id: UUID) async throws {
        Logger.sync.info("🗑️ [SYNC] Attempting to delete bookmark: \(id.uuidString)")
        
        // Fast auth check
        guard defaults.string(forKey: APIConstants.Keys.token) != nil else {
            Logger.sync.warning("⚠️ [SYNC] Cannot delete bookmark: Not authenticated")
            return
        }
        
        let endpoint = "\(APIConstants.Endpoints.bookmarks)/\(id.uuidString.lowercased())"
        Logger.sync.debug("🌐 [SYNC] DELETE \(endpoint)")
        
        do {
            let _: EmptyResponse = try await network.request(
                endpoint: endpoint,
                method: "DELETE"
            )
            Logger.sync.info("✅ [SYNC] Successfully deleted bookmark from cloud: \(id.uuidString)")
        } catch {
            let errorMsg = error.localizedDescription.lowercased()
            Logger.sync.error("❌ [SYNC] Cloud delete failed for bookmark \(id.uuidString): \(error.localizedDescription)")
            
            if errorMsg.contains("404") || errorMsg.contains("no query results") || errorMsg.contains("not found") {
                Logger.sync.warning("⚠️ [SYNC] SERVER ERROR: Model not found. The server might be expecting an integer ID or looking in the wrong column despite the API docs.")
            }
            
            throw error
        }
    }
    
    func deleteCategory(id: UUID) async throws {
        Logger.sync.info("🗑️ [SYNC] Attempting to delete category: \(id.uuidString)")
        
        guard defaults.string(forKey: APIConstants.Keys.token) != nil else {
            Logger.sync.warning("⚠️ [SYNC] Cannot delete category: Not authenticated")
            return
        }
        
        let endpoint = "\(APIConstants.Endpoints.categories)/\(id.uuidString.lowercased())"
        Logger.sync.debug("🌐 [SYNC] DELETE \(endpoint)")
        
        do {
            let _: EmptyResponse = try await network.request(
                endpoint: endpoint,
                method: "DELETE"
            )
            Logger.sync.info("✅ [SYNC] Successfully deleted category from cloud: \(id.uuidString)")
        } catch {
            let errorMsg = error.localizedDescription.lowercased()
            Logger.sync.error("❌ [SYNC] Cloud delete failed for category \(id.uuidString): \(error.localizedDescription)")
            
            if errorMsg.contains("404") || errorMsg.contains("no query results") || errorMsg.contains("not found") {
                Logger.sync.warning("⚠️ [SYNC] SERVER ERROR: Model not found for category. Check server route binding.")
            }
            
            throw error
        }
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
            let serverID = cloud.id
            let localID = cloud.localId
            
            // 1. Check if record with server ID already exists
            let serverDescriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == serverID })
            if let existing = try context.fetch(serverDescriptor).first {
                updateCategory(existing, with: cloud)
                continue
            }
            
            // 2. If not found by server ID, check if it exists by local ID
            if let localID = localID, localID != serverID {
                let localDescriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == localID })
                if let existingLocal = try context.fetch(localDescriptor).first {
                    Logger.sync.info("🆔 [SYNC] Promoting category identity (Delete/Insert): \(localID) -> \(serverID)")
                    
                    // Copy data to new record with Server ID
                    let promoted = Category(
                        id: serverID,
                        name: decryptIfNeeded(cloud.name, isEncrypted: cloud.isEncrypted ?? false),
                        icon: cloud.icon,
                        colorHex: cloud.color,
                        order: cloud.order
                    )
                    promoted.bookmarksCount = cloud.bookmarksCount
                    if let cloudCreated = parseDate(cloud.createdAt) {
                        promoted.createdAt = cloudCreated
                    } else {
                        promoted.createdAt = existingLocal.createdAt
                    }
                    if let cloudUpdated = parseDate(cloud.updatedAt) {
                        promoted.updatedAt = cloudUpdated
                    }
                    
                    // Delete old and insert new
                    context.delete(existingLocal)
                    context.insert(promoted)
                    
                    // Update all bookmarks that were pointing to the old local ID
                    try updateRelationships(from: localID, to: serverID, in: context)
                    continue
                }
            }
            
            // 3. Fallback: Match by name (safeguard for missing local_id from server)
            let name = decryptIfNeeded(cloud.name, isEncrypted: cloud.isEncrypted ?? false)
            let nameDescriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.name == name })
            if let existingByName = try context.fetch(nameDescriptor).first {
                 Logger.sync.info("🆔 [SYNC] Promoting category identity by name match: '\(name)' (\(existingByName.id) -> \(serverID))")
                 
                 let promoted = Category(
                     id: serverID,
                     name: name,
                     icon: cloud.icon,
                     colorHex: cloud.color,
                     order: cloud.order
                 )
                  promoted.bookmarksCount = cloud.bookmarksCount
                  if let cloudCreated = parseDate(cloud.createdAt) {
                      promoted.createdAt = cloudCreated
                  } else {
                      promoted.createdAt = existingByName.createdAt
                  }
                  if let cloudUpdated = parseDate(cloud.updatedAt) {
                      promoted.updatedAt = cloudUpdated
                  }
                 
                 let oldID = existingByName.id
                 context.delete(existingByName)
                 context.insert(promoted)
                 
                 try updateRelationships(from: oldID, to: serverID, in: context)
                 continue
            }
            
            // 4. Not found by any means, create new
            let newCategory = Category(
                id: serverID,
                name: decryptIfNeeded(cloud.name, isEncrypted: cloud.isEncrypted ?? false),
                icon: cloud.icon,
                colorHex: cloud.color,
                order: cloud.order
            )
            newCategory.bookmarksCount = cloud.bookmarksCount
            if let cloudCreated = parseDate(cloud.createdAt) {
                newCategory.createdAt = cloudCreated
            }
            if let cloudUpdated = parseDate(cloud.updatedAt) {
                newCategory.updatedAt = cloudUpdated
            }
            
            context.insert(newCategory)
        }
    }
    
    private func updateRelationships(from oldId: UUID, to newId: UUID, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.categoryId == oldId })
        let bookmarks = try context.fetch(descriptor)
        for b in bookmarks {
            b.categoryId = newId
            b.updatedAt = Date() // Mark for upload to notify server of the link update
        }
        if !bookmarks.isEmpty {
            Logger.sync.info("🔗 [SYNC] Remapped \(bookmarks.count) bookmarks to new category ID: \(newId)")
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
            let serverID = cloud.id
            let localID = cloud.localId
            
            // 1. Check if record with server ID already exists
            let serverDescriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.id == serverID })
            if let existing = try context.fetch(serverDescriptor).first {
                if let catID = cloud.categoryId {
                    Logger.sync.debug("📝 [SYNC] Updating bookmark '\(existing.title)' - belongs to category ID: \(catID)")
                }
                updateBookmark(existing, with: cloud)
                continue
            }
            
            // 2. If not found by server ID, check if it exists by local ID
            if let localID = localID, localID != serverID {
                let localDescriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.id == localID })
                if let existingLocal = try context.fetch(localDescriptor).first {
                    Logger.sync.info("🆔 [SYNC] Promoting bookmark identity (Delete/Insert): \(localID) -> \(serverID)")
                    
                    // Copy data to new record with Server ID
                    let promoted = Bookmark(
                        title: existingLocal.title,
                        url: existingLocal.url,
                        note: existingLocal.note,
                        source: existingLocal.source
                    )
                    promoted.id = serverID
                    promoted.createdAt = existingLocal.createdAt
                    
                    if let catID = cloud.categoryId {
                        Logger.sync.debug("📝 [SYNC] Promoting bookmark '\(promoted.title)' - belongs to category ID: \(catID)")
                    }
                    
                    updateBookmark(promoted, with: cloud)
                    
                    // Delete old and insert new
                    context.delete(existingLocal)
                    context.insert(promoted)
                    continue
                }
            }
            
            // 3. Create new
            let newBookmark = Bookmark(
                title: decryptIfNeeded(cloud.title, isEncrypted: cloud.isEncrypted ?? false),
                url: decryptIfNeeded(cloud.url ?? "", isEncrypted: cloud.isEncrypted ?? false),
                note: decryptIfNeeded(cloud.note ?? "", isEncrypted: cloud.isEncrypted ?? false),
                source: BookmarkSource(rawValue: cloud.source) ?? .manual
            )
            newBookmark.id = serverID
            
            if let catID = cloud.categoryId {
                Logger.sync.debug("📝 [SYNC] Incoming bookmark '\(newBookmark.title)' belongs to category ID: \(catID)")
            }
            
            updateBookmark(newBookmark, with: cloud)
            context.insert(newBookmark)
        }
        
        Logger.sync.info("📝 [SYNC] Processed \(cloudBookmarks.count) cloud bookmarks.")
    }
    
    private func updateBookmark(_ bookmark: Bookmark, with cloud: CloudBookmark) {
        let isEncrypted = cloud.isEncrypted ?? false
        bookmark.title = decryptIfNeeded(cloud.title, isEncrypted: isEncrypted)
        bookmark.url = decryptIfNeeded(cloud.url ?? "", isEncrypted: isEncrypted)
        bookmark.note = decryptIfNeeded(cloud.note ?? "", isEncrypted: isEncrypted)
        bookmark.isRead = cloud.isRead
        bookmark.isFavorite = cloud.isFavorite
        bookmark.imageUrls = cloud.imageUrls
        bookmark.fileURL = cloud.fileUrl
        
        if let tags = cloud.tags {
            bookmark.tags = tags.map { decryptIfNeeded($0, isEncrypted: isEncrypted) }
        }
        
        if let cloudCreated = parseDate(cloud.createdAt) {
            bookmark.createdAt = cloudCreated
        }
        if let cloudUpdated = parseDate(cloud.updatedAt) {
            bookmark.updatedAt = cloudUpdated
        }
        if let categoryId = cloud.categoryId {
            bookmark.categoryId = categoryId
        }
        
        // Linked Bookmarks
        
        Logger.sync.debug("📝 [SYNC] Updated bookmark: '\(bookmark.title)' (Favorite: \(cloud.isFavorite))")
    }
    
    // MARK: - Upload Helpers
    
    private func uploadCategories(context: ModelContext) async throws {
        let localCategories = try context.fetch(FetchDescriptor<Category>())
        guard !localCategories.isEmpty else { return }

        let payloads = localCategories.map { createCategoryPayload($0) }
        
        let _: [String: AnyCodable] = try await network.request(
            endpoint: APIConstants.Endpoints.categoriesUpsert,
            method: "POST",
            body: try encoder.encode(["categories": payloads])
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
                    Logger.sync.error("❌ [SYNC] Image upload failed for bookmark \(bookmark.id): \(error)")
                    // Continue without images rather than failing the whole batch
                }
            }
            payloads.append(payload)
        }

        do {
            let _: [String: AnyCodable] = try await network.request(
                endpoint: APIConstants.Endpoints.bookmarksUpsert,
                method: "POST",
                body: try encoder.encode(["bookmarks": payloads])
            )
        } catch {
            Logger.sync.error("❌ [SYNC] Bookmarks upsert failed: \(error)")
            throw error
        }
    }

    // MARK: - Private Helpers
    
    private func canSync() async -> Bool {
        guard modelContext != nil else { return false }
        guard await AuthService.shared.getCurrentUser() != nil else { return false }
        guard NetworkMonitor.shared.isConnected else { return false }
        return syncState == .idle
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .serverError, .unexpectedStatusCode:
                return true
            case .unauthorized, .forbidden, .invalidURL, .noData, .decodingError:
                return false
            }
        }
        
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }
        
        return false
    }

    private func decryptIfNeeded(_ value: String, isEncrypted: Bool) -> String {
        guard !value.isEmpty else { return value }
        
        // Ensure key is loaded if it's not already
        if isEncrypted && !EncryptionService.shared.isKeyAvailable {
            Logger.sync.info("🔑 [SYNC] isEncrypted is true but key not available, attempting to load...")
        }
        
        // decryptOptional handles the actual decryption and is safe
        if isEncrypted || EncryptionService.shared.isKeyAvailable {
            let result = EncryptionService.shared.decryptOptional(value) ?? value
            
            if result != value {
                Logger.sync.debug("🔍 [SYNC] ✅ Decrypted: '\(value.prefix(10))...' -> '\(result.prefix(15))...'")
                
                // Detection for potential double encryption
                if result.count > 30 && Data(base64Encoded: result) != nil {
                    Logger.sync.warning("🔍 [SYNC] ⚠️ WARNING: Decrypted result still looks like ciphertext! Double encryption detected?")
                }
            } else if isEncrypted {
                Logger.sync.error("🔍 [SYNC] ❌ Expected encrypted value but decryption failed: '\(value.prefix(15))...'")
            }
            
            return result
        }
        
        return value
    }
    
    private func updateCategory(_ category: Category, with cloud: CloudCategory) {
        category.name = decryptIfNeeded(cloud.name, isEncrypted: cloud.isEncrypted ?? false)
        category.icon = cloud.icon
        category.colorHex = cloud.color
        category.order = cloud.order
        category.bookmarksCount = cloud.bookmarksCount
    }
    
    private func encryptIfNeeded(_ value: String) -> String {
        // Only encrypt if encryption key is available
        guard EncryptionService.shared.isKeyAvailable else { return value }
        // encryptOptional returns the ciphertext string directly
        return (try? EncryptionService.shared.encryptOptional(value)) ?? value
    }

    private func createBookmarkPayload(_ bookmark: Bookmark) -> [String: AnyEncodable] {
        // Check if encryption is enabled
        let shouldEncrypt = EncryptionService.shared.isKeyAvailable
        
        var payload: [String: AnyEncodable] = [
            "id": AnyEncodable(bookmark.id.uuidString.lowercased()),
            "local_id": AnyEncodable(bookmark.id.uuidString.lowercased()),
            "title": AnyEncodable(encryptIfNeeded(bookmark.title)),
            "source": AnyEncodable(bookmark.source.rawValue),
            "is_read": AnyEncodable(bookmark.isRead),
            "is_favorite": AnyEncodable(bookmark.isFavorite),
            "sync_version": AnyEncodable(0), // Default for new/updated
            "is_encrypted": AnyEncodable(shouldEncrypt),
            "created_at": AnyEncodable(bookmark.createdAt),
            "updated_at": AnyEncodable(bookmark.lastUpdated)
        ]

        if let url = bookmark.url, !url.isEmpty {
            payload["url"] = AnyEncodable(encryptIfNeeded(url))
        }
        
        if !bookmark.note.isEmpty {
            payload["note"] = AnyEncodable(encryptIfNeeded(bookmark.note))
        }
        
        if !bookmark.tags.isEmpty {
            let encryptedTags = bookmark.tags.map { encryptIfNeeded($0) }
            payload["tags"] = AnyEncodable(encryptedTags)
        }
        
        if let linkedIds = bookmark.linkedBookmarkIds, !linkedIds.isEmpty {
            payload["linked_bookmarks"] = AnyEncodable(linkedIds.map { $0.uuidString.lowercased() })
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
        // Check if encryption is enabled
        let shouldEncrypt = EncryptionService.shared.isKeyAvailable
        
        let payload: [String: AnyEncodable] = [
            "id": AnyEncodable(category.id.uuidString.lowercased()),
            "local_id": AnyEncodable(category.id.uuidString.lowercased()),
            "name": AnyEncodable(encryptIfNeeded(category.name)),
            "icon": AnyEncodable(category.icon),
            "color": AnyEncodable(category.colorHex),
            "order": AnyEncodable(category.order),
            "is_encrypted": AnyEncodable(shouldEncrypt),
            "created_at": AnyEncodable(category.createdAt),
            "updated_at": AnyEncodable(category.lastUpdated)
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
        case .notAuthenticated: return String(localized: "sync.error.not_authenticated")
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
    static let bookmarkDidUpdate = Notification.Name("bookmarkDidUpdate")
}
