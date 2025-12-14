import Foundation

/// Localization keys for the application
struct LocalizationKeys {
    // MARK: - General
    static let ok = NSLocalizedString("Tamam", comment: "OK button")
    static let cancel = NSLocalizedString("İptal", comment: "Cancel button")
    static let delete = NSLocalizedString("Sil", comment: "Delete button")
    static let save = NSLocalizedString("Kaydet", comment: "Save button")
    static let edit = NSLocalizedString("Düzenle", comment: "Edit button")
    static let close = NSLocalizedString("Kapat", comment: "Close button")
    static let remove = NSLocalizedString("Kaldır", comment: "Remove button")
    
    // MARK: - Home View
    static let homeTitle = NSLocalizedString("Bookmarklar", comment: "Home view title")
    static let totalCountLabel = NSLocalizedString("Toplam", comment: "Total count label")
    static let unreadCountLabel = NSLocalizedString("Okunmadı", comment: "Unread count label")
    static let thisWeek = NSLocalizedString("Bu Hafta", comment: "This week label")
    static let quickAccess = NSLocalizedString("Hızlı Erişim", comment: "Quick access section title")
    static let favorites = NSLocalizedString("Favoriler", comment: "Favorites label")
    static let today = NSLocalizedString("Bugün", comment: "Today label")
    static let categories = NSLocalizedString("Kategoriler", comment: "Categories section title")
    static let createCategories = NSLocalizedString("Kategorileri Oluştur", comment: "Create categories button")
    static let recentItems = NSLocalizedString("Son Eklenenler", comment: "Recent items section title")
    static let viewAll = NSLocalizedString("Tümünü Gör", comment: "View all link")
    static let noBookmarksYet = NSLocalizedString("Henüz bookmark eklenmedi", comment: "Empty recent bookmarks message")
}

/// Localization keys for the application
struct LocalizationKeys {
    // MARK: - General
    static let ok = NSLocalizedString("Tamam", comment: "OK button")
    static let cancel = NSLocalizedString("İptal", comment: "Cancel button")
    static let delete = NSLocalizedString("Sil", comment: "Delete button")
    static let save = NSLocalizedString("Kaydet", comment: "Save button")
    static let edit = NSLocalizedString("Düzenle", comment: "Edit button")
    static let close = NSLocalizedString("Kapat", comment: "Close button")
    static let remove = NSLocalizedString("Kaldır", comment: "Remove button")
    
    // MARK: - Home View
    static let homeTitle = NSLocalizedString("Bookmarklar", comment: "Home view title")
    static let totalCount = NSLocalizedString("Toplam", comment: "Total count label")
    static let unreadCount = NSLocalizedString("Okunmadı", comment: "Unread count label")
    static let thisWeek = NSLocalizedString("Bu Hafta", comment: "This week label")
    static let quickAccess = NSLocalizedString("Hızlı Erişim", comment: "Quick access section title")
    static let favorites = NSLocalizedString("Favoriler", comment: "Favorites label")
    static let today = NSLocalizedString("Bugün", comment: "Today label")
    static let categories = NSLocalizedString("Kategoriler", comment: "Categories section title")
    static let createCategories = NSLocalizedString("Kategorileri Oluştur", comment: "Create categories button")
    static let recentItems = NSLocalizedString("Son Eklenenler", comment: "Recent items section title")
    static let viewAll = NSLocalizedString("Tümünü Gör", comment: "View all link")
    static let noBookmarksYet = NSLocalizedString("Henüz bookmark eklenmedi", comment: "Empty recent bookmarks message")
    
    // MARK: - Categories
    static let selectCategory = NSLocalizedString("Kategori Seç", comment: "Category selection title")
    static let notSelected = NSLocalizedString("Seçilmedi", comment: "Not selected")
    static let uncategorized = NSLocalizedString("Kategorisiz", comment: "Uncategorized label")
    static let all = NSLocalizedString("Tümü", comment: "All items")
    static let category = NSLocalizedString("Kategori", comment: "Category label")
    static let noCategoriesYet = NSLocalizedString("Henüz kategori yok", comment: "No categories message")
    static let categoryDescription = NSLocalizedString("Bookmarklarını düzenlemek için kategoriler oluştur. Sürükleyerek sıralayabilirsin.", comment: "Category management description")
    static let addDefaultCategories = NSLocalizedString("Varsayılan Kategorileri Ekle", comment: "Add default categories button")
    static let editCategories = NSLocalizedString("Kategorileri Düzenle", comment: "Manage categories title")
    static let deleteCategory = NSLocalizedString("Kategoriyi Sil", comment: "Delete category alert")
    static let categoryName = NSLocalizedString("Kategori Adı", comment: "Category name label")
    static let categoryNameExample = NSLocalizedString("Örn: İş, Okuma Listesi, Araştırma", comment: "Category name example")
    static let icon = NSLocalizedString("İkon", comment: "Icon label")
    static let color = NSLocalizedString("Renk", comment: "Color label")
    static let preview = NSLocalizedString("Önizleme", comment: "Preview label")
    
