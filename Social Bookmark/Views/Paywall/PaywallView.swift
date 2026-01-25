//
//  PaywallView.swift
//  Social Bookmark
//
//  Created by Social Bookmark App on 24.01.2026.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = SubscriptionManager.shared
    @State private var selectedPackage: Package?
    
    /// Paywall'ın gösterilme nedeni (örn: "Bookmark sınırı doldu")
    var reason: String?
    
    var body: some View {
        ZStack {
            // Arkaplan
            Color("Background")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 40)
                        
                        Text("Social Bookmark PRO")
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                        
                        if let reason = reason {
                            Text(reason)
                                .font(.headline)
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                        } else {
                            Text("Sınırları kaldırın ve tam potansiyelinizi keşfedin.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    
                    // MARK: - Features
                    VStack(alignment: .leading, spacing: 20) {
                        FeatureRow(icon: "infinity", title: "Sınırsız Bookmark", description: "İstediğin kadar içerik kaydet.")
                        FeatureRow(icon: "icloud.fill", title: "Cloud Sync", description: "Tüm cihazlarında verilerine eriş.")
                        FeatureRow(icon: "photo.stack", title: "Çoklu Görsel", description: "Her içerik için sınırsız görsel ekle.")
                        FeatureRow(icon: "text.viewfinder", title: "Sınırsız OCR", description: "Görsellerden metin tarama.")
                    }
                    .padding(24)
                    .background(Color("CardBackground").opacity(0.5))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // MARK: - Packages
                    if manager.isLoading {
                        ProgressView()
                            .padding()
                    } else if manager.packages.isEmpty {
                        Text("Paketler yüklenemedi. Lütfen internet bağlantınızı kontrol edin.")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(manager.packages) { package in
                                PackageButton(
                                    package: package,
                                    isSelected: selectedPackage?.identifier == package.identifier
                                ) {
                                    selectedPackage = package
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Footer Actions
                    VStack(spacing: 16) {
                        Button {
                            if let package = selectedPackage {
                                Task {
                                    let success = await manager.purchase(package: package)
                                    if success {
                                        dismiss()
                                    }
                                }
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue)
                                
                                if manager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Devam Et")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(height: 56)
                        }
                        .disabled(selectedPackage == nil || manager.isLoading)
                        
                        HStack(spacing: 24) {
                            Button("Geri Yükle") {
                                Task {
                                    await manager.restorePurchases()
                                }
                            }
                            
                            Link("Kullanım Koşulları", destination: URL(string: "https://your-terms-url.com")!)
                            Link("Gizlilik", destination: URL(string: "https://your-privacy-url.com")!)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(24)
                }
            }
        }
        .onAppear {
            // İlk paketi varsayılan seç
            if selectedPackage == nil {
                selectedPackage = manager.packages.first
            }
        }
    }
}

// MARK: - Subviews

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PackageButton: View {
    let package: Package
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(package.storeProduct.subscriptionPeriod?.periodTitle ?? "Ömür Boyu")
                        .font(.headline)
                        .foregroundStyle(isSelected ? .blue : .primary)
                    
                    if let intro = package.storeProduct.introductoryDiscount {
                        Text("\(intro.localizedPriceString) / ilk \(intro.subscriptionPeriod.periodTitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(package.storeProduct.localizedPriceString)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(isSelected ? .blue : .primary)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    .background(isSelected ? Color.blue.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// RevenueCat Helpers
extension SubscriptionPeriod {
    var periodTitle: String {
        switch unit {
        case .day: return "Günlük"
        case .week: return "Haftalık"
        case .month: return "Aylık"
        case .year: return "Yıllık"
        @unknown default: return "Bilinmeyen"
        }
    }
}
