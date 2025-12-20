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
    @State private var useCustomColor = false
    @State private var customColor: Color = .blue

    
    // MARK: - Body
    
    var body: some View {
        List {
            // Bilgi kartı
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("categories.management.info_title", systemImage: "folder.fill")
                        .font(.headline)
                    
                    Text("categories.management.info_desc")
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
                                Label("common.delete", systemImage: "trash")
                            }
                            
                            Button {
                                editingCategory = category
                            } label: {
                                Label("common.edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove(perform: moveCategories)
                }
            } header: {
                HStack {
                    Text("categories.management.count \(viewModel.categories.count)")
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
                        Label("library.action.create_default_categories", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .navigationTitle("categories.title")
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
                Task{
                  await  viewModel.updateCategory(updatedCategory)
                }
               
            }
        }
        .alert("category.delete.title", isPresented: $showingDeleteAlert) {
            Button("common.cancel", role: .cancel) {}
            Button("common.delete", role: .destructive) {
                if let category = categoryToDelete {
                    Task{
                      await  viewModel.deleteCategory(category)
                    }
                }
            }
        } message: {
            if let category = categoryToDelete {
                let count = viewModel.bookmarkCount(for: category)
                if count > 0 {
                    Text("categories.management.delete_with_bookmarks \(count) \(category.name)")
                } else {
                    Text("categories.management.delete_confirmation \(category.name)")
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
            
            Text("categories.empty")
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
            Task{
              await  viewModel.updateCategory(category)
            }
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
                
                Text("categories.management.bookmark_count \(bookmarkCount)")
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
                Section("category.field.name") {
                    TextField("category.field.name_placeholder", text: $name)
                }
                
                // İkon seçimi
                Section("category.field.icon") {
                    IconPickerGrid(selectedIcon: $selectedIcon)
                }
                
                // Renk seçimi
                Section("category.field.color") {
                    ColorPickerGrid(selectedColor: $selectedColor)
                }
                
                // Önizleme
                Section("category.preview") {
                    HStack(spacing: 14) {
                        Image(systemName: selectedIcon)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(selectedColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? String(localized: "category.field.name") : name)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("categories.management.bookmark_count \(2)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("category.new.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.save") {
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
                Section("category.field.name") {
                    TextField("category.field.name", text: $name)
                }
                
                // İkon seçimi
                Section("category.field.icon") {
                    IconPickerGrid(selectedIcon: $selectedIcon)
                }
                
                // Renk seçimi
                Section("category.field.color") {
                    ColorPickerGrid(selectedColor: $selectedColor)
                }
                
                // Önizleme
                Section("category.preview") {
                    HStack(spacing: 14) {
                        Image(systemName: selectedIcon)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(selectedColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "category.field.name" : name)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("categories.management.editing_status")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("category.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.save") {
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
// IconPickerGrid ve ColorPickerGrid yapıları statik metin içermediği için (sadece sistem ikonları ve renkler) oldukları gibi bırakılmıştır.

// MARK: - Icon Picker Grid
struct CategoryDesign {
    static let icons: [String] = [
        // Temel & Klasör
        "folder.fill", "folder.badge.plus", "folder.badge.gear", "archivebox.fill", "tray.full.fill",
        // İş & Eğitim
        "briefcase.fill", "building.2.fill", "chart.bar.fill", "graduationcap.fill", "pencil.and.outline",
        "doc.text.fill", "signature", "calendar", "book.fill", "books.vertical.fill", "newspaper.fill",
        // Teknoloji
        "laptopcomputer", "desktopcomputer", "iphone", "ipad", "applewatch", "terminal.fill", "cpu",
        // Sosyal & İletişim
        "person.2.fill", "bubble.left.and.bubble.right.fill", "network", "envelope.fill", "phone.fill",
        // Medya & Eğlence
        "play.circle.fill", "music.note", "gamecontroller.fill", "camera.fill", "tv.fill", "headphones",
        // Yaşam & Hobi
        "star.fill", "heart.fill", "bookmark.fill", "lightbulb.fill", "leaf.fill", "cart.fill",
        "airplane", "house.fill", "car.fill", "bicycle", "tram.fill", "map.fill",
        // Sağlık & Spor
        "cross.case.fill", "pills.fill", "figure.run", "dumbbell.fill", "fork.knife", "cup.and.saucer.fill",
        // Finans & Araçlar
        "creditcard.fill", "banknote.fill", "hammer.fill", "wrench.and.screwdriver.fill", "bolt.fill", "key.fill"
    ]
    
    static let colors: [Color] = [
        .blue, .purple, .pink, .red, .orange, .yellow,
        .green, .mint, .teal, .cyan, .indigo, .brown,
        .gray, .black, .accentColor,
       
    ]
}

// MARK: - Modern Icon Picker Grid

struct IconPickerGrid: View {
    @Binding var selectedIcon: String
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 15) {
            ForEach(CategoryDesign.icons, id: \.self) { icon in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        selectedIcon = icon
                    }
                } label: {
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(width: 46, height: 46)
                        .background(selectedIcon == icon ? Color.blue.opacity(0.15) : Color(.systemGray6))
                        .foregroundStyle(selectedIcon == icon ? .blue : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
                        )
                        .scaleEffect(selectedIcon == icon ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Modern Color Picker Grid

struct ColorPickerGrid: View {
    @Binding var selectedColor: Color
    @State private var showCustomColorPicker = false

    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 18) {
            ForEach(CategoryDesign.colors, id: \.self) { color in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedColor = color
                    }
                } label: {
                    ZStack {
                        if color == CategoryDesign.colors.last{
                            ColorPicker("category.color.picker", selection: $selectedColor, supportsOpacity: false)
                                .labelsHidden().controlSize(.extraLarge).scaleEffect(1.2)
                        }else{
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
                    
                }
                .buttonStyle(.plain)
            }
            
        }
        .padding(.vertical, 10)
    }
    
    // Kontrast kontrolü (Koyu renklerde checkmark beyaz, açıklarda siyah olsun)
    private func isDarkColor(_ color: Color) -> Bool {
        // Basit bir yaklaşım, daha kompleks lüminans kontrolü de yapılabilir
        return color == .black || color == .indigo || color == .blue || color == .brown
    }
}

// MARK: - Preview

struct CustomColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: Color

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                ColorPicker(
                    "Renk Seç",
                    selection: $selectedColor,
                    supportsOpacity: false
                )
                .labelsHidden()
                .padding()

                // Önizleme
                Circle()
                    .fill(selectedColor)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )

                Spacer()
            }
            .navigationTitle("Özel Renk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
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