    // MARK: - Bookmarks
    static let newBookmark = NSLocalizedString("Yeni Bookmark", comment: "New bookmark title")
    static let basicInfo = NSLocalizedString("Temel Bilgiler", comment: "Basic info section")
    static let title = NSLocalizedString("Başlık", comment: "Title field")
    static let url = NSLocalizedString("URL (opsiyonel)", comment: "URL field")
    static let invalidURLFormat = NSLocalizedString("Geçersiz URL formatı", comment: "Invalid URL message")
    static let details = NSLocalizedString("Detaylar", comment: "Details section")
    static let notes = NSLocalizedString("Notlar (opsiyonel)", comment: "Notes field")
    static let organization = NSLocalizedString("Organizasyon", comment: "Organization section")
    static let source = NSLocalizedString("Kaynak", comment: "Source label")
    static let tags = NSLocalizedString("Etiketler", comment: "Tags section")
    static let tagsPlaceholder = NSLocalizedString("Etiketler (virgülle ayır)", comment: "Tags placeholder")
    static let tagsExample = NSLocalizedString("swift, ios, development", comment: "Tags example")
    static let photo = NSLocalizedString("Fotoğraf", comment: "Photo section")
    static let addPhoto = NSLocalizedString("Fotoğraf Ekle", comment: "Add photo button")
    static let takePhoto = NSLocalizedString("Fotoğraf Çek", comment: "Take photo button")
    static let chooseFromLibrary = NSLocalizedString("Galeriden Seç", comment: "Choose from library button")
    static let errors = NSLocalizedString("Hatalar", comment: "Errors section")
    static let deleteBookmark = NSLocalizedString("Bookmark Silinsin mi?", comment: "Delete bookmark confirmation")
    static let cannotUndo = NSLocalizedString("Bu işlem geri alınamaz.", comment: "Cannot undo message")
    
    // MARK: - Search
    static let search = NSLocalizedString("Ara", comment: "Search title")
    static let searchBookmarks = NSLocalizedString("Bookmark ara...", comment: "Search placeholder")
    static let searchResults = NSLocalizedString("sonuç bulundu", comment: "Search results count")
    static let noResults = NSLocalizedString("Sonuç bulunamadı", comment: "No search results")
    static let searching = NSLocalizedString("Aranıyor...", comment: "Searching indicator")
    static let clearSearch = NSLocalizedString("Temizle", comment: "Clear search")
    static let recentSearches = NSLocalizedString("Son Aramalar", comment: "Recent searches")
    
    // MARK: - Reading Status
    static let read = NSLocalizedString("Okundu", comment: "Read status")
    static let unread = NSLocalizedString("Okunmadı", comment: "Unread status")
    static let markAsRead = NSLocalizedString("Okundu İşaretle", comment: "Mark as read button")
    static let markAsUnread = NSLocalizedString("Okunmadı İşaretle", comment: "Mark as unread button")
    static let onlyUnread = NSLocalizedString("Sadece Okunmamışlar", comment: "Only unread filter")
    static let onlyFavorites = NSLocalizedString("Sadece Favoriler", comment: "Only favorites filter")
    
    // MARK: - Settings
    static let settings = NSLocalizedString("Ayarlar", comment: "Settings title")
    static let general = NSLocalizedString("Genel", comment: "General section")
    static let appLanguage = NSLocalizedString("Uygulama Dili", comment: "App language setting")
    
    // MARK: - Empty States
    static let noBookmarks = NSLocalizedString("Henüz bookmark yok", comment: "No bookmarks message")
    static let startSaving = NSLocalizedString("İnternette bulduğun değerli içerikleri kaydetmeye başla", comment: "Empty state description")
    static let addFirstBookmark = NSLocalizedString("İlk Bookmark'ı Ekle", comment: "Add first bookmark button")
    
    // MARK: - Content Actions
    static let openInBrowser = NSLocalizedString("Tarayıcıda Aç", comment: "Open in browser button")
    static let copyURL = NSLocalizedString("URL'yi Kopyala", comment: "Copy URL button")
    static let share = NSLocalizedString("Paylaş", comment: "Share button")
    static let content = NSLocalizedString("İçerik", comment: "Content label")
    static let words = NSLocalizedString("kelime", comment: "Words count label")
}
