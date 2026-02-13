import Foundation

/// Repository pattern interface
/// Protocol kullanmanın faydaları:
/// 1. Test için mock repository oluşturabilirsin
/// 2. İlerisi için farklı data source (CloudKit, Firebase) ekleyebilirsin
/// 3. Dependency Injection ile loose coupling
protocol BookmarkRepositoryProtocol {
    /// Tüm bookmarkları getir (tarih sıralı)
    func fetchAll() -> [Bookmark]
    
    /// ID ile tek bookmark getir
    /// - Parameter id: Bookmark UUID
    /// - Returns: Bookmark veya nil (bulunamazsa)
    func fetch(by id: UUID) -> Bookmark?
    
    /// Yeni bookmark oluştur
    /// - Parameter bookmark: Kaydedilecek bookmark
    func create(_ bookmark: Bookmark) throws
    
    /// Mevcut bookmark'ı güncelle
    /// - Parameter bookmark: Güncellenecek bookmark
    func update(_ bookmark: Bookmark)
    
    /// Bookmark'ı sil
    /// - Parameter bookmark: Silinecek bookmark
    func delete(_ bookmark: Bookmark)
    
    /// Birden fazla bookmark sil
    /// - Parameter bookmarks: Silinecek bookmarklar
    func deleteMultiple(_ bookmarks: [Bookmark])
    
    /// Metin araması yap (başlık ve not içinde)
    /// - Parameter query: Arama metni
    /// - Returns: Eşleşen bookmarklar
    func search(query: String) -> [Bookmark]
    
    /// Kaynağa göre filtrele
    /// - Parameter source: Kaynak türü (Twitter, Medium, vs.)
    /// - Returns: Filtrelenmiş bookmarklar
    func filter(by source: BookmarkSource) -> [Bookmark]
    
    /// Okunmamış bookmarkları getir
    /// - Returns: isRead = false olan bookmarklar
    func fetchUnread() -> [Bookmark]
    
    /// Etikete göre filtrele
    /// - Parameter tag: Etiket ismi
    /// - Returns: Bu etiketi içeren bookmarklar
    func filter(by tag: String) -> [Bookmark]
    
    /// Tarih aralığına göre getir
    /// - Parameters:
    ///   - startDate: Başlangıç tarihi
    ///   - endDate: Bitiş tarihi
    /// - Returns: Bu tarihler arasındaki bookmarklar
    func fetch(from startDate: Date, to endDate: Date) -> [Bookmark]
    
    /// Toplam bookmark sayısı
    var count: Int { get }
    
    /// Okunmamış bookmark sayısı
    var unreadCount: Int { get }
}
