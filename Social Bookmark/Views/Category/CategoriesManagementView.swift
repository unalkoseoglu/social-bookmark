//
//  CategoriesManagementView.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 14.12.2025.
//

import SwiftUI

/// Kategori yönetim ekranı
/// Kategorileri ekle, düzenle, sil, sırala
struct CategoriesManagementView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: Category?
    
    @State private var showingPaywall = false
    @State private var paywallReason = ""
    
    // MARK: - Body
    
    var body: some View {
        List {
            // Bilgi kartı
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(LanguageManager.shared.localized("categories.management.info_title"), systemImage: "folder.fill")
                        .font(.headline)
                    
                    Text(LanguageManager.shared.localized("categories.management.info_desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // Kategoriler
            Section {
                if viewModel.categories.isEmpty {
                    emptyCategoriesView
                } else {
                    ForEach(viewModel.sortedCategories) { category in
                        CategoryManagementRow(
                            category: category,
                            bookmarkCount: viewModel.bookmarkCount(for: category)
                        ) {
                            editingCategory = category
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                categoryToDelete = category
                                showingDeleteAlert = true
                            } label: {
                                Label(LanguageManager.shared.localized("common.delete"), systemImage: "trash")
                            }
                            
                            Button {
                                editingCategory = category
                            } label: {
                                Label(LanguageManager.shared.localized("common.edit"), systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove(perform: moveCategories)
                }
            } header: {
                HStack {
                    Text(LanguageManager.shared.localized("categories.management.count %lld", Int64(viewModel.categories.count)))
                    Spacer()
                    EditButton()
                        .font(.caption)
                }
            }
            
            // Varsayılanları ekle butonu
            if viewModel.categories.isEmpty {
                Section {
                    Button {
                        viewModel.createDefaultCategories()
                    } label: {
                        Label(LanguageManager.shared.localized("library.action.create_default_categories"), systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .navigationTitle(LanguageManager.shared.localized("categories.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    // Sıralama Menüsü
                    Menu {
                        Section(LanguageManager.shared.localized("all.menu.sort")) {
                            ForEach(HomeViewModel.CategorySortOrder.allCases) { order in
                                Button {
                                    withAnimation { viewModel.categorySortOrder = order }
                                } label: {
                                    Label(order.title, systemImage: viewModel.categorySortOrder == order ? "checkmark" : "arrow.up.arrow.down")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }

                    Button {
                        if UsageLimitService.shared.canAddCategory(context: modelContext) {
                            showingAddCategory = true
                        } else {
                            paywallReason = LanguageManager.shared.localized("pro.limit.message")
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView { category in
                viewModel.addCategory(category)
            }
        }
        .sheet(item: $editingCategory) { category in
            EditCategoryView(category: category) { updatedCategory in
                viewModel.updateCategory(updatedCategory)
            }
        }
        .alert(LanguageManager.shared.localized("category.delete.title"), isPresented: $showingDeleteAlert) {
            Button(LanguageManager.shared.localized("common.cancel"), role: .cancel) {}
            Button(LanguageManager.shared.localized("common.delete"), role: .destructive) {
                if let category = categoryToDelete {
                    viewModel.deleteCategory(category)
                }
            }
        } message: {
            if let category = categoryToDelete {
                let count = viewModel.bookmarkCount(for: category)
                if count > 0 {
                    Text(LanguageManager.shared.localized("categories.management.delete_with_bookmarks %lld %@", Int64(count), category.name))
                } else {
                    Text(LanguageManager.shared.localized("categories.management.delete_confirmation %@", category.name))
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(reason: paywallReason)
        }
    }
    
    // MARK: - Views
    
    private var emptyCategoriesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text(LanguageManager.shared.localized("categories.empty"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    // MARK: - Actions
    
    private func moveCategories(from source: IndexSet, to destination: Int) {
        var items = viewModel.sortedCategories
        items.move(fromOffsets: source, toOffset: destination)
        viewModel.reorderCategories(items)
    }
}

// MARK: - Category Management Row

struct CategoryManagementRow: View {
    let category: Category
    let bookmarkCount: Int
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(category.color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(LanguageManager.shared.localized("categories.management.bookmark_count %lld", Int64(bookmarkCount)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}

// MARK: - Add Category View

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = Color.blue
    
    let onSave: (Category) -> Void
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(LanguageManager.shared.localized("category.preview")) {
                    HStack(spacing: 14) {
                        Image(systemName: selectedIcon)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(selectedColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? LanguageManager.shared.localized("category.field.name") : name)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(LanguageManager.shared.localized("categories.management.bookmark_count %lld", Int64(2)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    TextField(LanguageManager.shared.localized("category.field.name_placeholder"), text: $name)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 20 {
                                name = String(newValue.prefix(20))
                            }
                        }
                } header: {
                    Text(LanguageManager.shared.localized("category.field.name"))
                } footer: {
                    HStack {
                        Spacer()
                        Text("\(name.count)/20")
                            .font(.caption2)
                            .foregroundStyle(name.count >= 20 ? .red : .secondary)
                    }
                }
                
                Section(LanguageManager.shared.localized("category.field.icon")) {
                    IconPickerGrid(selectedIcon: $selectedIcon)
                }
                
                Section(LanguageManager.shared.localized("category.field.color")) {
                    ColorPickerGrid(selectedColor: $selectedColor)
                }
                
                
            }
            .navigationTitle(LanguageManager.shared.localized("category.new.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LanguageManager.shared.localized("common.cancel")) { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LanguageManager.shared.localized("common.save")) { saveCategory() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }
    
    private func saveCategory() {
        let category = Category(
            name: name.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            colorHex: selectedColor.toHex() ?? "#007AFF"
        )
        onSave(category)
        dismiss()
    }
}

// MARK: - Edit Category View

struct EditCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let category: Category
    let onSave: (Category) -> Void
    
    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: Color
    
    init(category: Category, onSave: @escaping (Category) -> Void) {
        self.category = category
        self.onSave = onSave
        self._name = State(initialValue: category.name)
        self._selectedIcon = State(initialValue: category.icon)
        self._selectedColor = State(initialValue: category.color)
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(LanguageManager.shared.localized("category.preview")) {
                    HStack(spacing: 14) {
                        Image(systemName: selectedIcon)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(selectedColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? LanguageManager.shared.localized("category.field.name") : name)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(LanguageManager.shared.localized("categories.management.bookmark_count %lld", Int64(2)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    TextField(LanguageManager.shared.localized("category.field.name"), text: $name)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 20 {
                                name = String(newValue.prefix(20))
                            }
                        }
                } header: {
                    Text(LanguageManager.shared.localized("category.field.name"))
                } footer: {
                    HStack {
                        Spacer()
                        Text("\(name.count)/20")
                            .font(.caption2)
                            .foregroundStyle(name.count >= 20 ? .red : .secondary)
                    }
                }
                
                Section(LanguageManager.shared.localized("category.field.icon")) {
                    IconPickerGrid(selectedIcon: $selectedIcon)
                }
                
                Section(LanguageManager.shared.localized("category.field.color")) {
                    ColorPickerGrid(selectedColor: $selectedColor)
                }
                
                
            }
            .navigationTitle(LanguageManager.shared.localized("category.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LanguageManager.shared.localized("common.cancel")) { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LanguageManager.shared.localized("common.save")) { saveChanges() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }
    
    private func saveChanges() {
        category.name = name.trimmingCharacters(in: .whitespaces)
        category.icon = selectedIcon
        category.colorHex = selectedColor.toHex() ?? "#007AFF"
        onSave(category)
        dismiss()
    }
}

// MARK: - Icon Picker Grid (3 satır + daha fazla butonu)

struct IconPickerGrid: View {
    @Binding var selectedIcon: String
    @State private var showAllIcons = false
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)
    
    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CategoryDesign.quickIcons, id: \.self) { icon in
                    IconButton(icon: icon, isSelected: selectedIcon == icon) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedIcon = icon
                        }
                    }
                }
            }
            
            Button {
                showAllIcons = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.body)
                    Text(LanguageManager.shared.localized("category.icons.show_more"))
                        .font(.subheadline)
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showAllIcons) {
            AllIconsPickerView(selectedIcon: $selectedIcon)
        }
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 46, height: 46)
                .background(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
                .foregroundStyle(isSelected ? .blue : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
                .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - All Icons Picker View

struct AllIconsPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String
    @State private var searchText = ""
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)
    
    private var filteredCategories: [IconCategory] {
        if searchText.isEmpty {
            return CategoryDesign.allIcons
        }
        
        return CategoryDesign.allIcons.compactMap { category in
            let filteredIcons = category.icons.filter { $0.localizedCaseInsensitiveContains(searchText) }
            if filteredIcons.isEmpty { return nil }
            return IconCategory(name: category.name, icons: filteredIcons)
        }
    }
    
    private var totalIconCount: Int {
        CategoryDesign.allIcons.reduce(0) { $0 + $1.icons.count }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if searchText.isEmpty {
                        Text(LanguageManager.shared.localized("category.icons.total_count %lld", Int64(totalIconCount)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    
                    ForEach(filteredCategories) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(category.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                Text("(\(category.icons.count))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(category.icons, id: \.self) { icon in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            selectedIcon = icon
                                        }
                                        dismiss()
                                    } label: {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .frame(width: 50, height: 50)
                                            .background(selectedIcon == icon ? Color.blue.opacity(0.15) : Color(.systemGray4))
                                            .foregroundStyle(selectedIcon == icon ? .blue : .secondary)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            .padding(.horizontal)

                        }
                    }
                }
                
                .padding(.vertical)
            }
            .navigationTitle(LanguageManager.shared.localized("category.icons.all_title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: LanguageManager.shared.localized("category.icons.search"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LanguageManager.shared.localized("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Color Picker Grid

struct ColorPickerGrid: View {
    @Binding var selectedColor: Color
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(Array(CategoryDesign.colors.enumerated()), id: \.offset) { index, color in
                if index == CategoryDesign.colors.count - 1 {
                    ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                        .scaleEffect(1.3)
                        .frame(width: 34, height: 34)
                } else {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedColor = color
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 34, height: 34)
                                .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                            
                            if selectedColor == color {
                                Circle()
                                    .stroke(Color.primary, lineWidth: 2)
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundStyle(isDarkColor(color) ? .white : .black)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 10)
    }
    
    private func isDarkColor(_ color: Color) -> Bool {
        return color == .black || color == .indigo || color == .blue || color == .brown || color == .purple
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CategoriesManagementView(
            viewModel: HomeViewModel(
                bookmarkRepository: PreviewMockRepository.shared,
                categoryRepository: PreviewMockCategoryRepository.shared
            )
        )
    }
}

#Preview("Add Category") {
    AddCategoryView { _ in }
}

#Preview("All Icons") {
    AllIconsPickerView(selectedIcon: .constant("folder.fill"))
}
