import SwiftUI

struct OverviewCard: View {
    let total: Int
    let thisWeek: Int
    let favorites: Int
    let readCount: Int
    let categories: Int
    let staleCount: Int
    let totalReadPercentage: Double
    var onReadTap: (() -> Void)? = nil
    var onStaleTap: (() -> Void)? = nil
    var onCategoriesTap: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LanguageManager.shared.localized("analytics.overview.title"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatItem(icon: "bookmark.fill", title: LanguageManager.shared.localized("home.stat.total"), value: "\(total)", color: .blue)
                StatItem(icon: "plus.circle.fill", title: LanguageManager.shared.localized("home.stat.this_week"), value: "\(thisWeek)", color: .green)
                StatItem(icon: "star.fill", title: LanguageManager.shared.localized("common.favorites"), value: "\(favorites)", color: .yellow)
                StatItem(icon: "checkmark.circle.fill", title: LanguageManager.shared.localized("all.stats.read"), value: "\(readCount) (%\(Int(totalReadPercentage * 100)))", color: Color.emerald) {
                    onReadTap?()
                }
                StatItem(icon: "folder.fill", title: LanguageManager.shared.localized("category_picker.title"), value: "\(categories)", color: .purple) {
                    onCategoriesTap?()
                }
                StatItem(icon: "archivebox.fill", title: LanguageManager.shared.localized("analytics.filters.stale"), value: "\(staleCount)", color: .brown) {
                    onStaleTap?()
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
