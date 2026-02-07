import SwiftData
import Foundation

/// Ana veri modeli - Her kaydedilen bookmark'ı temsil eder
/// @Model macro: SwiftData'ya bu bir veritabanı entity'si olduğunu söyler
@Model
final class Bookmark {
    // MARK: - Properties
    
    /// Benzersiz tanımlayıcı (Primary Key gibi)
    @Attribute(.unique) var id: UUID
    
    /// Bookmark başlığı (zorunlu)
    var title: String
    
    /// İçeriğin URL'i (opsiyonel - screenshot için link olmayabilir)
    var url: String?
    
    /// Kullanıcının kişisel notu
    var note: String
    
    /// İçeriğin kaynağı (Twitter, Medium, vs.)
    var source: BookmarkSource
    
    /// Oluşturulma tarihi - otomatik set edilir
    var createdAt: Date
    
    /// Güncellenme tarihi (YENİ - Sync için) - Migration için opsiyonel yaptık
    var updatedAt: Date?
    
    /// Okundu mu? - Reading tracker için
    var isRead: Bool
    
    /// Favori mi? - Hızlı erişim için (YENİ)
    var isFavorite: Bool
    
    /// Kategori ID - Klasörleme için (YENİ)
    var categoryId: UUID?
    
    /// Etiketler - kategorize etmek için
    var tags: [String]
    
    /// Tek fotoğraf (geriye uyumluluk için) - Data olarak saklanır
    @Attribute(.externalStorage) var imageData: Data?
    
    /// Çoklu fotoğraflar (YENİ) - Twitter gibi platformlar için
    @Attribute(.externalStorage) var imagesData: [Data]?
    
    /// OCR ile çıkarılan metin
    var extractedText: String?
    
    /// Cloud storage'daki görsel URL/path'leri (sync için)
    var imageUrls: [String]?
    
    /// Doküman bilgileri (YENİ)
    var fileURL: String?      // Supabase Storage path
    var fileName: String?     // Orijinal dosya adı
    var fileExtension: String? // pdf, docx, etc.
    var fileSize: Int64?      // Byte cinsinden boyut
    
    /// Bağlantılı bookmark ID'leri (YENİ - MVP)
    var linkedBookmarkIds: [UUID]? = []
    
    /// Transient data (sadece sync sırasında kullanılır, veritabanına kaydedilmez)
    @Transient var fileData: Data?
    
    // MARK: - Initialization
    
    /// Yeni bookmark oluştururken kullanılır
    init(
            title: String,
            url: String? = nil,
            note: String = "",
            source: BookmarkSource = .other,
            isRead: Bool = false,
            isFavorite: Bool = false,
            categoryId: UUID? = nil,
            tags: [String] = [],
            imageData: Data? = nil,
            imagesData: [Data]? = nil,
            extractedText: String? = nil,
            imageUrls: [String]? = nil,
            fileURL: String? = nil,
            fileName: String? = nil,
            fileExtension: String? = nil,
            fileSize: Int64? = nil,
            linkedBookmarkIds: [UUID]? = []
        ) {
            self.id = UUID()
            self.title = title
            self.url = url
            self.note = note
            self.source = source
            self.createdAt = Date()
            self.updatedAt = Date()
            self.isRead = isRead
            self.isFavorite = isFavorite
            self.categoryId = categoryId
            self.tags = tags
            self.imageData = imageData
            self.imagesData = imagesData
            self.extractedText = extractedText
            self.imageUrls = imageUrls
            self.fileURL = fileURL
            self.fileName = fileName
            self.fileExtension = fileExtension
            self.fileSize = fileSize
            self.linkedBookmarkIds = linkedBookmarkIds ?? []
        }
        
    // MARK: - Helpers
    
    func isLinked(to bookmarkId: UUID) -> Bool {
        return linkedBookmarkIds?.contains(bookmarkId) ?? false
    }
}

// MARK: - Computed Properties

extension Bookmark {
    /// URL var mı kontrolü
    var hasURL: Bool {
        url != nil && !(url?.isEmpty ?? true)
    }
    
    /// Not var mı kontrolü
    var hasNote: Bool {
        !note.isEmpty
    }
    
    /// Etiket var mı kontrolü
    var hasTags: Bool {
        !tags.isEmpty
    }
    
    /// Fotoğraf var mı kontrolü (tek veya çoklu)
    var hasImage: Bool {
        imageData != nil || (imagesData != nil && !imagesData!.isEmpty)
    }
    
    /// Dosya var mı kontrolü
    var hasFile: Bool {
        fileURL != nil && !(fileURL?.isEmpty ?? true)
    }
    
    /// Toplam görsel sayısı
    var imageCount: Int {
        if let imagesData = imagesData, !imagesData.isEmpty {
            return imagesData.count
        }
        return imageData != nil ? 1 : 0
    }
    
    /// Tüm görselleri al (çoklu veya tek)
    var allImagesData: [Data] {
        // Önce çoklu görselleri kontrol et
        if let imagesData = imagesData, !imagesData.isEmpty {
            return imagesData
        }
        // Yoksa tek görseli döndür
        if let imageData = imageData {
            return [imageData]
        }
        return []
    }
    
    /// OCR metni var mı kontrolü
    var hasExtractedText: Bool {
        extractedText != nil && !(extractedText?.isEmpty ?? true)
    }
    
    /// Gösterim için formatlı tarih
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    /// "2 days ago" gibi relative format
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// ✅ Sync için güvenli tarih (nil ise createdAt döner)
    var lastUpdated: Date {
        updatedAt ?? createdAt
    }
}
