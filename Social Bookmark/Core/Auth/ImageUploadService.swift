import Foundation
import UIKit
import CryptoKit
import Combine
import SwiftUI
import OSLog

/// Görsel yükleme servisi
@MainActor
final class ImageUploadService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ImageUploadService()
    
    // MARK: - Published Properties
    
    @Published private(set) var uploadProgress: Double = 0
    @Published private(set) var isUploading = false
    @Published private(set) var lastError: ImageUploadError?
    
    // MARK: - Configuration
    
    private let maxImageSize: Int = 5 * 1024 * 1024  // 5MB
    private let thumbnailSize: CGSize = CGSize(width: 300, height: 300)
    private let fullImageMaxDimension: CGFloat = 1920
    private let compressionQuality: CGFloat = 0.8
    
    // MARK: - Dependencies
    
    private var network: NetworkManager { NetworkManager.shared }
    
    // MARK: - Cache
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private var _cacheDirectory: URL?
    
    private var cacheDirectory: URL {
        if let dir = _cacheDirectory {
            return dir
        }
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("BookmarkImages")
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        _cacheDirectory = cacheDir
        return cacheDir
    }
    
    // MARK: - Initialization
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        Logger.network.info("ImageUploadService initialized")
    }
    
    // MARK: - Public Methods
    
    func uploadImage(_ image: UIImage, for bookmarkId: UUID, index: Int = 0) async throws -> String {
        guard await AuthService.shared.getCurrentUser() != nil else {
            throw ImageUploadError.notAuthenticated
        }
        
        isUploading = true
        uploadProgress = 0
        lastError = nil
        
        defer { isUploading = false }
        
        Logger.network.info("Uploading image for bookmark: \(bookmarkId)")
        
        // 1. Görseli optimize et
        guard let optimizedData = optimizeImage(image) else {
            throw ImageUploadError.compressionFailed
        }
        
        // 2. Boyut kontrolü
        guard optimizedData.count <= maxImageSize else {
            throw ImageUploadError.fileTooLarge(optimizedData.count, maxImageSize)
        }
        
        uploadProgress = 0.3
        
        let fileName = "\(index)_\(UUID().uuidString.prefix(8)).jpg"
        
        // 4. API'ya yükle
        do {
            print("📤 [ImageUpload] Uploading \(optimizedData.count / 1024) KB to Laravel API")
            
            let response: MediaUploadResponse = try await network.upload(
                endpoint: APIConstants.Endpoints.upload,
                files: [.init(
                    data: optimizedData,
                    fileName: fileName,
                    mimeType: "image/jpeg",
                    fieldName: "file"
                )]
            )
            
            uploadProgress = 1.0
            print("✅ [ImageUpload] Upload successful: \(response.url)")
            return response.url
            
        } catch {
            print("❌ [ImageUpload] Upload failed: \(error)")
            Logger.network.error("Upload failed: \(error)")
            lastError = .uploadFailed(error.localizedDescription)
            throw ImageUploadError.uploadFailed(error.localizedDescription)
        }
    }
    
    func uploadImages(_ images: [UIImage], for bookmarkId: UUID) async throws -> [String] {
        var urls: [String] = []
        for (index, image) in images.enumerated() {
            uploadProgress = Double(index) / Double(images.count)
            let url = try await uploadImage(image, for: bookmarkId, index: index)
            urls.append(url)
        }
        uploadProgress = 1.0
        return urls
    }
    
    func uploadImageFromURL(_ urlString: String, for bookmarkId: UUID, index: Int = 0) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ImageUploadError.invalidURL
        }
        
        Logger.network.info("Downloading from URL: \(urlString)")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageUploadError.downloadFailed
        }
        
        guard let image = UIImage(data: data) else {
            throw ImageUploadError.invalidImageData
        }
        
        return try await uploadImage(image, for: bookmarkId, index: index)
    }
    
    func uploadThumbnail(_ image: UIImage, for bookmarkId: UUID) async throws -> String {
        guard await AuthService.shared.getCurrentUser() != nil else {
            throw ImageUploadError.notAuthenticated
        }
        
        Logger.network.info("Creating thumbnail for: \(bookmarkId)")
        
        guard let thumbnail = createThumbnail(from: image),
              let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
            throw ImageUploadError.thumbnailCreationFailed
        }
        
        let response: MediaUploadResponse = try await network.upload(
            endpoint: APIConstants.Endpoints.upload,
            files: [.init(
                data: thumbnailData,
                fileName: "thumbnail_\(bookmarkId.uuidString).jpg",
                mimeType: "image/jpeg",
                fieldName: "file"
            )]
        )
        
        Logger.network.info("Thumbnail uploaded: \(response.url)")
        return response.url
    }
    
    func deleteImages(for bookmarkId: UUID) async throws {
        print("ℹ️ [ImageUpload] deleteImages called - server handles this on bookmark deletion")
    }
    
    func loadImage(from pathOrUrl: String) async -> UIImage? {
        if let cached = cache.object(forKey: pathOrUrl as NSString) {
            return cached
        }
        
        if let diskCached = loadFromDiskCache(urlString: pathOrUrl) {
            cache.setObject(diskCached, forKey: pathOrUrl as NSString)
            return diskCached
        }
        
        // Validation: Must be a valid HTTP URL
        guard pathOrUrl.lowercased().hasPrefix("http"),
              let url = URL(string: pathOrUrl) else { 
            return nil 
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            guard let image = UIImage(data: data) else { return nil }
            
            cacheImage(image, for: pathOrUrl)
            saveToDiskCache(data: data, urlString: pathOrUrl)
            return image
        } catch {
            Logger.network.error("Load failed: \(error)")
            return nil
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        Logger.network.info("Cache cleared")
    }
    
    func getCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path) else { return 0 }
        var totalSize: Int64 = 0
        for file in files {
            let filePath = cacheDirectory.appendingPathComponent(file).path
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath), let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }
    
    private func optimizeImage(_ image: UIImage) -> Data? {
        var targetImage = image
        let maxDim = max(image.size.width, image.size.height)
        if maxDim > fullImageMaxDimension {
            let scale = fullImageMaxDimension / maxDim
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            targetImage = resizeImage(image, to: newSize) ?? image
        }
        return targetImage.jpegData(compressionQuality: compressionQuality)
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func createThumbnail(from image: UIImage) -> UIImage? {
        let aspectRatio = image.size.width / image.size.height
        var targetSize: CGSize
        if aspectRatio > 1 {
            targetSize = CGSize(width: thumbnailSize.width, height: thumbnailSize.width / aspectRatio)
        } else {
            targetSize = CGSize(width: thumbnailSize.height * aspectRatio, height: thumbnailSize.height)
        }
        return resizeImage(image, to: targetSize)
    }
    
    private func cacheImage(_ image: UIImage, for urlString: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: urlString as NSString, cost: cost)
    }
    
    private func saveToDiskCache(data: Data, urlString: String) {
        let cacheKey = sha256(urlString)
        let filePath = cacheDirectory.appendingPathComponent(cacheKey)
        try? data.write(to: filePath)
    }
    
    private func loadFromDiskCache(urlString: String) -> UIImage? {
        let cacheKey = sha256(urlString)
        let filePath = cacheDirectory.appendingPathComponent(cacheKey)
        guard let data = try? Data(contentsOf: filePath) else { return nil }
        return UIImage(data: data)
    }
    
    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

