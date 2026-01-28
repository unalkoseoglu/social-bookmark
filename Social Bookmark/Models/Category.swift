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
    
    /// Güncellenme tarihi (YENİ - Sync için) - Migration için opsiyonel yaptık
    var updatedAt: Date?
    
    // MARK: - Computed Properties
    
    /// Hex'ten Color'a çevir
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    /// ✅ Sync için güvenli tarih (nil ise createdAt döner)
    var lastUpdated: Date {
        updatedAt ?? createdAt
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
        self.updatedAt = Date()
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
    static var emerald: Color { Color(hex: "#10B981") ?? .green }


    /// Hex string'den Color oluştur (failable)
    /// Destek: RGB (#RRGGBB) ve ARGB (#AARRGGBB)
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        switch hexSanitized.count {
        case 6: // RRGGBB
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        case 8: // AARRGGBB
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

    /// Hex string'den Color oluştur (non-optional)
    /// Hex parse edilemezse fallback döner.
    init(hex: String, fallback: Color = .secondary) {
        if let c = Color(hex: hex) { // yukarıdaki init?(hex:) çağrılır
            self = c
        } else {
            self = fallback
        }
    }

    /// Color -> Hex string (#RRGGBB). Opacity dahil edilmez.
    func toHex() -> String? {
        let uiColor = UIColor(self)

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }

        return String(
            format: "#%02lX%02lX%02lX",
            lround(Double(r) * 255),
            lround(Double(g) * 255),
            lround(Double(b) * 255)
        )
    }

    /// Color -> Hex string (#AARRGGBB) (opsiyonel)
    func toHexWithAlpha() -> String? {
        let uiColor = UIColor(self)

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }

        return String(
            format: "#%02lX%02lX%02lX%02lX",
            lround(Double(a) * 255),
            lround(Double(r) * 255),
            lround(Double(g) * 255),
            lround(Double(b) * 255)
        )
    }
}

