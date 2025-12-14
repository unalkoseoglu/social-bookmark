//
//  QuickFilterDetailView.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 14.12.2025.
//


import SwiftUI

/// Hızlı filtre detay ekranı
/// Okunmadı, Favoriler, Bugün, Bu Hafta gibi filtrelerin içeriğini gösterir
struct QuickFilterDetailView: View {
    // MARK: - Properties
    
    let filter: QuickFilter
    @Bindable var viewModel: HomeViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var bookmarks: [Bookmark] = []
    @State private var searchText = ""
    @State private var sortOption: SortOption = .newest
    
    private var filteredBookmarks: [Bookmark] {
        var result = bookmarks
        
        // Arama filtresi
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.note.lowercased().contains(query)
            }
        }
        
        // Sıralama
        switch sortOption {
        case .newest:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            result.sort { $0.createdAt < $1.createdAt }
        case .alphabetical:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .source:
            result.sort { $0.source.displayName < $1.source.displayName }
        }
        
        return result
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    emptyStateView
                } else {
                    bookmarksList
                }
            }
            .navigationTitle(filter.title)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Ara...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sırala", selection: $sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Label(option.title, systemImage: option.icon)
                                    .tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadBookmarks()
            }
        }
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: filter.icon)
                .font(.system(size: 60))
                .foregroundStyle(filter.color)
            
            Text(emptyStateTitle)
                .font(.title3)
                .fontWeight(.medium)
            
            Text(emptyStateSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .unread:
            return "Tüm bookmarklar okundu!"
        case .favorites:
            return "Henüz favori yok"
        case .today:
            return "Bugün eklenen yok"
        case .thisWeek:
            return "Bu hafta eklenen yok"
        case .uncategorized:
            return "Tüm bookmarklar kategorilendi"
        case .source(let source):
            return "\(source.displayName) bookmark yok"
        }
    }
    
    private var emptyStateSubtitle: String {
        switch filter {
        case .unread:
            return "Harika! Tüm içerikleri gözden geçirdin"
        case .favorites:
            return "Beğendiğin bookmarkları favorilere ekle"
        case .today:
            return "Yeni içerik keşfetmeye başla"
        case .thisWeek:
            return "Bookmark eklemek için paylaş butonunu kullan"
        case .uncategorized:
            return "Tüm bookmarkların bir kategorisi var"
        case .source:
            return "Bu kaynaktan içerik kaydetmeye başla"
        }
    }
    
    private var bookmarksList: some View {
        List {
            // Header bilgisi
            Section {
                HStack(spacing: 16) {
                    Image(systemName: filter.icon)
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(filter.color)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(filteredBookmarks.count) bookmark")
                            .font(.headline)
                        
                        if filter == .unread {
                            Button("Tümünü Okundu İşaretle") {
                                markAllAsRead()
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Bookmark listesi
            Section {
                ForEach(filteredBookmarks) { bookmark in
                    NavigationLink {
                        BookmarkDetailView(
                            bookmark: bookmark,
                            repository: viewModel.bookmarkRepository
                        )
                    } label: {
                        FilterBookmarkRow(
                            bookmark: bookmark,
                            showSource: !isSourceFilter
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteBookmark(bookmark)
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleRead(bookmark)
                        } label: {
                            Label(
                                bookmark.isRead ? "Okunmadı" : "Okundu",
                                systemImage: bookmark.isRead ? "circle" : "checkmark.circle.fill"
                            )
                        }
                        .tint(bookmark.isRead ? .orange : .green)
                        
                        Button {
                            toggleFavorite(bookmark)
                        } label: {
                            Label(
                                bookmark.isFavorite ? "Favoriden Çıkar" : "Favorile",
                                systemImage: bookmark.isFavorite ? "star.slash" : "star.fill"
                            )
                        }
                        .tint(.yellow)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var isSourceFilter: Bool {
        if case .source = filter {
            return true
        }
        return false
    }
    
    // MARK: - Actions
    
    private func loadBookmarks() {
        bookmarks = viewModel.bookmarks(for: filter)
    }
    
    private func deleteBookmark(_ bookmark: Bookmark) {
        viewModel.deleteBookmark(bookmark)
        loadBookmarks()
    }
    
    private func toggleRead(_ bookmark: Bookmark) {
        viewModel.toggleReadStatus(bookmark)
        
        // Eğer okunmadı filtresindeyse ve okundu işaretlendiyse listeden çıkar
        if filter == .unread && bookmark.isRead {
            loadBookmarks()
        }
    }
    
    private func toggleFavorite(_ bookmark: Bookmark) {
        viewModel.toggleFavorite(bookmark)
        
        // Eğer favoriler filtresindeyse ve favoriden çıkarıldıysa listeden çıkar
        if filter == .favorites && !bookmark.isFavorite {
            loadBookmarks()
        }
    }
    
    private func markAllAsRead() {
        for bookmark in bookmarks where !bookmark.isRead {
            bookmark.isRead = true
            viewModel.bookmarkRepository.update(bookmark)
        }
        loadBookmarks()
        viewModel.refresh()
    }
}

// MARK: - Sort Option

enum SortOption: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case alphabetical
    case source
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .newest: return "En Yeni"
        case .oldest: return "En Eski"
        case .alphabetical: return "Alfabetik"
        case .source: return "Kaynağa Göre"
        }
    }
    
    var icon: String {
        switch self {
        case .newest: return "arrow.down.circle"
        case .oldest: return "arrow.up.circle"
        case .alphabetical: return "textformat.abc"
        case .source: return "square.grid.2x2"
        }
    }
}

// MARK: - Filter Bookmark Row

struct FilterBookmarkRow: View {
    let bookmark: Bookmark
    var showSource: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            if showSource {
                Text(bookmark.source.emoji)
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .background(bookmark.source.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if showSource {
                        Text(bookmark.source.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .foregroundStyle(.tertiary)
                    }
                    
                    Text(bookmark.relativeDate)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    if let categoryId = bookmark.categoryId {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        
                        Image(systemName: "folder.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                if bookmark.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
                
                if !bookmark.isRead {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    QuickFilterDetailView(
        filter: .unread,
        viewModel: HomeViewModel(
            bookmarkRepository: PreviewMockRepository.shared,
            categoryRepository: PreviewMockCategoryRepository.shared
        )
    )
}
