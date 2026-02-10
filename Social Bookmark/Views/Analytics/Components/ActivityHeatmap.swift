import SwiftUI

struct ActivityHeatmap: View {
    let activity: [DateActivity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LanguageManager.shared.localized("analytics.last_30_days_activity"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 4) {
                    let maxCount = activity.map { $0.count }.max() ?? 1
                    
                    ForEach(activity) { day in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(day.count > 0 ? Color.blue.opacity(max(0.2, Double(day.count) / Double(maxCount))) : Color.gray.opacity(0.1))
                                .frame(width: 8, height: max(4, CGFloat(day.count) * 80 / CGFloat(maxCount)))
                            
                            if isMonday(day.date) {
                                Text(shortDay(day.date))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            } else {
                                Color.clear
                                    .frame(width: 8, height: 10)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 100)
            
            if let mostActive = activity.max(by: { $0.count < $1.count }), mostActive.count > 0 {
                Text(LanguageManager.shared.localized("analytics.most_active_day_template %@", formattedDate(mostActive.date)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private func isMonday(_ date: Date) -> Bool {
        Calendar.current.component(.weekday, from: date) == 2
    }
    
    private func shortDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date).prefix(1).uppercased()
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
