//
//  NetworkMonitor.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//

import Foundation
import Network
import Combine

/// Ağ bağlantısı durumunu izler
/// Offline-first sync stratejisi için kritik
///
/// Kullanım:
/// ```swift
/// NetworkMonitor.shared.$isConnected
///     .sink { connected in
///         if connected {
///             // Sync başlat
///         }
///     }
/// ```
@MainActor
final class NetworkMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    
    /// İnternet bağlantısı var mı?
    @Published private(set) var isConnected = true
    
    /// Bağlantı türü
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    /// Expensive connection mu? (cellular, hotspot)
    @Published private(set) var isExpensive = false
    
    /// Constrained connection mu? (low data mode)
    @Published private(set) var isConstrained = false
    
    // MARK: - Properties
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Initialization
    
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
        print("📡 Network monitoring started")
    }
    
    private func stopMonitoring() {
        monitor.cancel()
        print("📡 Network monitoring stopped")
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        // Bağlantı türünü belirle
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
        
        // Durum değiştiyse log
        if wasConnected != isConnected {
            if isConnected {
                print("✅ Network: Connected via \(connectionType)")
                NotificationCenter.default.post(name: .networkDidConnect, object: nil)
            } else {
                print("⚠️ Network: Disconnected")
                NotificationCenter.default.post(name: .networkDidDisconnect, object: nil)
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Sync için uygun mu?
    /// WiFi veya unlimited cellular ise true
    var isSuitableForSync: Bool {
        isConnected && (!isExpensive || !isConstrained)
    }
    
    /// Büyük dosya upload için uygun mu?
    var isSuitableForLargeUpload: Bool {
        isConnected && connectionType == .wifi && !isConstrained
    }
    
    /// Bağlantı durumu özeti
    var statusDescription: String {
        guard isConnected else { return "Çevrimdışı" }
        
        var desc = connectionType.description
        if isExpensive { desc += " (Sınırlı)" }
        if isConstrained { desc += " (Düşük Veri)" }
        return desc
    }
}

// MARK: - Connection Type

extension NetworkMonitor {
    enum ConnectionType: String {
        case wifi = "WiFi"
        case cellular = "Mobil Veri"
        case ethernet = "Ethernet"
        case unknown = "Bilinmiyor"
        
        var description: String { rawValue }
        
        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .ethernet: return "cable.connector"
            case .unknown: return "questionmark.circle"
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkDidConnect = Notification.Name("networkDidConnect")
    static let networkDidDisconnect = Notification.Name("networkDidDisconnect")
}