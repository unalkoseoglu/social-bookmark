import Foundation

/// Model for data exchanged between Share Extension and Main App via App Group
struct SharedInboxPayload: Codable {
    let id: String
    let createdAt: Date
    var urls: [String]
    var texts: [String]
    var imageFileNames: [String]
    
    init(id: String = UUID().uuidString, createdAt: Date = Date(), urls: [String] = [], texts: [String] = [], imageFileNames: [String] = []) {
        self.id = id
        self.createdAt = createdAt
        self.urls = urls
        self.texts = texts
        self.imageFileNames = imageFileNames
    }
}
