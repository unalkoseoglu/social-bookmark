import SwiftUI

struct ReadingHabitsCard: View {
    let readCount: Int
    let unreadCount: Int
    
    var total: Int { readCount + unreadCount }
    var percentage: Double {
        total > 0 ? Double(readCount) / Double(total) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LanguageManager.shared.localized("analytics.reading_habits"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.1), lineWidth: 10)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(percentage))
                        .stroke(
                            LinearGradient(colors: [.emerald, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.0), value: percentage)
                    
                    VStack {
                        Text("\(Int(percentage * 100))%")
                            .font(.title3.bold())
                        Text(LanguageManager.shared.localized("analytics.completed"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)
                
                VStack(alignment: .leading, spacing: 12) {
                    HabitMetricRow(color: .emerald, title: LanguageManager.shared.localized("all.stats.read"), count: readCount)
                    HabitMetricRow(color: .orange, title: LanguageManager.shared.localized("all.stats.unread"), count: unreadCount)
                    
                    if readCount >= 5 {
                        Text(LanguageManager.shared.localized("analytics.reading_habits_subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct HabitMetricRow: View {
    let color: Color
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Capsule()
                .fill(color)
                .frame(width: 4, height: 16)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline.bold())
        }
    }
}
