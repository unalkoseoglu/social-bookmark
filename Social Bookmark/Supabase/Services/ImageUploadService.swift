//
//  ImageUploadService.swift
//  Social Bookmark
//
//  ✅ DÜZELTME: Private bucket için signed URL desteği
//  - loadImage(): Path veya URL'yi destekler
//  - getSignedURL(): Private bucket'tan signed URL alır
//

import Foundation
import Supabase
import UIKit
import CryptoKit
internal import Combine
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
    
    private let bucketName = "bookmark-images"
    private let maxImageSize: Int = 5 * 1024 * 1024  // 5MB
    private let thumbnailSize: CGSize = CGSize(width: 300, height: 300)
    private let fullImageMaxDimension: CGFloat = 1920
    private let compressionQuality: CGFloat = 0.8
    private let signedURLExpiration: Int = 3600 // 1 saat
    
    // MARK: - Dependencies
    
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var storage: StorageFileApi { client.storage.from(bucketName) }
    
    // MARK: - Cache
    
    private let cache = NSCache<NSString, UIImage>()
    private let signedURLCache = NSCache<NSString, NSString>()  // ✅ Signed URL cache
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
        signedURLCache.countLimit = 200
        Logger.network.info("ImageUploadService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Tek bir görseli yükle
    /// - Parameters:
    ///   - image: Yüklenecek UIImage
    ///   - bookmarkId: Bookmark UUID
    ///   - index: Görsel indexi (birden fazla görsel için)
    /// - Returns: Yüklenen görselin Storage path'i (NOT: full URL değil!)
    func uploadImage(_ image: UIImage, for bookmarkId: UUID, index: Int = 0) async throws -> String {
        guard let userId = SupabaseManager.shared.userId else {
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
        
        // 3. Dosya yolunu oluştur
        let fileName = "\(index)_\(UUID().uuidString.prefix(8)).jpg"
        let filePath = "\(userId.uuidString)/\(bookmarkId.uuidString)/\(fileName)"
        
        Logger.network.debug("Path: \(filePath)")
        
        // 4. Storage'a yükle
        do {
            print("📤 [ImageUpload] Uploading \(optimizedData.count / 1024) KB to: \(filePath)")
            
            try await storage.upload(
                filePath,
                data: optimizedData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )
            
            uploadProgress = 1.0
            
            print("✅ [ImageUpload] Upload successful: \(filePath)")
            
            // ✅ Private bucket için sadece path döndür (URL değil!)
            return filePath
            
        } catch {
            print("❌ [ImageUpload] Upload failed: \(error)")
            Logger.network.error("Upload failed: \(error)")
            lastError = .uploadFailed(error.localizedDescription)
            throw ImageUploadError.uploadFailed(error.localizedDescription)
        }
    }
    
    /// Birden fazla görseli yükle
    func uploadImages(_ images: [UIImage], for bookmarkId: UUID) async throws -> [String] {
        var paths: [String] = []
        
        for (index, image) in images.enumerated() {
            uploadProgress = Double(index) / Double(images.count)
            
            let path = try await uploadImage(image, for: bookmarkId, index: index)
            paths.append(path)
        }
        
        uploadProgress = 1.0
        return paths
    }
    
    /// URL'den görsel yükle (Twitter, Reddit vs. için)
    func uploadImageFromURL(_ urlString: String, for bookmarkId: UUID, index: Int = 0) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ImageUploadError.invalidURL
        }
        
        Logger.network.info("Downloading from URL: \(urlString)")
        
        // Görseli indir
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageUploadError.downloadFailed
        }
        
        guard let image = UIImage(data: data) else {
            throw ImageUploadError.invalidImageData
        }
        
        // Storage'a yükle
        return try await uploadImage(image, for: bookmarkId, index: index)
    }
    
    /// Thumbnail oluştur ve yükle
    func uploadThumbnail(_ image: UIImage, for bookmarkId: UUID) async throws -> String {
        guard let userId = SupabaseManager.shared.userId else {
            throw ImageUploadError.notAuthenticated
        }
        
        Logger.network.info("Creating thumbnail for: \(bookmarkId)")
        
        // Thumbnail oluştur
        guard let thumbnail = createThumbnail(from: image),
              let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
            throw ImageUploadError.thumbnailCreationFailed
        }
        
        // Yükle
        let filePath = "\(userId.uuidString)/\(bookmarkId.uuidString)/thumbnail.jpg"
        
        try await storage.upload(
            filePath,
            data: thumbnailData,
            options: FileOptions(
                cacheControl: "86400", // 1 gün
                contentType: "image/jpeg",
                upsert: true
            )
        )
        
        Logger.network.info("Thumbnail uploaded: \(filePath)")
        
        return filePath
    }
    
    /// Bookmark için tüm görselleri sil
    func deleteImages(for bookmarkId: UUID) async throws {
        guard let userId = SupabaseManager.shared.userId else {
            throw ImageUploadError.notAuthenticated
        }
        
        let folderPath = "\(userId.uuidString)/\(bookmarkId.uuidString)"
        
        Logger.network.info("Deleting images at: \(folderPath)")
        
        do {
            // Klasördeki dosyaları listele
            let files = try await storage.list(path: folderPath)
            
            if files.isEmpty {
                Logger.network.info("No images to delete")
                return
            }
            
            // Dosyaları sil
            let filePaths = files.map { "\(folderPath)/\($0.name)" }
            try await storage.remove(paths: filePaths)
            
            Logger.network.info("Deleted \(files.count) images")
            
            // Cache'den de sil
            for file in files {
                let path = "\(folderPath)/\(file.name)"
                removeCachedImage(for: path)
            }
            
        } catch {
            Logger.network.error("Delete failed: \(error)")
            throw ImageUploadError.deleteFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Image Loading (with Cache & Signed URL)
    
    /// ✅ DÜZELTME: Storage path veya URL'den görsel yükle
    /// - Parameter pathOrUrl: Storage path (örn: "userId/bookmarkId/0_xxx.jpg") veya tam URL
    /// - Returns: Yüklenen UIImage veya nil
    func loadImage(from pathOrUrl: String) async -> UIImage? {
        print("🖼️ [ImageUpload] loadImage called with: \(pathOrUrl.prefix(60))...")
        
        // 1. Memory cache kontrol
        if let cached = cache.object(forKey: pathOrUrl as NSString) {
            print("   ✅ Found in memory cache")
            return cached
        }
        
        // 2. Disk cache kontrol
        if let diskCached = loadFromDiskCache(urlString: pathOrUrl) {
            cache.setObject(diskCached, forKey: pathOrUrl as NSString)
            print("   ✅ Found in disk cache")
            return diskCached
        }
        
        // 3. URL mi yoksa path mi belirle
        let isFullURL = pathOrUrl.hasPrefix("http://") || pathOrUrl.hasPrefix("https://")
        
        var downloadURL: URL?
        
        if isFullURL {
            // Zaten tam URL
            downloadURL = URL(string: pathOrUrl)
            print("   📍 Using as direct URL")
        } else {
            // Storage path - Signed URL al
            print("   📍 Getting signed URL for path...")
            if let signedURL = await getSignedURL(for: pathOrUrl) {
                downloadURL = signedURL
                print("   ✅ Got signed URL")
            } else {
                print("   ❌ Failed to get signed URL")
                return nil
            }
        }
        
        guard let url = downloadURL else {
            print("   ❌ Invalid URL")
            return nil
        }
        
        // 4. Network'ten indir
        do {
            print("   ⬇️ Downloading from: \(url.absoluteString.prefix(80))...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("   ❌ Invalid response")
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                print("   ❌ HTTP \(httpResponse.statusCode)")
                return nil
            }
            
            guard let image = UIImage(data: data) else {
                print("   ❌ Invalid image data")
                return nil
            }
            
            // Cache'e kaydet (path ile, URL ile değil)
            cacheImage(image, for: pathOrUrl)
            saveToDiskCache(data: data, urlString: pathOrUrl)
            
            print("   ✅ Downloaded and cached successfully")
            return image
            
        } catch {
            print("   ❌ Download error: \(error.localizedDescription)")
            Logger.network.error("Load failed: \(error)")
            return nil
        }
    }
    
    /// ✅ Private bucket için signed URL al
    /// - Parameter path: Storage dosya yolu
    /// - Returns: Signed URL veya nil
    func getSignedURL(for path: String) async -> URL? {
        // Cache kontrol
        if let cachedURL = signedURLCache.object(forKey: path as NSString) {
            if let url = URL(string: cachedURL as String) {
                return url
            }
        }
        
        do {
            let signedURL = try await storage.createSignedURL(
                path: path,
                expiresIn: signedURLExpiration
            )
            
            // Cache'e kaydet
            signedURLCache.setObject(signedURL.absoluteString as NSString, forKey: path as NSString)
            
            return signedURL
        } catch {
            print("❌ [ImageUpload] Failed to create signed URL: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// ✅ Birden fazla path için signed URL'ler al
    func getSignedURLs(for paths: [String]) async -> [String: URL] {
        var result: [String: URL] = [:]
        
        for path in paths {
            if let url = await getSignedURL(for: path) {
                result[path] = url
            }
        }
        
        return result
    }
    
    /// Cache'i temizle
    func clearCache() {
        cache.removeAllObjects()
        signedURLCache.removeAllObjects()
        
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        Logger.network.info("Cache cleared")
    }
    
    /// Cache boyutunu hesapla
    func getCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for file in files {
            let filePath = cacheDirectory.appendingPathComponent(file).path
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return totalSize
    }
    
    // MARK: - Private Methods
    
    /// Görseli optimize et (boyut küçült + sıkıştır)
    private func optimizeImage(_ image: UIImage) -> Data? {
        // Boyutu kontrol et ve gerekirse küçült
        var targetImage = image
        
        let maxDim = max(image.size.width, image.size.height)
        if maxDim > fullImageMaxDimension {
            let scale = fullImageMaxDimension / maxDim
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            targetImage = resizeImage(image, to: newSize) ?? image
        }
        
        // JPEG olarak sıkıştır
        return targetImage.jpegData(compressionQuality: compressionQuality)
    }
    
    /// Görseli yeniden boyutlandır
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// Thumbnail oluştur
    private func createThumbnail(from image: UIImage) -> UIImage? {
        let aspectRatio = image.size.width / image.size.height
        
        var targetSize: CGSize
        if aspectRatio > 1 {
            // Landscape
            targetSize = CGSize(width: thumbnailSize.width, height: thumbnailSize.width / aspectRatio)
        } else {
            // Portrait
            targetSize = CGSize(width: thumbnailSize.height * aspectRatio, height: thumbnailSize.height)
        }
        
        return resizeImage(image, to: targetSize)
    }
    
    /// Memory cache'e ekle
    private func cacheImage(_ image: UIImage, for urlString: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Approximate memory
        cache.setObject(image, forKey: urlString as NSString, cost: cost)
    }
    
    /// Memory cache'den sil
    private func removeCachedImage(for urlString: String) {
        cache.removeObject(forKey: urlString as NSString)
        signedURLCache.removeObject(forKey: urlString as NSString)
        
        // Disk cache'den de sil
        let cacheKey = sha256(urlString)
        let filePath = cacheDirectory.appendingPathComponent(cacheKey)
        try? fileManager.removeItem(at: filePath)
    }
    
    /// Disk cache'e kaydet
    private func saveToDiskCache(data: Data, urlString: String) {
        let cacheKey = sha256(urlString)
        let filePath = cacheDirectory.appendingPathComponent(cacheKey)
        try? data.write(to: filePath)
    }
    
    /// Disk cache'den yükle
    private func loadFromDiskCache(urlString: String) -> UIImage? {
        let cacheKey = sha256(urlString)
        let filePath = cacheDirectory.appendingPathComponent(cacheKey)
        
        guard let data = try? Data(contentsOf: filePath) else { return nil }
        return UIImage(data: data)
    }
    
    /// SHA256 hash
    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Error Types

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
        case .notAuthenticated:
            return "Görsel yüklemek için giriş yapmanız gerekiyor"
        case .invalidURL:
            return "Geçersiz görsel URL'i"
        case .invalidImageData:
            return "Görsel verisi okunamadı"
        case .compressionFailed:
            return "Görsel sıkıştırılamadı"
        case .thumbnailCreationFailed:
            return "Thumbnail oluşturulamadı"
        case .fileTooLarge(let size, let max):
            let sizeMB = Double(size) / 1024 / 1024
            let maxMB = Double(max) / 1024 / 1024
            return String(format: "Görsel çok büyük (%.1fMB). Maksimum: %.1fMB", sizeMB, maxMB)
        case .uploadFailed(let reason):
            return "Yükleme başarısız: \(reason)"
        case .downloadFailed:
            return "Görsel indirilemedi"
        case .deleteFailed(let reason):
            return "Silme başarısız: \(reason)"
        }
    }
}

// MARK: - SwiftUI Image Loader

/// AsyncImage benzeri ama cache destekli
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    
    let url: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        guard let url, !isLoading else { return }
        
        isLoading = true
        image = await ImageUploadService.shared.loadImage(from: url)
        isLoading = false
    }
}

// Convenience initializer
extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: String?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content) {
            ProgressView()
        }
    }
}
