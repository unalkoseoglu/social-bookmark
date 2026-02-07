import SwiftUI
import UIKit

/// A SwiftUI wrapper for UITextView that provides native text selection handles and link support.
/// This component resolves the "all-or-nothing" selection limitation in SwiftUI's native Text.
struct SelectableTextView: View {
    let text: String
    let font: UIFont
    let color: UIColor
    let lineSpacing: CGFloat
    
    @State private var dynamicHeight: CGFloat = .zero
    
    var body: some View {
        SelectableTextViewRepresentable(
            text: text,
            font: font,
            color: color,
            lineSpacing: lineSpacing,
            dynamicHeight: $dynamicHeight
        )
        .frame(height: dynamicHeight)
    }
}

private struct SelectableTextViewRepresentable: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor
    let lineSpacing: CGFloat
    @Binding var dynamicHeight: CGFloat
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = .link
        textView.isSelectable = true
        
        // Set compression resistance to allow SwiftUI to manage the frame
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        uiView.attributedText = NSAttributedString(string: text, attributes: attributes)
        
        // Optional link customization
        uiView.linkTextAttributes = [
            .foregroundColor: uiView.tintColor ?? .systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        
        // Calculate and update the dynamic height
        DispatchQueue.main.async {
            let size = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: CGFloat.greatestFiniteMagnitude))
            if abs(dynamicHeight - size.height) > 0.1 {
                dynamicHeight = size.height
            }
        }
    }
}
