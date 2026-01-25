import SwiftUI

struct PageIndicator: View {
    let numberOfPages: Int
    let currentPage: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? color : Color.secondary.opacity(0.3))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(), value: currentPage)
            }
        }
    }
}
