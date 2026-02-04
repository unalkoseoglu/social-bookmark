# Social Bookmark Laravel API Dökümantasyonu

Laravel tabanlı yeni backend sistemi için hazırlanan tam kapsamlı API dökümantasyonu aşağıdadır. Tüm endpoint'ler `JSON` formatında veri kabul eder ve döndürür.

## Genel Bilgiler
- **Base URL:** `https://linkbookmark.tarikmaden.com/api/v1`
- **Authentication:** `Authorization: Bearer <token>` header'ı gerekir.

---

## 1. Kimlik Doğrulama (Authentication)

### Kayıt (Register)
`POST /auth/register`
- **Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword",
  "full_name": "John Doe",
  "is_anonymous": false
}
```

### Giriş (Login)
`POST /auth/login`
- **Body (Email):** `{"email": "...", "password": "..."}`
- **Body (Apple):** `{"provider": "apple", "id_token": "...", "nonce": "..."}`

### Çıkış (Logout)
`POST /auth/logout`

---

## 2. Kullanıcı Profili

### Profili Al
`GET /profile`

### Profili Güncelle
`PATCH /profile`
- **Body:** `{"display_name": "...", "is_pro": true}`

### Hesabı Sil
`DELETE /profile`

---

## 3. Bookmark İşlemleri

### Tüm Bookmarkları Listele
`GET /bookmarks`

### Tekli Bookmark Al
`GET /bookmarks/{id}`

### Bookmark Oluştur / Güncelle (Upsert)
`POST /bookmarks/upsert`

Bu endpoint hem standart JSON hem de medya içeren `multipart/form-data` formatını destekler.

- **Format 1: Standart JSON (Medya Yoksa)**
  - **Header:** `Content-Type: application/json`
  - **Body:**
    ```json
    {
      "bookmarks": [
        {
          "id": "uuid",
          "title": "...",
          "url": "...",
          "note": "...",
          "category_id": "uuid",
          "source": "manual",
          "is_read": false,
          "is_favorite": false,
          "tags": ["tag1", "tag2"]
        }
      ]
    }
    ```

- **Format 2: Multipart (Resimler veya Dosya Varsa)**
  - **Header:** `Content-Type: multipart/form-data`
  - **Fields:**
    - `payload`: Bookmark JSON verisi (Format 1'deki body ile aynı)
    - `images[]`: (Binary) Resim dosyası veya dosyaları. Birden fazla resim için aynı isimle (`images[]`) birden fazla dosya gönderilebilir.
    - `file`: (Binary) Doküman dosyası (opsiyonel)
  - **Açıklama:** Birden fazla resim gönderildiğinde sunucu tüm resimleri işler ve bookmark ile ilişkilendirir.

### Bookmark Sil
`DELETE /bookmarks/{id}`

---

## 4. Kategori İşlemleri

### Tüm Kategorileri Listele
`GET /categories`

### Kategori Oluştur / Güncelle (Upsert)
`POST /categories/upsert`
- **Body:**
```json
{
  "categories": [
    {
      "id": "uuid",
      "name": "...",
      "icon": "folder",
      "color": "#HEX",
      "order": 0
    }
  ]
}
```

### Kategori Sil
`DELETE /categories/{id}`

---

## 5. Senkronizasyon (Sync)

### Delta Sync
`POST /sync/delta`
- **Body:** 
```json
{
  "last_sync_timestamp": "2024-02-04T12:00:00Z",
  "bookmarks": [...],
  "categories": [...]
}
```
- **Açıklama:** Belirtilen zamandan sonraki değişiklikleri getirir ve gönderilen batch veriyi işler.

---

## 6. Medya İşlemleri

### Dosya/Resim Yükle
`POST /media/upload`
- **Content-Type:** `multipart/form-data`
- **Response:** `{"url": "...", "disk_path": "..."}`

---

## Veri Modelleri

### CloudBookmark
| Field | Type | Description |
| :--- | :--- | :--- |
| id | UUID | Benzersiz kimlik |
| title | String | Başlık (Opsiyonel şifrelenebilir) |
| url | String? | URL (Opsiyonel şifrelenebilir) |
| note | String? | Not (Opsiyonel şifrelenebilir) |
| source | String | manual, link, tweet, ocr, document |
| is_read | Bool | Okundu bilgisi |
| is_favorite | Bool | Favori bilgisi |
| tags | [String]? | Etiket listesi |
| image_urls | [String]? | Resim URL listesi |
| file_url | String? | Doküman URL'i |

### UserProfile
- `id`: UUID
- `email`: String?
- `display_name`: String
- `is_anonymous`: Bool
- `is_pro`: Bool
- `last_sync_at`: Date? (ISO8601)

---

## Hata Kodları
- `200/201`: Başarılı
- `401`: Yetkisiz (Token eksik/hatalı)
- `403`: Yasak (Yetki yetersiz)
- `404`: Kaynak bulunamadı
- `422`: Validasyon hatası (Eksik/yanlış parametre)
- `500`: Sunucu hatası
