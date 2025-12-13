# Social Bookmark 📱

**Sosyal medya ve web içeriklerini akıllı şekilde kaydeden iOS uygulaması**

![iOS](https://img.shields.io/badge/iOS-17%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS%2017%2B-blue)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📋 İçerik

- [Genel Bakış](#genel-bakış)
- [Özellikler](#özellikler)
- [Teknoloji Stack](#teknoloji-stack)
- [Proje Yapısı](#proje-yapısı)
- [Kurulum](#kurulum)
- [Kullanım](#kullanım)
- [Mimari](#mimari)
- [Desteklenen Platformlar](#desteklenen-platformlar)
- [Geliştirme](#geliştirme)
- [Test](#test)
- [Lokalizasyon](#lokalizasyon)
- [Lisans](#lisans)

---

## 🎯 Genel Bakış

**Social Bookmark**, Twitter/X, Reddit, LinkedIn, Medium ve diğer web içeriklerini kolaylıkla kaydetmenizi ve yönetmenizi sağlayan bir iOS uygulamasıdır.

### Ana Avantajlar:
- 🚀 **Anında Kayıt**: Safari ve diğer uygulamalardan Share Extension ile hızlıca bookmark kaydedin
- 🔍 **Akıllı Tanıma**: Kaynağı otomatik algılayan sistem (Twitter, Reddit, LinkedIn, vb.)
- 🖼️ **Çoklu Medya Desteği**: Görselleri kırpın, OCR ile metni çıkarın
- 🏷️ **Etiketleme Sistemi**: Bookmarkları kategorize etmek için etiket ekleyin
- 📝 **Not Alma**: Her bookmark'a kişisel notlar ekleyin
- 🌍 **Çok Dil Desteği**: Türkçe ve İngilizce
- 📱 **Share Extension**: Doğrudan Safari'den kaydedin
- 💾 **İndirme Kaydı**: Okundu/Okunmadı durumu takibi

---

## ✨ Özellikler

### 1. **Bookmark Yönetimi**
- ➕ Yeni bookmark oluşturma
- ✏️ Mevcut bookmarkları düzenleme
- 🗑️ Toplu silme
- 🔍 Başlık ve not ile arama
- 🏷️ Kaynak bazlı filtreleme

### 2. **Sosyal Medya Entegrasyonu**

#### **Twitter/X**
- Tweet bilgilerini otomatik çekme (başlık, yazar, beğeni, retweet sayısı)
- Çoklu görsel desteği
- FxTwitter API kullanılarak stabil erişim
- Tweet istatistiklerini kaydetme

#### **Reddit**
- Reddit gönderilerinin başlık, yazar ve subreddit bilgilerini çekme
- Skor ve yorum sayısını kaydetme
- İçerik özeti otomatik çıkarma
- Alternatif permalink desteği

#### **LinkedIn**
- OAuth 2.0 doğrulama (Credentials gerektir)
- LinkedIn profili ve paylaşım bilgilerini çekme
- Token yönetimi ve refresh mekanizması
- Keychain'e güvenli saklama

#### **Medium & Blog**
- Genel URL metadata çekimi
- URL'den başlık ve açıklama otomatik alınması
- Favicon desteği

### 3. **OCR (Optik Karakter Tanıma)**
- Vision Framework kullanarak fotoğraflardan metin çıkarma
- Akıllı başlık önerisi
- Metin temizleme ve formatlandırma
- Güven skoru (confidence) hesaplama
- Kişi ismi algılaması

### 4. **Görsel İşleme**
- Fotoğraf seçme ve kırpma
- Çoklu görsel desteği
- Dış depolamada saklama (external storage)
- Thumbnail oluşturma

### 5. **Çok Dil Desteği**
- 🇹🇷 **Türkçe** (Tam destekli)
- 🇬🇧 **İngilizce** (Tam destekli)
- 🌐 Sistem dili takibi

---

## 🛠️ Teknoloji Stack

### **Frontend**
- **SwiftUI** - Modern UI framework
- **iOS 17+** - Minimum iOS versiyonu
- **Observable** - Modern state management (iOS 17+)

### **Backend & Veri**
- **SwiftData** - Modern Apple veritabanı çözümü
- **Codable** - JSON serialization

### **Ağ İşlemleri**
- **URLSession** - HTTP istekleri
- **async/await** - Modern concurrency

### **Servisler & Entegrasyonlar**
- **Vision Framework** - OCR (metin tanıma)
- **Security Framework** - Keychain (token saklama)
- **FxTwitter API** - Twitter veri çekimi
- **Reddit API** - Reddit veri çekimi
- **LinkedIn API** - LinkedIn veri çekimi (OAuth 2.0)

### **Share Extension**
- UIKit + SwiftUI hybrid
- App Groups (uygulamalar arası veri paylaşımı)
- UniformTypeIdentifiers (veri tipleri)

---

## 📁 Proje Yapısı

```
social-bookmark/
├── Social Bookmark/                    # Ana Uygulama
│   ├── App/
│   │   ├── Social_BookmarkApp.swift   # App entry point, SwiftData setup
│   │   └── Assets.xcassets/            # Resimler, ikonlar
│   ├── Models/
│   │   ├── Bookmark.swift              # Ana veri modeli (@Model)
│   │   └── BookmarkSource.swift        # Enum - Kaynak tipleri
│   ├── Views/
│   │   ├── BookmarkList/               # Ana liste ekranı
│   │   │   ├── BookmarkListView.swift
│   │   │   ├── BookmarkRow.swift       # List satırı
│   │   │   └── EmptyStateView.swift    # Boş durum gösterimi
│   │   ├── AddBookmark/                # Yeni bookmark ekleme
│   │   │   ├── AddBookmarkView.swift
│   │   │   ├── LinkedInPreviewView.swift
│   │   │   ├── RedditPreviewView.swift
│   │   │   └── TweetPreviewView.swift
│   │   ├── BookmarkDetail/             # Detay ve düzenleme
│   │   │   ├── BookmarkDetailView.swift
│   │   │   └── EditBookmarkView.swift
│   │   ├── Common/                     # Paylaşılan komponentler
│   │   │   ├── ImagePickerView.swift
│   │   │   ├── ImageCropView.swift
│   │   │   ├── LoadingView.swift
│   │   │   └── ErrorView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift      # Uygulama ayarları
│   ├── ViewModels/                     # Business Logic (@Observable)
│   │   ├── BookmarkListViewModel.swift
│   │   └── AddBookmarkViewModel.swift
│   ├── Repositories/
│   │   ├── BookmarkRepository.swift    # CRUD operasyonları
│   │   └── Protocol/
│   │       └── BookmarkRepositoryProtocol.swift
│   ├── Utilities/
│   │   ├── Services/                   # İş mantığı servisleri
│   │   │   ├── LinkedInService.swift   # LinkedIn API
│   │   │   ├── TwitterService.swift    # Twitter API (FxTwitter)
│   │   │   ├── RedditService.swift     # Reddit API
│   │   │   ├── OCRService.swift        # Vision Framework OCR
│   │   │   └── URLMetadataService.swift # Genel URL metadata
│   │   ├── Extensions/                 # Swift Extensions
│   │   │   ├── Date+Extensions.swift
│   │   │   └── View+Extensions.swift
│   │   ├── Helpers/
│   │   │   └── URLValidator.swift      # URL doğrulama
│   │   ├── Constants/
│   │   │   ├── AppConstants.swift
│   │   │   └── LinkedInConfig.swift    # LinkedIn OAuth config
│   │   └── AppLanguage.swift           # Dil yönetimi
│   ├── Localization/                   # Çok dil dosyaları
│   │   ├── en.lproj/
│   │   │   └── Localizable.strings
│   │   └── tr.lproj/
│   │       └── Localizable.strings
│   └── Content/
│       └── MockData.swift              # Test verisi
├── BookmarkShareExtension/             # Share Extension
│   ├── ShareViewController.swift        # Entry point
│   ├── ShareExtensionView.swift         # SwiftUI UI
│   ├── ShareExtensionView.entitlements
│   └── Info.plist
├── Social BookmarkTests/               # Unit Tests
│   ├── Social_BookmarkTests.swift
│   ├── LinkedInIntegrationTests.swift
│   └── RedditServiceTests.swift
├── Social BookmarkUITests/             # UI Tests
│   ├── Social_BookmarkUITests.swift
│   └── Social_BookmarkUITestsLaunchTests.swift
├── Config/
│   └── LinkedInSecrets.xcconfig.example # Konfigürasyon örneği
└── Social Bookmark.xcodeproj/          # Xcode Project
    └── project.pbxproj
```

---

## 📦 Kurulum

### Ön Koşullar
- **Xcode 15+**
- **iOS 17+** (target device/simulator)
- **Swift 5.9+**
- CocoaPods veya SPM (ihtiyaca göre)

### Adım Adım Kurulum

1. **Projeyi klonlayın:**
```bash
git clone https://github.com/unalkoseoglu/social-bookmark.git
cd social-bookmark
```

2. **Xcode'da projeyi açın:**
```bash
open "Social Bookmark.xcodeproj"
```

3. **Bundle ID'yi değiştirin (opsiyonel):**
   - `Social Bookmark` target → Build Settings → Bundle Identifier
   - Kendi bundle ID'nizi girin (örn: `com.yourname.socialbookmark`)

4. **App Group ID'yi ayarlayın (Share Extension için zorunlu):**
   - `Social_BookmarkApp.swift` dosyasında:
   ```swift
   static let appGroupID = "group.com.unal.socialbookmark" // DEĞIŞTIR!
   ```
   - Kendi ID'nizi kullanın
   - Both targets'ın entitlements dosyasında ayarlayın

5. **LinkedIn OAuth Kurulumu (opsiyonel):**
   - `Config/LinkedInSecrets.xcconfig.example` kopyalayıp `LinkedInSecrets.xcconfig` yapın
   - LinkedIn Developer Portal'dan credentials alın:
     - Client ID
     - Client Secret
     - Redirect URI
   - `.xcconfig` dosyasına değerleri girin

6. **Projeyi çalıştırın:**
```bash
Cmd + R (Xcode'da)
```

---

## 🚀 Kullanım

### Ana Ekran (Bookmark Listesi)
1. **Listeleme**: Tüm saved bookmarkları tarih sırasına göre gösterir
2. **Arama**: Başlık veya nota göre hızlı arama
3. **Filtreleme**: Kaynak (Twitter, Reddit, vb.) seçerek filtrele
4. **Okunmadı Modu**: Sadece okunmamış bookmarkları göster

### Yeni Bookmark Ekleme
1. **Temel Bilgiler**:
   - Başlık (zorunlu)
   - URL (opsiyonel - sistem otomatik algılar)

2. **Kaynak Algılama**:
   - URL'den otomatik kaynak algılanır
   - Manuel olarak değiştirebilirsiniz

3. **Metadata Çekimi**:
   - Twitter: Tweet bilgileri, görseller, istatistikler
   - Reddit: Gönderi başlığı, subreddit, puan
   - LinkedIn: Profil/paylaşım bilgileri (OAuth required)
   - Diğer: Sayfa başlığı, açıklama

4. **Görsel İşleme**:
   - Kamera veya galeriden fotoğraf seçin
   - Kırpma aracı ile optimize edin
   - OCR ile metni otomatik çıkarın

5. **Etiketleme**: virgülle ayrılmış etiketler ekleyin

6. **Kaydetme**: "Kaydet" tuşu ile taslağı veritabanına yazın

### Share Extension Kullanımı
1. **Safari'de** herhangi bir sayfayı açın
2. **Paylaş** (Share) menüsünü açın
3. **Social Bookmark** seçin
4. Bilgileri düzenleyin ve **Kaydet**

### Detay Ekranı
- Bookmark tam bilgisini görüntüleme
- Notları ve etiketleri görme
- Okundu/Okunmadı durumunu ayarlama
- Düzenle veya Sil seçeneği

---

## 🏗️ Mimari

### Design Patterns

#### **Repository Pattern**
```
View ←→ ViewModel ←→ Repository ←→ SwiftData
```
- Repository: Veri erişim katmanını soyutlar
- Kolaylıkla mock'lanabilir (testing için)

#### **MVVM + Observable**
- `@Observable`: iOS 17+ modern state management
- ViewModel'deki değişiklikler otomatik View günceller
- Binding gereksiz (reactive)

#### **Protocol-Oriented Design**
- `BookmarkRepositoryProtocol`: CRUD interface
- `RedditPostProviding`: Reddit servis interface
- `LinkedInAuthProviding`: LinkedIn auth interface
- Kolaylıkla swap'ı ve testing'i mümkün kılar

#### **Dependency Injection**
```swift
AddBookmarkViewModel(
    repository: bookmarkRepository,
    linkedinAuthClient: linkedinAuthClient,
    redditService: redditService
)
```
- Loose coupling
- Testable code

### Veri Akışı

#### **Bookmark Oluşturma**
```
User Input 
  ↓
AddBookmarkView 
  ↓
AddBookmarkViewModel.saveBookmark()
  ↓
Services (LinkedIn/Twitter/Reddit)
  ↓
BookmarkRepository.create()
  ↓
SwiftData.modelContext.insert()
  ↓
Database Persist
```

#### **Bookmark Listeleme**
```
App Launch
  ↓
BookmarkListView loads
  ↓
BookmarkListViewModel.loadBookmarks()
  ↓
BookmarkRepository.fetchAll()
  ↓
SwiftData.modelContext.fetch()
  ↓
View refreshed (Observable)
```

### Concurrency Model
- **async/await**: Modern Swift concurrency
- **URLSession**: Ağ istekleri için async/await
- **Vision Framework**: Background thread'de OCR işlemi
- **Task**: Background operations

---

## 🌐 Desteklenen Platformlar

### **Twitter/X**
| Özellik | Durum |
|---------|-------|
| Tweet bilgileri | ✅ |
| Çoklu görseller | ✅ |
| Video | ⚠️ (Thumbnail) |
| Beğeni/Retweet | ✅ |
| Yani sıra | ✅ |

**Not**: FxTwitter API kullanılır (API key gerektirmez)

### **Reddit**
| Özellik | Durum |
|---------|-------|
| Post başlığı | ✅ |
| Subreddit | ✅ |
| Yazar/Skor | ✅ |
| Açıklama | ✅ |
| Görseller | ✅ |

### **LinkedIn**
| Özellik | Durum |
|---------|-------|
| OAuth 2.0 | ✅ |
| Profil bilgisi | ✅ |
| Paylaşım detayı | ✅ |
| Token refresh | ✅ |
| Keychain depolama | ✅ |

**Not**: OAuth credentials gerekli

### **Medium & Blog**
| Özellik | Durum |
|---------|-------|
| URL metadata | ✅ |
| Başlık çekimi | ✅ |
| Açıklama | ✅ |
| Favicon | ✅ |

---

## 🧪 Test

### Unit Tests
```bash
Cmd + U (Xcode'da)
```

#### **Testler İçeriği:**
- `LinkedInIntegrationTests.swift`: LinkedIn OAuth flow
- `RedditServiceTests.swift`: Reddit API çekimi
- `Social_BookmarkTests.swift`: Temel model testleri

### UI Tests
```bash
Cmd + U (Xcode'da - UI Tests scheme)
```

#### **Kapsanan Alanlar:**
- Bookmark oluşturma flow
- Liste gösterimi
- Arama işlevselliği
- Settings navigasyonu

### Mock Data
`Content/MockData.swift` dosyasında örnek veriler:
```swift
let mockBookmarks: [Bookmark] = [
    Bookmark(
        title: "Twitter integrations",
        url: "https://twitter.com/...",
        source: .twitter,
        ...
    ),
    ...
]
```

---

## 🌍 Lokalizasyon

### Desteklenen Diller
- 🇹🇷 **Türkçe** (Default)
- 🇬🇧 **İngilizce**
- 🌐 **Sistem Dili** (Cihaz ayarına göre)

### Dosya Yapısı
```
Social Bookmark/
├── Localization/
│   ├── en.lproj/
│   │   └── Localizable.strings
│   └── tr.lproj/
│       └── Localizable.strings
└── tr.lproj/
    └── Localizable.strings
```

### Yeni Dil Ekleme
1. Xcode'da yeni localization ekleyin
2. `Localizable.strings` dosyasında çevirileri yapın
3. `AppLanguage.swift`'te enum case'i ekleyin

### Kullanım
```swift
import SwiftUI

Text("Bookmark Ekle") // Otomatik çevrilir
// or
Text(LocalizedStringKey("Bookmark Ekle"))
```

---

## 🔧 Geliştirme

### Proje Açma
```bash
cd social-bookmark
open "Social Bookmark.xcodeproj"
```

### Key Files Özeti

| Dosya | Amaç |
|-------|------|
| `Social_BookmarkApp.swift` | App entry, SwiftData setup |
| `Bookmark.swift` | Ana veri modeli |
| `BookmarkListView.swift` | Ana UI |
| `AddBookmarkViewModel.swift` | Form logic |
| `TwitterService.swift` | Tweet çekimi |
| `LinkedInService.swift` | LinkedIn OAuth + API |
| `RedditService.swift` | Reddit API |
| `OCRService.swift` | Vision Framework OCR |

### Best Practices
- ✅ Protocol-oriented design kullanın
- ✅ Dependency injection yapın
- ✅ @Observable ile state yönetin
- ✅ async/await tercih edin
- ✅ Error handling yapın
- ✅ Unit test yazın

### Known Limitations
- ⚠️ LinkedIn OAuth config gerekli
- ⚠️ Twitter sadece FxTwitter API aracılığıyla
- ⚠️ OCR sadece statik görsellerden (video yok)
- ⚠️ iOS 17+ gerekli

---

## 📝 Lisans

Bu proje MIT Lisansı altında yayınlanmıştır.

---

## 👤 Yazar

**Ünal Köseoğlu**
- GitHub: [@unalkoseoglu](https://github.com/unalkoseoglu)

---

## 🤝 Katkı

Katkılar hoştur! Lütfen:
1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Değişiklikleri commit edin (`git commit -m 'Add amazing feature'`)
4. Branch'ı push edin (`git push origin feature/amazing-feature`)
5. Pull Request açın

---

## ❓ SSS (Sıkça Sorulan Sorular)

### **S: LinkedIn OAuth'ı kurması zorunlu mu?**
**C**: Hayır, opsiyonal. LinkedIn preview'ı kullanmak için gerekli.

### **S: OCR hangi dilleri destekliyor?**
**C**: Vision Framework'ün desteklediği tüm diller (Türkçe, İngilizce, vb.)

### **S: Veriler ne zaman senkronize edilir?**
**C**: Şu an senkronizasyon yok. İleride iCloud sync planlanıyor.

### **S: Share Extension'dan bookmark nasıl kaydedilir?**
**C**: Safari → Share → Social Bookmark → Bilgileri düzenle → Kaydet

### **S: Uygulamayı kişiselleştirebilir miyim?**
**C**: Evet, Xcode'da renk tema, ikonlar vb. özelleştirebilirsiniz.

---

## 🚀 Gelecek Özellikler

- [ ] iCloud Sync
- [ ] Dark Mode iyileştirmeleri
- [ ] Bulut yedekleme
- [ ] PDF export
- [ ] Offline mode
- [ ] Widget desteği
- [ ] MacOS uygulaması
- [ ] Web uygulaması
- [ ] AI-powered kategorize etme
- [ ] Sosyal paylaşım

---

## 📞 İletişim & Destek

Sorularınız veya sorunlarınız için:
- 📧 GitHub Issues açın
- 🐦 Twitter'dan (@unalkoseoglu)
- 💬 Discussions sekmesini kullanın

---

**Son Güncelleme**: 14 Aralık 2025  
**Sürüm**: 1.0.0  
**Swift**: 5.9+  
**iOS**: 17+
