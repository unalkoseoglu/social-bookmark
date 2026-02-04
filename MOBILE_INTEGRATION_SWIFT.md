# Social Bookmark Swift Entegrasyon Rehberi

Bu döküman, Swift ile geliştirilen iOS uygulamasının Laravel tabanlı yeni backend API'si ile nasıl haberleşeceğini ve veri modellerini içerir.

## 1. Veri Modelleri (Models)

API ile uyumlu `Codable` modelleri aşağıdadır.

```swift
import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var email: String?
    var displayName: String
    var isAnonymous: Bool
    var isPro: Bool
    var lastSyncAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case isAnonymous = "is_anonymous"
        case isPro = "is_pro"
        case lastSyncAt = "last_sync_at"
    }
}

struct CloudBookmark: Codable, Identifiable {
    let id: UUID
    var localId: UUID?
    var categoryId: UUID?
    var title: String
    var url: String?
    var note: String?
    var source: String
    var isRead: Bool
    var isFavorite: Bool
    var tags: [String]?
    var imageUrls: [String]?
    var fileUrl: String?
    var syncVersion: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title, url, note, source, tags
        case localId = "local_id"
        case categoryId = "category_id"
        case isRead = "is_read"
        case isFavorite = "is_favorite"
        case imageUrls = "image_urls"
        case fileUrl = "file_url"
        case syncVersion = "sync_version"
    }
}

struct CloudCategory: Codable, Identifiable {
    let id: UUID
    var localId: UUID?
    var name: String
    var icon: String
    var color: String
    var order: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, color, order
        case localId = "local_id"
    }
}
```

---

## 2. API Servisi (Network Service)

Temel bir network helper yapısı:

```swift
import Foundation

class APIConfig {
    static let baseURL = URL(string: "https://linkbookmark.tarikmaden.com/api/v1")!
    static var token: String? = nil // KeyChain veya SessionStore'dan alınmalı
}

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
}

class APIService {
    static let shared = APIService()
    
    private func commonHeaders() -> [String: String] {
        var headers = ["Accept": "application/json"]
        if let token = APIConfig.token {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
    
    // Standart GET İsteği
    func fetch<T: Codable>(endpoint: String) async throws -> T {
        let url = APIConfig.baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = commonHeaders()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Fetch failed")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
```

---

## 3. Bookmark Upsert ve Dosya Yükleme (Multipart)

Yeni API, bookmark verisi ile birlikte resim ve döküman yüklemeyi tek bir endpoint'te (`/bookmarks/upsert`) destekler.

```swift
func upsertBookmark(bookmark: CloudBookmark, images: [Data]?, file: Data?) async throws {
    let url = APIConfig.baseURL.appendingPathComponent("bookmarks/upsert")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.allHTTPHeaderFields?.merge(commonHeaders()) { (_, new) in new }
    
    var body = Data()
    
    // 1. JSON Payload
    let payload: [String: Any] = ["bookmarks": [bookmark.dictionary]] // Dictionary conversion helper gerekir
    let jsonData = try JSONSerialization.data(withJSONObject: payload)
    let jsonString = String(data: jsonData, encoding: .utf8)!
    
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"payload\"\r\n\r\n".data(using: .utf8)!)
    body.append("\(jsonString)\r\n".data(using: .utf8)!)
    
    // 2. Images (Birden fazla)
    if let images = images {
        for (index, imageData) in images.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"images[]\"; filename=\"image\(index).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
    }
    
    // 3. File (Opsiyonel)
    if let fileData = file {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"document.pdf\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
    }
    
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)
    request.httpBody = body
    
    let (_, response) = try await URLSession.shared.data(for: request)
    // Response handler...
}
```

---

## 4. Senkronizasyon (Delta Sync)

İstemci tarafındaki verileri sunucuya gönderip, son senkronizasyondan bu yana gerçekleşen değişiklikleri almak için kullanılır.

```swift
struct DeltaSyncRequest: Codable {
    let lastSyncTimestamp: String?
    let bookmarks: [CloudBookmark]?
    let categories: [CloudCategory]?
    
    enum CodingKeys: String, CodingKey {
        case lastSyncTimestamp = "last_sync_timestamp"
        case bookmarks, categories
    }
}

struct DeltaSyncResponse: Codable {
    let updatedCategories: [CloudCategory]
    let updatedBookmarks: [CloudBookmark]
    let deletedIds: [String: [String]] // categories, bookmarks
    let currentServerTime: String
    
    enum CodingKeys: String, CodingKey {
        case updatedCategories = "updated_categories"
        case updatedBookmarks = "updated_bookmarks"
        case deletedIds = "deleted_ids"
        case currentServerTime = "current_server_time"
    }
}

// Kullanım:
// POST /sync/delta
```

---

## Önemli Notlar

1. **Date Format**: Sunucu `ISO8601` formatında tarih bekler ve dönderir. Swift'te `JSONDecoder.DateDecodingStrategy.iso8601` kullanılmalıdır.
2. **Error Handling**: API `422` (Validation Error), `401` (Unauthorized) ve `500` hataları dönebilir. Swift tarafında bu status code'lara göre kullanıcıya bilgi verilmelidir.
3. **Background Sync**: Apple'ın `BackgroundTasks` framework'ü ile periyodik olarak `Delta Sync` yapılması önerilir.
