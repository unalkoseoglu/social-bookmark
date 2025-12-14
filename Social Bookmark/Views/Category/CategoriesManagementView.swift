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
    
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: Category?
    
    // MARK: - Body
    
    var body: some View {
        List {
            // Bilgi kartı
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Kategoriler", systemImage: "folder.fill")
                        .font(.headline)
                    
                    Text("Bookmarklarını düzenlemek için kategoriler oluştur. Sürükleyerek sıralayabilirsin.")
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
                    ForEach(viewModel.categories) { category in
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
                                Label("Sil", systemImage: "trash")
                            }
                            
                            Button {
                                editingCategory = category
                            } label: {
                                Label("Düzenle", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove(perform: moveCategories)
                }
            } header: {
                HStack {
                    Text("Kategoriler (\(viewModel.categories.count))")
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
                        Label("Varsayılan Kategorileri Ekle", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .navigationTitle("Kategoriler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus")
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
        .alert("Kategoriyi Sil", isPresented: $showingDeleteAlert) {
            Button("İptal", role: .cancel) {}
            Button("Sil", role: .destructive) {
                if let category = categoryToDelete {
                    viewModel.deleteCategory(category)
                }
            }
        } message: {
            if let category = categoryToDelete {
                let count = viewModel.bookmarkCount(for: category)
                if count > 0 {
                    Text("'\(category.name)' kategorisinde \(count) bookmark var. Bu bookmarklar kategorisiz kalacak.")
                } else {
                    Text("'\(category.name)' kategorisini silmek istediğine emin misin?")
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var emptyCategoriesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("Henüz kategori yok")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    // MARK: - Actions
    
    private func moveCategories(from source: IndexSet, to destination: Int) {
        var categories = viewModel.categories
        categories.move(fromOffsets: source, toOffset: destination)
        
        // Sıralamayı güncelle
        for (index, category) in categories.enumerated() {
            category.order = index
            viewModel.updateCategory(category)
        }
        
        viewModel.refresh()
    }
}

// MARK: - Category Management Row

struct CategoryManagementRow: View {
    let category: Category
    let bookmarkCount: Int
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            // İkon
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(category.color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Bilgiler
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("\(bookmarkCount) bookmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Düzenle butonu
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
                // İsim
                Section("Kategori Adı") {
                    TextField("Örn: İş, Okuma Listesi, Araştırma", text: $name)
                }
                
                // İkon seçimi
                Section("İkon") {
                    IconPickerGrid(selectedIcon: $selectedIcon)
                }
                
                // Renk seçimi
                Section("Renk") {
                    ColorPickerGrid(selectedColor: $selectedColor)
                }
                
                // Önizleme
                Section("Önizleme") {
                    HStack(spacing: 14) {
                        Image(systemName: selectedIcon)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(selectedColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "Kategori Adı" : name)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("0 bookmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Yeni Kategori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") {
                        saveCategory()
                    }
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
                // İsim
                Section("Kategori Adı") {
                    TextField("Kategori adı", text: $name)
                }
                
                // İkon seçimi
                Section("İkon") {
                    IconPickerGrid(selectedIcon: $selectedIcon)
                }
                
                // Renk seçimi
                Section("Renk") {
                    ColorPickerGrid(selectedColor: $selectedColor)
                }
                
                // Önizleme
                Section("Önizleme") {
                    HStack(spacing: 14) {
                        Image(systemName: selectedIcon)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(selectedColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "Kategori Adı" : name)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("Düzenleniyor")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Kategori Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") {
                        saveChanges()
                    }
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

// MARK: - Icon Picker Grid

struct IconPickerGrid: View {
    @Binding var selectedIcon: String
    
    private let icons = [
        // Klasörler
        "folder.fill", "folder.badge.plus", "folder.badge.gear",
        // İş
        "briefcase.fill", "building.2.fill", "chart.bar.fill",
        // Okuma
        "book.fill", "books.vertical.fill", "newspaper.fill",
        // Teknoloji
        "laptopcomputer", "desktopcomputer", "iphone",
        // Sosyal
        "person.2.fill", "bubble.left.and.bubble.right.fill", "network",
        // Eğlence
        "play.circle.fill", "music.note", "gamecontroller.fill",
        // Diğer
        "star.fill", "heart.fill", "bookmark.fill",
        "lightbulb.fill", "graduationcap.fill", "leaf.fill",
        "cart.fill", "airplane", "house.fill"
    ]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(icons, id: \.self) { icon in
                Button {
                    selectedIcon = icon
                } label: {
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color(.systemGray6))
                        .foregroundStyle(selectedIcon == icon ? .blue : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedIcon == icon ? Color.blue : .clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Color Picker Grid

struct ColorPickerGrid: View {
    @Binding var selectedColor: Color
    
    private let colors: [Color] = [
        .blue, .purple, .pink, .red, .orange, .yellow,
        .green, .mint, .teal, .cyan, .indigo, .brown
    ]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(colors, id: \.self) { color in
                Button {
                    selectedColor = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                        )
                        .overlay(
                            Circle()
                                .stroke(color, lineWidth: selectedColor == color ? 2 : 0)
                                .scaleEffect(1.3)
                        )
                }
                .buttonStyle(.plain)
            }
        }
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