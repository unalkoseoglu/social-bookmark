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
                Text(status.isEmpty ? String(localized: "cleanup.status.ready") : status)
                    .font(.caption)
            } header: {
                Text(String(localized: "cleanup.status.label"))
            }
            
            Section {
                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    Label(String(localized: "cleanup.action.delete_all"), systemImage: "trash.circle")
                }
                .disabled(isProcessing)
            } header: {
                Text(String(localized: "cleanup.section.danger"))
            } footer: {
                Text(String(localized: "cleanup.footer.danger"))
            }
        }
        .navigationTitle(String(localized: "cleanup.title"))
        .alert(String(localized: "cleanup.alert.title"), isPresented: $showConfirmation) {
            Button(String(localized: "cleanup.alert.cancel"), role: .cancel) { }
            Button(String(localized: "cleanup.alert.confirm"), role: .destructive) {
                Task {
                    await cleanupAndResync()
                }
            }
        } message: {
            Text(String(localized: "cleanup.alert.message"))
        }
    }
    
    @MainActor
    private func cleanupAndResync() async {
        isProcessing = true
        status = String(localized: "cleanup.status.deleting")
        
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
            status = String(localized: "cleanup.status.deleted_count \(bookmarkCount) \(categoryCount)")
            
            print("🗑️ [CLEANUP] Deleted \(bookmarkCount) bookmarks, \(categoryCount) categories")
            
            // Kısa bir bekleme
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 saniye
            
            // 4. SyncService'i configure et
            status = String(localized: "cleanup.status.preparing")
            syncService.configure(modelContext: modelContext)
            
            print("⚙️ [CLEANUP] SyncService configured")
            
            // 5. Supabase'den yeniden indir
            status = String(localized: "cleanup.status.downloading")
            
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
            
            status = String(localized: "cleanup.status.completed_count \(newCategories.count) \(newBookmarks.count)")
            
        } catch {
            print("❌ [CLEANUP] Error: \(error)")
            status = String(localized: "cleanup.status.error \(error.localizedDescription)")
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
