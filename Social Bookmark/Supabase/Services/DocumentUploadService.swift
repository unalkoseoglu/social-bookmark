import Foundation
import Supabase
import OSLog
internal import Combine

/// Doküman yükleme servisi (PDF, Word, vb.)
@MainActor
final class DocumentUploadService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DocumentUploadService()
    
    // MARK: - Published Properties
    
    @Published private(set) var uploadProgress: Double = 0
    @Published private(set) var isUploading = false
    @Published private(set) var lastError: Error?
    
    // MARK: - Configuration
    
    private let bucketName = "bookmark-documents"
    private let maxDocSize: Int = 10 * 1024 * 1024  // 10MB
    private let signedURLExpiration: Int = 3600 // 1 saat
    
    // MARK: - Dependencies
    
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var storage: StorageFileApi { client.storage.from(bucketName) }
    
    // MARK: - Initialization
    
    private init() {
        Logger.network.info("DocumentUploadService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Doküman yükle
    /// - Parameters:
    ///   - data: Yüklenecek dosya verisi
    ///   - fileName: Dosya adı
    ///   - bookmarkId: Bookmark UUID
    /// - Returns: Yüklenen dosyanın Storage path'i
    func uploadDocument(_ data: Data, fileName: String, for bookmarkId: UUID) async throws -> String {
        guard let userId = SupabaseManager.shared.userId else {
            throw DocumentUploadError.notAuthenticated
        }
        
        isUploading = true
        uploadProgress = 0
        lastError = nil
        
        defer { isUploading = false }
        
        Logger.network.info("Uploading document: \(fileName) for bookmark: \(bookmarkId)")
        
        // Boyut kontrolü
        guard data.count <= maxDocSize else {
            throw DocumentUploadError.fileTooLarge(data.count, maxDocSize)
        }
        
        uploadProgress = 0.2
        
        // Dosya yolunu oluştur
        let sanitizedFileName = sanitizeFileName(fileName)
        let filePath = "\(userId.uuidString)/\(bookmarkId.uuidString)/\(sanitizedFileName)"
        
        // Storage'a yükle
        do {
            try await storage.upload(
                filePath,
                data: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "application/pdf", // Varsayılan, yüklenecek dosyaya göre değişebilir
                    upsert: true
                )
            )
            
            uploadProgress = 1.0
            Logger.network.info("Document upload successful: \(filePath)")
            return filePath
            
        } catch {
            Logger.network.error("Document upload failed: \(error)")
            lastError = error
            throw error
        }
    }
    
    /// Private bucket için signed URL al
    func getSignedURL(for path: String) async -> URL? {
        do {
            let signedURL = try await storage.createSignedURL(
                path: path,
                expiresIn: signedURLExpiration
            )
            return signedURL
        } catch {
            print("❌ [DocumentUpload] Failed to create signed URL: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Dokümanı sil
    func deleteDocument(path: String) async throws {
        try await storage.remove(paths: [path])
        Logger.network.info("Document deleted: \(path)")
    }
    
    // MARK: - Private Methods
    
    private func sanitizeFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        return name.components(separatedBy: allowed.inverted).joined(separator: "_")
    }
}

// MARK: - Error Types

enum DocumentUploadError: LocalizedError {
    case notAuthenticated
    case fileTooLarge(Int, Int)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Doküman yüklemek için giriş yapmanız gerekiyor"
        case .fileTooLarge(let size, let max):
            let sizeMB = Double(size) / 1024 / 1024
            let maxMB = Double(max) / 1024 / 1024
            return String(format: "Dosya çok büyük (%.1fMB). Maksimum: %.1fMB", sizeMB, maxMB)
        }
    }
}
