import SwiftUI
import Foundation

/// UI için güvenli, detached bookmark modeli.
/// SwiftData objesi silindiğinde crash olmasını engeller.
struct BookmarkDisplayModel: Identifiable, Hashable {
    let id: UUID
    let title: String
    let url: String?
    let note: String?
    let extractedText: String?
    let source: BookmarkSource
    let isRead: Bool
    let isFavorite: Bool
    let createdAt: Date
    let imageUrls: [String]?
    let imageData: Data?
    let categoryName: String?
    let categoryColorHex: String?
    
    // MARK: - Computed Properties
    
    var contentPreview: String {
        if let note = note, !note.isEmpty {
            return note
        } else if let extractedText = extractedText, !extractedText.isEmpty {
            return extractedText
        } else if let url = url {
            return url
        }
        return LanguageManager.shared.localized("bookmark.no_content")
    }
    
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = LanguageManager.shared.currentLanguage.locale
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var categoryColor: Color {
        if let hex = categoryColorHex {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }
    
    // MARK: - Initialization
    
    init(bookmark: Bookmark, category: Category? = nil) {
        self.id = bookmark.id
        self.title = bookmark.title
        self.url = bookmark.url
        self.note = bookmark.note
        self.extractedText = bookmark.extractedText
        self.source = bookmark.source
        self.isRead = bookmark.isRead
        self.isFavorite = bookmark.isFavorite
        self.createdAt = bookmark.createdAt
        self.imageUrls = bookmark.imageUrls
        self.imageData = bookmark.imageData
        
        self.categoryName = category?.name
        self.categoryColorHex = category?.colorHex
    }
}
