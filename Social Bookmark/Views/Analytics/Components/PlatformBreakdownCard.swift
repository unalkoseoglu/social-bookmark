import SwiftUI

struct PlatformBreakdownCard: View {
    let breakdown: [PlatformCount]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LanguageManager.shared.localized("analytics.platform_analysis"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if breakdown.isEmpty {
                Text(LanguageManager.shared.localized("analytics.no_data"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    let maxCount = Double(breakdown.max(by: { $0.count < $1.count })?.count ?? 1)
                    let total = Double(breakdown.reduce(0) { $0 + $1.count })
                    
                    ForEach(breakdown) { item in
                        HStack(spacing: 12) {
                            Text(item.source.emoji)
                                .font(.title3)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.source.displayName)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(item.count) (%\(Int((Double(item.count) / total) * 100)))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(height: 8)
                                        
                                        Capsule()
                                            .fill(item.source.color)
                                            .frame(width: geo.size.width * CGFloat(Double(item.count) / maxCount), height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                        }
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
