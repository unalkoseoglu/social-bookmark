import SwiftUI

struct OnboardingButton: View {
    let title: String
    let action: () -> Void
    var isPrimary: Bool = true
    var color: Color = .blue
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isPrimary ? color : Color.clear)
                .foregroundStyle(isPrimary ? .white : color)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color, lineWidth: isPrimary ? 0 : 2)
                )
        }
    }
}
