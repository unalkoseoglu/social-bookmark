//
//  SearchView.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 14.12.2025.
//


import SwiftUI

/// Global arama ekranı
/// Spotlight tarzı hızlı arama deneyimi
struct SearchView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [Bookmark] = []
    @State private var recentSearches: [String] = []
    @State private var isSearching = false
    
    @FocusState private var isSearchFieldFocused: Bool
    
    // Arama sonuçlarını kategorilere ayır
    private var groupedResults: [(source: BookmarkSource, bookmarks: [Bookmark])] {
        let grouped = Dictionary(grouping: searchResults) { $0.source }
        return BookmarkSource.allCases.compactMap { source in
            guard let bookmarks = grouped[source], !bookmarks.isEmpty else { return nil }
            return (source: source, bookmarks: bookmarks)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Arama çubuğu
                searchBar
                
                // İçerik
                if searchText.isEmpty {
                    suggestionsView
                } else if isSearching {
                    loadingView
                } else if searchResults.isEmpty {
                    noResultsView
                } else {
                    resultsView
                }
            }
            .navigationTitle("Ara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isSearchFieldFocused = true
                loadRecentSearches()
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Bookmark ara...", text: $searchText)
                    .focused($isSearchFieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .onChange(of: searchText) { _, newValue in
            // Debounced search
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                if searchText == newValue && !newValue.isEmpty {
                    performSearch()
                }
            }
        }
    }
    
    // MARK: - Suggestions View
    
    private var suggestionsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Son aramalar
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Son Aramalar", systemImage: "clock")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Temizle") {
                                clearRecentSearches()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        
                        ForEach(recentSearches, id: \.self) { query in
                            Button {
                                searchText = query
                                performSearch()
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundStyle(.secondary)
                                    
                                    Text(query)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.left")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    Divider()
                }
                
                // Hızlı filtreler
                VStack(alignment: .leading, spacing: 12) {
                    Label("Hızlı Filtreler", systemImage: "sparkles")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
                        SearchSuggestionCard(
                            title: "Okunmadı",
                            icon: "circle.fill",
                            color: .orange,
                            count: viewModel.unreadCount
                        ) {
                            searchText = "is:unread"
                            searchResults = viewModel.bookmarks.filter { !$0.isRead }
                        }
                        
                        SearchSuggestionCard(
                            title: "Favoriler",
                            icon: "star.fill",
                            color: .yellow,
                            count: viewModel.favoritesCount
                        ) {
                            searchText = "is:favorite"
                            searchResults = viewModel.bookmarks.filter { $0.isFavorite }
                        }
                        
                       
                    }
                }
                
                // Kaynağa göre ara
                VStack(alignment: .leading, spacing: 12) {
                    Label("Kaynağa Göre", systemImage: "square.grid.2x2")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(viewModel.sourcesWithCounts, id: \.source) { item in
                                Button {
                                    searchText = "source:\(item.source.rawValue)"
                                    searchResults = viewModel.bookmarks.filter { $0.source == item.source }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(item.source.emoji)
                                        Text(item.source.displayName)
                                        Text("(\(item.count))")
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // Etiketler
                let allTags = Array(Set(viewModel.bookmarks.flatMap { $0.tags })).sorted()
                if !allTags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Etiketler", systemImage: "tag")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(allTags.prefix(20), id: \.self) { tag in
                                Button {
                                    searchText = "tag:\(tag)"
                                    searchResults = viewModel.bookmarks.filter { $0.tags.contains(tag) }
                                } label: {
                                    Text("#\(tag)")
                                        .font(.subheadline)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Aranıyor...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Results View
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Sonuç bulunamadı")
                .font(.headline)
            
            Text("'\(searchText)' için eşleşen bookmark yok")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Öneriler
            VStack(alignment: .leading, spacing: 8) {
                Text("Öneriler:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("• Farklı anahtar kelimeler deneyin")
                Text("• Daha kısa terimler kullanın")
                Text("• Yazım hatası olup olmadığını kontrol edin")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results View
    
    private var resultsView: some View {
        List {
            // Sonuç sayısı
            Section {
                HStack {
                    Text("\(searchResults.count) sonuç bulundu")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("'\(searchText)'")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            
            // Gruplandırılmış sonuçlar
            ForEach(groupedResults, id: \.source) { group in
                Section {
                    ForEach(group.bookmarks) { bookmark in
                        NavigationLink {
                            BookmarkDetailView(
                                bookmark: bookmark,
                                repository: viewModel.bookmarkRepository
                            )
                        } label: {
                            SearchResultRow(
                                bookmark: bookmark,
                                searchQuery: searchText
                            )
                        }
                    }
                } header: {
                    HStack {
                        Text(group.source.emoji)
                        Text(group.source.displayName)
                        Spacer()
                        Text("\(group.bookmarks.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Actions
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // Özel filtreler
        if searchText.hasPrefix("is:") || searchText.hasPrefix("source:") || 
           searchText.hasPrefix("tag:") || searchText.hasPrefix("date:") {
            // Zaten filtrelenmiş, devam et
            isSearching = false
            saveRecentSearch(searchText)
            return
        }
        
        // Normal arama
        Task { @MainActor in
            searchResults = viewModel.search(query: searchText)
            isSearching = false
            saveRecentSearch(searchText)
        }
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []
    }
    
    private func saveRecentSearch(_ query: String) {
        guard !query.isEmpty else { return }
        
        var searches = recentSearches
        searches.removeAll { $0 == query }
        searches.insert(query, at: 0)
        searches = Array(searches.prefix(10))
        
        recentSearches = searches
        UserDefaults.standard.set(searches, forKey: "recentSearches")
    }
    
    private func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: "recentSearches")
    }
}

// MARK: - Search Suggestion Card

struct SearchSuggestionCard: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                
                Text(title)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let bookmark: Bookmark
    let searchQuery: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Başlık (highlight ile)
            Text(highlightedTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            HStack(spacing: 8) {
                Text(bookmark.relativeDate)
                
                if !bookmark.isRead {
                    Text("•")
                    Text("Okunmadı")
                        .foregroundStyle(.orange)
                }
                
                if bookmark.isFavorite {
                    Text("•")
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Not varsa göster
            if !bookmark.note.isEmpty {
                Text(bookmark.note)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var highlightedTitle: AttributedString {
        var attributed = AttributedString(bookmark.title)
        
        guard !searchQuery.isEmpty,
              !searchQuery.hasPrefix("is:"),
              !searchQuery.hasPrefix("source:"),
              !searchQuery.hasPrefix("tag:"),
              !searchQuery.hasPrefix("date:") else {
            return attributed
        }
        
        // Basit highlight - tüm eşleşmeleri bul
        let lowercaseTitle = bookmark.title.lowercased()
        let lowercaseQuery = searchQuery.lowercased()
        
        if let range = lowercaseTitle.range(of: lowercaseQuery) {
            let startIndex = bookmark.title.distance(from: bookmark.title.startIndex, to: range.lowerBound)
            let length = searchQuery.count
            
            if let attributedRange = Range<AttributedString.Index>(
                NSRange(location: startIndex, length: length),
                in: attributed
            ) {
                attributed[attributedRange].backgroundColor = .yellow.opacity(0.3)
                attributed[attributedRange].foregroundColor = .primary
            }
        }
        
        return attributed
    }
}

// MARK: - Preview

#Preview {
    SearchView(
        viewModel: HomeViewModel(
            bookmarkRepository: PreviewMockRepository.shared,
            categoryRepository: PreviewMockCategoryRepository.shared
        )
    )
}
