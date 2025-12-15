//
//  ImageUploadService.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//
//  Bookmark görsellerini Supabase Storage'a yükler
//  - Resim sıkıştırma
//  - Thumbnail oluşturma
//  - Batch upload
//  - Cache yönetimi
//

import Foundation
import UIKit
import CryptoKit
internal import Combine

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
    
    // MARK: - Dependencies
    
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var storage: StorageFileApi { client.storage.from(bucketName) }
    
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
        print("🖼️ [IMAGE] ImageUploadService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Tek bir görseli yükle
    /// - Parameters:
    ///   - image: Yüklenecek UIImage
    ///   - bookmarkId: Bookmark UUID
    ///   - index: Görsel indexi (birden fazla görsel için)
    /// - Returns: Yüklenen görselin public URL'i
    func uploadImage(_ image: UIImage, for bookmarkId: UUID, index: Int = 0) async throws -> String {
        guard let userId = SupabaseManager.shared.userId else {
            throw ImageUploadError.notAuthenticated
        }
        
        isUploading = true
        uploadProgress = 0
        lastError = nil
        
        defer { isUploading = false }
        
        print("🖼️ [IMAGE] Uploading image for bookmark: \(bookmarkId)")
        
        // 1. Görseli optimize et
        guard let optimizedData = optimizeImage(image) else {
            throw ImageUploadError.compressionFailed
        }
        
        print("   Original: \(image.size), Optimized: \(optimizedData.count) bytes")
        
        // 2. Boyut kontrolü
        guard optimizedData.count <= maxImageSize else {
            throw ImageUploadError.fileTooLarge(optimizedData.count, maxImageSize)
        }
        
        uploadProgress = 0.3
        
        // 3. Dosya yolunu oluştur
        let fileName = "\(index)_\(UUID().uuidString.prefix(8)).jpg"
        let filePath = "\(userId.uuidString)/\(bookmarkId.uuidString)/\(fileName)"
        
        print("   Path: \(filePath)")
        
        // 4. Storage'a yükle
        do {
            try await storage.upload(
                filePath,
                data: optimizedData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )
            
            uploadProgress = 0.8
            
            // 5. Public URL al
            let publicURL = try storage.getPublicURL(path: filePath)
            
            uploadProgress = 1.0
            
            print("✅ [IMAGE] Uploaded: \(publicURL.absoluteString)")
            
            // 6. Cache'e ekle
            cacheImage(image, for: publicURL.absoluteString)
            
            return publicURL.absoluteString
            
        } catch {
            print("❌ [IMAGE] Upload failed: \(error)")
            lastError = .uploadFailed(error.localizedDescription)
            throw ImageUploadError.uploadFailed(error.localizedDescription)
        }
    }
    
    /// Birden fazla görseli yükle
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
    
    /// URL'den görsel yükle (Twitter, Reddit vs. için)
    func uploadImageFromURL(_ urlString: String, for bookmarkId: UUID, index: Int = 0) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ImageUploadError.invalidURL
        }
        
        print("🖼️ [IMAGE] Downloading from URL: \(urlString)")
        
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
        
        print("🖼️ [IMAGE] Creating thumbnail for: \(bookmarkId)")
        
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
        
        let publicURL = try storage.getPublicURL(path: filePath)
        
        print("✅ [IMAGE] Thumbnail uploaded: \(publicURL.absoluteString)")
        
        return publicURL.absoluteString
    }
    
    /// Bookmark için tüm görselleri sil
    func deleteImages(for bookmarkId: UUID) async throws {
        guard let userId = SupabaseManager.shared.userId else {
            throw ImageUploadError.notAuthenticated
        }
        
        let folderPath = "\(userId.uuidString)/\(bookmarkId.uuidString)"
        
        print("🗑️ [IMAGE] Deleting images at: \(folderPath)")
        
        do {
            // Klasördeki dosyaları listele
            let files = try await storage.list(path: folderPath)
            
            if files.isEmpty {
                print("ℹ️ [IMAGE] No images to delete")
                return
            }
            
            // Dosyaları sil
            let filePaths = files.map { "\(folderPath)/\($0.name)" }
            try await storage.remove(paths: filePaths)
            
            print("✅ [IMAGE] Deleted \(files.count) images")
            
            // Cache'den de sil
            for file in files {
                let url = try storage.getPublicURL(path: "\(folderPath)/\(file.name)")
                removeCachedImage(for: url.absoluteString)
            }
            
        } catch {
            print("❌ [IMAGE] Delete failed: \(error)")
            throw ImageUploadError.deleteFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Image Loading (with Cache)
    
    /// Görseli yükle (cache'den veya network'ten)
    func loadImage(from urlString: String) async -> UIImage? {
        // 1. Memory cache kontrol
        if let cached = cache.object(forKey: urlString as NSString) {
            return cached
        }
        
        // 2. Disk cache kontrol
        if let diskCached = loadFromDiskCache(urlString: urlString) {
            cache.setObject(diskCached, forKey: urlString as NSString)
            return diskCached
        }
        
        // 3. Network'ten indir
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let image = UIImage(data: data) else { return nil }
            
            // Cache'e kaydet
            cacheImage(image, for: urlString)
            saveToDiskCache(data: data, urlString: urlString)
            
            return image
            
        } catch {
            print("❌ [IMAGE] Load failed: \(error)")
            return nil
        }
    }
    
    /// Cache'i temizle
    func clearCache() {
        cache.removeAllObjects()
        
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        print("🧹 [IMAGE] Cache cleared")
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

import SwiftUI

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
