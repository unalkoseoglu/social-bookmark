import SwiftUI
import SwiftData

/// Kategori modeli
/// Bookmarkları gruplandırmak için kullanılır
@Model
final class Category {
    // MARK: - Properties
    
    /// Benzersiz tanımlayıcı
    @Attribute(.unique) var id: UUID
    
    /// Kategori adı
    var name: String
    
    /// SF Symbols ikon adı
    var icon: String
    
    /// Renk hex kodu (örn: "#FF5733")
    var colorHex: String
    
    /// Sıralama önceliği (düşük = üstte)
    var order: Int
    
    /// Oluşturulma tarihi
    var createdAt: Date
    
    // MARK: - Computed Properties
    
    /// Hex'ten Color'a çevir
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        colorHex: String = "#007AFF",
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.order = order
        self.createdAt = Date()
    }
    
    // MARK: - Static Methods
    
    /// Varsayılan kategoriler
    static func createDefaults() -> [Category] {
        [
            Category(name: "İş", icon: "briefcase.fill", colorHex: "#007AFF", order: 0),
            Category(name: "Okuma Listesi", icon: "book.fill", colorHex: "#34C759", order: 1),
            Category(name: "Araştırma", icon: "magnifyingglass", colorHex: "#FF9500", order: 2),
            Category(name: "İlham", icon: "lightbulb.fill", colorHex: "#FFD60A", order: 3),
            Category(name: "Teknoloji", icon: "laptopcomputer", colorHex: "#5856D6", order: 4),
            Category(name: "Eğlence", icon: "play.circle.fill", colorHex: "#FF2D55", order: 5)
        ]
    }
}

// MARK: - Color Extension

extension Color {
    /// Hex string'den Color oluştur
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        
        switch length {
        case 6: // RGB (24-bit)
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        case 8: // ARGB (32-bit)
            self.init(
                red: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                green: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x000000FF) / 255.0,
                opacity: Double((rgb & 0xFF000000) >> 24) / 255.0
            )
        default:
            return nil
        }
    }
    
    /// Color'dan hex string'e çevir
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        
        let r = components[0]
        let g = components.count > 1 ? components[1] : r
        let b = components.count > 2 ? components[2] : r
        
        return String(format: "#%02lX%02lX%02lX",
                      lround(Double(r) * 255),
                      lround(Double(g) * 255),
                      lround(Double(b) * 255))
    }
}
