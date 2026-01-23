import SwiftUI
import UIKit

struct SelectableTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var highlights: [Highlight]
    var font: UIFont
    var textColor: UIColor
    var onHighlight: (NSRange, String) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = CustomMenuTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        
        // Custom Highlight Action
        let highlightAction = UIMenuItem(title: "Vurgula", action: #selector(CustomMenuTextView.highlightSelection))
        UIMenuController.shared.menuItems = [highlightAction]
        
        textView.onHighlight = { range in
            // Default color hex "FFE082" (Yellow)
            self.onHighlight(range, "FFE082")
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { // Basic check, better diffing might be needed for huge texts
            uiView.text = text
        }
        
        let attributedString = NSMutableAttributedString(string: text)
        
        // Base attributes
        let range = NSRange(location: 0, length: attributedString.length)
        attributedString.addAttribute(.font, value: font, range: range)
        attributedString.addAttribute(.foregroundColor, value: textColor, range: range)
        
        // Paragraph style for line spacing (matching BookmarkDetailView)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = font.pointSize * 0.6
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        
        // Apply Highlights
        for highlight in highlights {
            if highlight.rangeLocation + highlight.rangeLength <= attributedString.length {
                let range = NSRange(location: highlight.rangeLocation, length: highlight.rangeLength)
                let color = UIColor(hex: highlight.colorHex)
                attributedString.addAttribute(.backgroundColor, value: color.withAlphaComponent(0.5), range: range)
            }
        }
        
        uiView.attributedText = attributedString
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextView
        
        init(parent: SelectableTextView) {
            self.parent = parent
        }
    }
}

// MARK: - Custom TextView with Menu Action

class CustomMenuTextView: UITextView {
    var onHighlight: ((NSRange) -> Void)?
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(highlightSelection) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    @objc func highlightSelection() {
        guard selectedRange.length > 0 else { return }
        onHighlight?(selectedRange)
    }
}

// MARK: - Helper Extension for UIColor Hex
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