enum ImageUploadError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidImageData
    case compressionFailed
    case thumbnailCreationFailed
    case fileTooLarge(Int, Int)
    case uploadFailed(String)
    case downloadFailed
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Görsel yüklemek için giriş yapmanız gerekiyor"
        case .invalidURL: return "Geçersiz görsel URL'i"
        case .invalidImageData: return "Görsel verisi okunamadı"
        case .compressionFailed: return "Görsel sıkıştırılamadı"
        case .thumbnailCreationFailed: return "Thumbnail oluşturulamadı"
        case .fileTooLarge(let size, let max):
            let sizeMB = Double(size) / 1024 / 1024
            let maxMB = Double(max) / 1024 / 1024
            return String(format: "Görsel çok büyük (%.1fMB). Maksimum: %.1fMB", sizeMB, maxMB)
        case .uploadFailed(let reason): return "Yükleme başarısız: \(reason)"
        case .downloadFailed: return "Görsel indirilemedi"
        case .deleteFailed(let reason): return "Silme başarısız: \(reason)"
        }
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let failure: () -> Failure
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var hasFailed = false
    
    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.failure = failure
    }
    
    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else if hasFailed {
                failure()
            } else {
                placeholder()
                    .task { await loadImage() }
            }
        }
    }
    
    private func loadImage() async {
        guard let url, !isLoading else { return }
        isLoading = true
        hasFailed = false
        
        if let loadedImage = await ImageUploadService.shared.loadImage(from: url) {
            image = loadedImage
            hasFailed = false
        } else {
            hasFailed = true
        }
        
        isLoading = false
    }
}

extension CachedAsyncImage where Failure == Placeholder {
    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(url: url, content: content, placeholder: placeholder, failure: placeholder)
    }
}

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView>, Failure == ProgressView<EmptyView, EmptyView> {
    init(url: String?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content) { ProgressView() }
    }
}
