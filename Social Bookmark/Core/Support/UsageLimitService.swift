import Foundation
import SwiftData
import OSLog

/// Centralized service to manage and enforce usage limits
final class UsageLimitService {
    static let shared = UsageLimitService()
    
    private init() {}
    
    enum Feature {
        case ocr
        case documents
    }
    
    struct Limits {
        static let freeBookmarkLimit = 50
        static let freeCategoryLimit = 10
    }
    
    /// Thread-safe check for Pro status via App Group defaults
    private var isPro: Bool {
        let defaults = UserDefaults(suiteName: APIConstants.appGroupId) ?? .standard
        return defaults.bool(forKey: "isProUser")
    }
    
    /// Checks if the user can add a new bookmark
    func canAddBookmark(context: ModelContext) -> Bool {
        if isPro { return true }
        
        let descriptor = FetchDescriptor<Bookmark>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count < Limits.freeBookmarkLimit
    }
    
    /// Checks if the user can add a new category
    func canAddCategory(context: ModelContext) -> Bool {
        if isPro { return true }
        
        let descriptor = FetchDescriptor<Category>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count < Limits.freeCategoryLimit
    }
    
    /// Checks if a specific feature is allowed
    func isFeatureAllowed(_ feature: Feature) -> Bool {
        if isPro { return true }
        
        // For now, OCR and Documents are Pro-only
        switch feature {
        case .ocr, .documents:
            return false
        }
    }
}

/// Errors thrown when usage limits are exceeded
enum UsageLimitError: LocalizedError {
    case bookmarkLimitReached
    case categoryLimitReached
    case proFeatureRequired
    
    var errorDescription: String? {
        switch self {
        case .bookmarkLimitReached:
            return String(localized: "error.limit.bookmark_reached", defaultValue: "Bookmark limit reached. Upgrade to Pro for unlimited saves.")
        case .categoryLimitReached:
            return String(localized: "error.limit.category_reached", defaultValue: "Category limit reached. Upgrade to Pro to create more.")
        case .proFeatureRequired:
            return String(localized: "error.limit.pro_required", defaultValue: "This is a Pro feature. Please upgrade to continue.")
        }
    }
}
