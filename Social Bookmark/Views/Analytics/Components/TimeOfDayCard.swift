import SwiftUI

struct TimeOfDayCard: View {
    let breakdown: [TimeOfDayCount]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Üretkenlik Saatleri")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .bottom, spacing: 12) {
                let maxCount = breakdown.map { $0.count }.max() ?? 1
                
                ForEach(breakdown) { item in
                    VStack(spacing: 8) {
                        Text("\(item.count)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(10, CGFloat(item.count) * 100 / CGFloat(maxCount)))
                        
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        
                        Text(item.label)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 160)
            
            if let peak = breakdown.max(by: { $0.count < $1.count }), peak.count > 0 {
                Text("En çok **\(peak.label)** vaktini seviyorsun.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}
