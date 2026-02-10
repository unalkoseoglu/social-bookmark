import SwiftUI

// MARK: - Appearance Models

enum ReaderFont: String, CaseIterable, Identifiable {
    case system = "System"
    case serif = "Serif"
    case mono = "Mono"
    case rounded = "Rounded"
    
    var id: String { rawValue }
    
    var design: Font.Design {
        switch self {
        case .system: return .default
        case .serif: return .serif
        case .mono: return .monospaced
        case .rounded: return .rounded
        }
    }
    
    var displayName: String {
        switch self {
        case .system: return LanguageManager.shared.localized("appearance.font.system")
        case .serif: return LanguageManager.shared.localized("appearance.font.serif")
        case .mono: return LanguageManager.shared.localized("appearance.font.mono")
        case .rounded: return LanguageManager.shared.localized("appearance.font.rounded")
        }
    }
}

enum ReaderTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case sepia = "Sepia"
    case dark = "Dark"
    case black = "Black"
    
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return LanguageManager.shared.localized("appearance.theme.light")
        case .sepia: return LanguageManager.shared.localized("appearance.theme.sepia")
        case .dark: return LanguageManager.shared.localized("appearance.theme.dark")
        case .black: return LanguageManager.shared.localized("appearance.theme.black")
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .light: return Color.white
        case .sepia: return Color(hex: "F8F1E3") // Warm paper color
        case .dark: return Color(hex: "1C1C1E") // System gray 6
        case .black: return Color.black
        }
    }
    
    var textColor: Color {
        switch self {
        case .light, .sepia: return .black.opacity(0.87)
        case .dark, .black: return .white.opacity(0.9)
        }
    }
    
    var secondaryTextColor: Color {
        switch self {
        case .light, .sepia: return .black.opacity(0.6)
        case .dark, .black: return .white.opacity(0.6)
        }
    }
    
    var accentColor: Color {
        switch self {
        case .sepia: return Color(hex: "5D4037") // Brownish
        default: return .blue
        }
    }
}

// MARK: - Settings View

struct AppearanceSettingsView: View {
    @AppStorage("readerFont") private var selectedFont: ReaderFont = .serif
    @AppStorage("readerFontSize") private var fontSize: Double = 18
    @AppStorage("readerTheme") private var selectedTheme: ReaderTheme = .light
    
    // We treat 'system' as a conceptual default, but in this specific UI we force a choice for reader mode override
    // Or we strictly use the 4 themes defined.
    
    var body: some View {
        VStack(spacing: 24) {
            // Theme Selector
            HStack(spacing: 16) {
                ForEach(ReaderTheme.allCases) { theme in
                    Circle()
                        .fill(theme.backgroundColor)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .strokeBorder(selectedTheme == theme ? Color.blue : Color.gray.opacity(0.3), lineWidth: selectedTheme == theme ? 2 : 1)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .foregroundColor(theme.textColor)
                                .opacity(selectedTheme == theme ? 1 : 0)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTheme = theme
                            }
                        }
                }
            }
            .padding(.horizontal)
            
            Divider()
                .overlay(selectedTheme.secondaryTextColor.opacity(0.2))
            
            // Font Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ReaderFont.allCases) { font in
                        Text(font.displayName)
                            .font(.system(size: 16, design: font.design))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                Capsule()
                                    .fill(selectedFont == font ? selectedTheme.backgroundColor.opacity(0.5) : Color.clear)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedFont == font ? selectedTheme.accentColor : selectedTheme.secondaryTextColor.opacity(0.3), lineWidth: 1)
                            )
                            .foregroundColor(selectedTheme.textColor)
                            .onTapGesture {
                                withAnimation {
                                    selectedFont = font
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
                .overlay(selectedTheme.secondaryTextColor.opacity(0.2))
            
            // Font Size
            HStack {
                Text("A")
                    .font(.system(size: 14))
                Slider(value: $fontSize, in: 14...32, step: 1)
                    .tint(selectedTheme.accentColor)
                Text("A")
                    .font(.system(size: 24))
            }
            .padding(.horizontal)
            .foregroundColor(selectedTheme.textColor)
        }
        .padding(.vertical, 24)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    AppearanceSettingsView()
}
