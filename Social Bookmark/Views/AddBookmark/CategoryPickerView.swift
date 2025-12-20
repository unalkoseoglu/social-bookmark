import SwiftUI

/// Bookmark formlarında kullanılan kategori seçici
struct CategoryPickerView: View {
    @Binding var selectedCategoryId: UUID?
    let categories: [Category]
    
    @State private var showingPicker = false
    
    private var selectedCategory: Category? {
        guard let id = selectedCategoryId else { return nil }
        return categories.first { $0.id == id }
    }
    
    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack {
                // "Kategori" -> "category_picker.title"
                Text("category_picker.title")
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if let category = selectedCategory {
                    HStack(spacing: 6) {
                        Image(systemName: category.icon)
                            .foregroundStyle(category.color)
                        Text(category.name)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // "Seçilmedi" -> "category_picker.none"
                    Text("category_picker.none")
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            CategorySelectionSheet(
                selectedCategoryId: $selectedCategoryId,
                categories: categories
            )
        }
    }
}

// MARK: - Category Selection Sheet

struct CategorySelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategoryId: UUID?
    let categories: [Category]
    
    var body: some View {
        NavigationStack {
            List {
                // Kategori yok seçeneği
                Button {
                    selectedCategoryId = nil
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "circle.slash")
                            .foregroundStyle(.secondary)
                        Text("category_picker.none")
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if selectedCategoryId == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                // Kategoriler listesi
                ForEach(categories) { category in
                    Button {
                        selectedCategoryId = category.id
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                            Text(category.name)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if selectedCategoryId == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            // "Kategoriler" -> "category_picker.selection_title"
            .navigationTitle("category_picker.selection_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// CategoryChip yapısı genellikle model verisi (category.name) ve ikon kullandığı için
// statik metin içermemektedir, bu yüzden kod yapısı korunmuştur.

// MARK: - Compact Category Picker (Inline)

struct CompactCategoryPicker: View {
    @Binding var selectedCategoryId: UUID?
    let categories: [Category]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Kategorisiz
                CategoryChip(
                    icon: "folder",
                    name: "Tümü",
                    color: .gray,
                    isSelected: selectedCategoryId == nil
                ) {
                    selectedCategoryId = nil
                }
                
                ForEach(categories) { category in
                    CategoryChip(
                        icon: category.icon,
                        name: category.name,
                        color: category.color,
                        isSelected: selectedCategoryId == category.id
                    ) {
                        selectedCategoryId = category.id
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let icon: String
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(name)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.2) : Color(.systemGray6))
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var selectedId: UUID? = nil
        
        var body: some View {
            Form {
                CategoryPickerView(
                    selectedCategoryId: $selectedId,
                    categories: Category.createDefaults()
                )
            }
        }
    }
    
    return PreviewWrapper()
}
