import Foundation
import UIKit
import OSLog
import Combine

/// Doküman yükleme servisi
@MainActor
final class DocumentUploadService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DocumentUploadService()
    
    // MARK: - Published Properties
    
    @Published private(set) var uploadProgress: Double = 0
    @Published private(set) var isUploading = false
    @Published private(set) var lastError: DocumentUploadError?
    
    // MARK: - Dependencies
    
    private var network: NetworkManager { NetworkManager.shared }
    
    // MARK: - Configuration
    
    private let maxFileSize: Int = 20 * 1024 * 1024 // 20MB
    
    // MARK: - Initialization
    
    private init() {
        Logger.network.info("DocumentUploadService initialized")
    }
    
    // MARK: - Public Methods
    
    func uploadDocument(data: Data, fileName: String, mimeType: String, for bookmarkId: UUID) async throws -> String {
        guard await AuthService.shared.getCurrentUser() != nil else {
            throw DocumentUploadError.notAuthenticated
        }
        
        // Boyut kontrolü
        guard data.count <= maxFileSize else {
            throw DocumentUploadError.fileTooLarge(data.count, maxFileSize)
        }
        
        isUploading = true
        uploadProgress = 0.1
        lastError = nil
        
        defer { isUploading = false }
        
        Logger.network.info("Uploading document for bookmark: \(bookmarkId)")
        
        do {
            print("📤 [DocumentUpload] Uploading \(data.count / 1024) KB to Laravel API")
            
            let response: MediaUploadResponse = try await network.upload(
                endpoint: APIConstants.Endpoints.upload,
                files: [.init(
                    data: data,
                    fileName: fileName,
                    mimeType: mimeType,
                    fieldName: "file"
                )]
            )
            
            uploadProgress = 1.0
            print("✅ [DocumentUpload] Upload successful: \(response.url)")
            return response.url
            
        } catch {
            print("❌ [DocumentUpload] Upload failed: \(error)")
            Logger.network.error("Upload failed: \(error)")
            lastError = .uploadFailed(error.localizedDescription)
            throw DocumentUploadError.uploadFailed(error.localizedDescription)
        }
    }
    
    func deleteDocument(for bookmarkId: UUID) async throws {
         print("ℹ️ [DocumentUpload] deleteDocument called - server handles this on bookmark deletion")
    }
    
    func getSignedURL(for path: String) async -> URL? {
        // Laravel handles media access differently. For now, assume it returns direct URLs.
        return URL(string: path)
    }
}

enum DocumentUploadError: LocalizedError {
    case notAuthenticated
    case fileTooLarge(Int, Int)
    case uploadFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Dosya yüklemek için giriş yapmanız gerekiyor"
        case .fileTooLarge(let size, let max):
            let sizeMB = Double(size) / 1024 / 1024
            let maxMB = Double(max) / 1024 / 1024
            return String(format: "Dosya çok büyük (%.1fMB). Maksimum: %.1fMB", sizeMB, maxMB)
        case .uploadFailed(let reason): return "Yükleme başarısız: \(reason)"
        case .deleteFailed(let reason): return "Silme başarısız: \(reason)"
        }
    }
}
