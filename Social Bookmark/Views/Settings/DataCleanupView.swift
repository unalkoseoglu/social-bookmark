//
//  DataCleanupView.swift
//  Social Bookmark
//
//  SwiftData'daki şifreli verileri temizle ve yeniden sync et
//

import SwiftUI
import SwiftData

struct DataCleanupView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var syncService = SyncService.shared
    
    @State private var status = ""
    @State private var isProcessing = false
    @State private var showConfirmation = false
    
    var body: some View {
        List {
            Section {
                Text(status.isEmpty ? "Hazır" : status)
                    .font(.caption)
            } header: {
                Text("Durum")
            }
            
            Section {
                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    Label("Tüm Verileri Temizle ve Yeniden Sync Et", systemImage: "trash.circle")
                }
                .disabled(isProcessing)
            } header: {
                Text("⚠️ Tehlikeli İşlemler")
            } footer: {
                Text("Bu işlem lokal tüm bookmark ve kategorileri silip Supabase'den yeniden indirecek. Şifreli veriler düzgün şekilde decrypt edilecek.")
            }
        }
        .navigationTitle("Data Cleanup")
        .alert("Emin misiniz?", isPresented: $showConfirmation) {
            Button("İptal", role: .cancel) { }
            Button("Evet, Temizle", role: .destructive) {
                Task {
                    await cleanupAndResync()
                }
            }
        } message: {
            Text("Tüm lokal veriler silinip Supabase'den yeniden indirilecek.")
        }
    }
    
    @MainActor
    private func cleanupAndResync() async {
        isProcessing = true
        status = "🗑️ Lokal veriler siliniyor..."
        
        do {
            // 1. Tüm bookmarkları sil
            let bookmarkDescriptor = FetchDescriptor<Bookmark>()
            let bookmarks = try modelContext.fetch(bookmarkDescriptor)
            for bookmark in bookmarks {
                modelContext.delete(bookmark)
            }
            let bookmarkCount = bookmarks.count
            
            // 2. Tüm kategorileri sil
            let categoryDescriptor = FetchDescriptor<Category>()
            let categories = try modelContext.fetch(categoryDescriptor)
            for category in categories {
                modelContext.delete(category)
            }
            let categoryCount = categories.count
            
            // 3. Değişiklikleri kaydet
            try modelContext.save()
            status = "✅ \(bookmarkCount) bookmark, \(categoryCount) kategori silindi"
            
            print("🗑️ [CLEANUP] Deleted \(bookmarkCount) bookmarks, \(categoryCount) categories")
            
            // Kısa bir bekleme
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 saniye
            
            // 4. SyncService'i configure et
            status = "⚙️ Sync servisi hazırlanıyor..."
            syncService.configure(modelContext: modelContext)
            
            print("⚙️ [CLEANUP] SyncService configured")
            
            // 5. Supabase'den yeniden indir
            status = "📥 Supabase'den indiriliyor..."
            
            try await syncService.downloadFromCloud()
            
            print("📥 [CLEANUP] Download completed")
            
            // 6. Context'i save et
            try modelContext.save()
            
            // 7. Kontrol et
            let newCategories = try modelContext.fetch(FetchDescriptor<Category>())
            let newBookmarks = try modelContext.fetch(FetchDescriptor<Bookmark>())
            
            print("📊 [CLEANUP] Downloaded \(newCategories.count) categories, \(newBookmarks.count) bookmarks")
            
            if let firstCat = newCategories.first {
                print("📂 [CLEANUP] First category: \(firstCat.name)")
                print("📂 [CLEANUP] Is encrypted: \(firstCat.name.count > 50)")
            }
            
            status = "✅ Tamamlandı! \(newCategories.count) kategori, \(newBookmarks.count) bookmark indirildi."
            
        } catch {
            print("❌ [CLEANUP] Error: \(error)")
            status = "❌ Hata: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
}

#Preview {
    NavigationStack {
        DataCleanupView()
    }
    .modelContainer(for: [Bookmark.self, Category.self])
}
