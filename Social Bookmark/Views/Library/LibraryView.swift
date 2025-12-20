//
//  LibraryView.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 18.12.2025.
//

import SwiftUI

/// Kütüphane ekranı
/// Tüm bookmarklar ve kategoriler burada listelenir
struct LibraryView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    @Binding var selectedTab: AppTab
    
    @State private var selectedSegment: LibrarySegment = .all
    @State private var selectedCategory: Category?
    @State private var showingCategoryManagement = false
    
    enum LibrarySegment: String, CaseIterable {
        case all = "all"
        case categories = "categories"
        case sources = "sources"
        
        var title: String {
            switch self {
            case .all: return String(localized: "library.segment.all")
            case .categories: return String(localized: "library.segment.categories")
            case .sources: return String(localized: "library.segment.sources")
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Segment Picker
            Picker(String(localized: "addBookmark.select"), selection: $selectedSegment) {
                ForEach(LibrarySegment.allCases, id: \.self) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Content
            switch selectedSegment {
            case .all:
                allBookmarksContent
            case .categories:
                categoriesContent
            case .sources:
                sourcesContent
            }
        }
        .navigationTitle(String(localized: "library.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Back button - Ana Sayfa'ya döner
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    selectedTab = .home
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .font(.body)
                }
            }
            
            // Category management button
            if selectedSegment == .categories {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCategoryManagement = true
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
                    }
                }
            }
        }
        .sheet(item: $selectedCategory) { category in
            CategoryDetailView(category: category, viewModel: viewModel)
        }
        .sheet(isPresented: $showingCategoryManagement) {
            NavigationStack {
                CategoriesManagementView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - All Bookmarks Content
    
    private var allBookmarksContent: some View {
        Group {
            if viewModel.bookmarks.isEmpty {
                emptyStateView(
                    icon: "bookmark",
                    title: String(localized: "library.empty.title"),
                    subtitle: String(localized: "library.empty.subtitle")
                )
            } else {
                List {
                    ForEach(viewModel.bookmarks) { bookmark in
                        NavigationLink {
                            BookmarkDetailView(
                                bookmark: bookmark,
                                viewModel: viewModel
                            )
                        } label: {
                            EnhancedBookmarkRow(bookmark: bookmark).padding()
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                
                                Task {
                                 await   viewModel.deleteBookmark(bookmark)
                                }
                            } label: {
                                Label(String(localized: "common.delete"), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task{
                                  await  viewModel.toggleReadStatus(bookmark)
                                }
                               
                            } label: {
                                Label(
                                    bookmark.isRead ? String(localized: "bookmarkDetail.markUnread") : String(localized: "bookmarkDetail.markRead"),
                                    systemImage: bookmark.isRead ? "circle" : "checkmark.circle"
                                )
                            }
                            .tint(bookmark.isRead ? .orange : .green)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Categories Content
    
    private var categoriesContent: some View {
        Group {
            if viewModel.categories.isEmpty {
                VStack(spacing: 16) {
                    emptyStateView(
                        icon: "folder",
                        title: String(localized: "library.categories.empty.title"),
                        subtitle: String(localized: "library.categories.empty.subtitle")
                    )
                    
                    Button {
                        viewModel.createDefaultCategories()
                    } label: {
                        Label(String(localized: "library.action.create_default_categories"), systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(viewModel.categories) { category in
                            LibraryCategoryCard(
                                category: category,
                                count: viewModel.bookmarkCount(for: category)
                            ) {
                                selectedCategory = category
                            }
                        }
                        
                        // Kategorisiz
                        if viewModel.uncategorizedCount > 0 {
                            UncategorizedCard(count: viewModel.uncategorizedCount) {
                                // TODO: Kategorisiz bookmarkları gösteren bir filtreleme eklenebilir
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
    
    // MARK: - Sources Content
    
    private var sourcesContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.sourcesWithCounts, id: \.source) { item in
                    SourceCard(source: item.source, count: item.count)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Empty State
    
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(subtitle)
        }
    }
}

// MARK: - Bookmark List Row

struct BookmarkListRow: View {
    let bookmark: Bookmark
    
    var body: some View {
        HStack(spacing: 12) {
            if let imageData = bookmark.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(bookmark.source.emoji)
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(bookmark.source.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Text(bookmark.source.displayName)
                    Text("•")
                    Text(bookmark.relativeDate)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                if bookmark.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
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

// MARK: - Library Category Card

struct LibraryCategoryCard: View {
    let category: Category
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(category.color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }
                
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Uncategorized Card

struct UncategorizedCard: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }
                
                Text(String(localized: "common.uncategorized"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Source Card

struct SourceCard: View {
    let source: BookmarkSource
    let count: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(source.emoji)
                    .font(.title)
                    .frame(width: 44, height: 44)
                    .background(source.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
            }
            
            Text(source.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LibraryView(
            viewModel: HomeViewModel(
                bookmarkRepository: PreviewMockRepository.shared,
                categoryRepository: PreviewMockCategoryRepository.shared
            ),
            selectedTab: .constant(.library)
        )
    }
}
