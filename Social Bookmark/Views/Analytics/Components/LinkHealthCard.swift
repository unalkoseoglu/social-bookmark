import SwiftUI

struct LinkHealthCard: View {
    let stats: LinkHealthStats
    let brokenLinks: [BookmarkSnapshot]
    var onBookmarkTap: ((BookmarkSnapshot) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bağlantı Sağlığı")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.1), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: stats.activePercentage)
                        .stroke(stats.activePercentage > 0.9 ? Color.emerald : Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(stats.activePercentage * 100))%")
                        .font(.headline.bold())
                }
                .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(stats.active) Aktif", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.emerald)
                        .font(.subheadline)
                    
                    Label("\(stats.broken) Kontrol Et", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                }
            }
            
            if !brokenLinks.isEmpty {
                Divider()
                
                Text("Kontrol Edilmesi Gerekenler")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                ForEach(brokenLinks.prefix(3)) { link in
                    Button {
                        onBookmarkTap?(link)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(link.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                if let url = link.url {
                                    Text(url)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                if brokenLinks.count > 3 {
                    Text("\(brokenLinks.count - 3) tane daha...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}
