//
//  CategoryRepositoryProtocol.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 14.12.2025.
//


import Foundation

/// Kategori Repository Protocol
/// Kategori verilerine erişim için arayüz
protocol CategoryRepositoryProtocol {
    /// Tüm kategorileri getir (sıralı)
    func fetchAll() -> [Category]
    
    /// ID ile kategori getir
    func fetch(by id: UUID) -> Category?
    
    /// Yeni kategori oluştur
    func create(_ category: Category) throws
    
    /// Kategori güncelle
    func update(_ category: Category)
    
    /// Kategori sil
    func delete(_ category: Category)
    
    /// Kategori için bookmark sayısı
    func bookmarkCount(for categoryId: UUID) -> Int
    
    /// Toplam kategori sayısı
    var count: Int { get }
    
    /// Varsayılan kategorileri oluştur (ilk açılış için)
    func createDefaultsIfNeeded()
}
