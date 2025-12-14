import SwiftUI

// MARK: - Sort Option

enum SortOption: String, CaseIterable, Hashable {
    case newest
    case oldest
    case alphabetical
    case source
    
    var title: String {
        switch self {
        case .newest: return "En Yeni"
        case .oldest: return "En Eski"
        case .alphabetical: return "Alfabetik"
        case .source: return "Kaynağa Göre"
        }
    }
    
    var icon: String {
        switch self {
        case .newest: return "clock.badge.checkmark"
        case .oldest: return "clock.arrow.circlepath"
        case .alphabetical: return "textformat.abc"
        case .source: return "square.stack.3d.up"
        }
    }
}
