//
//  NetworkMonitor.swift
//  Social Bookmark
//
//  Created by Claude on 15.12.2025.
//
//  Ağ bağlantı durumunu izler
//

import Foundation
import Network
internal import Combine
import OSLog

/// Ağ durumu izleme servisi
@MainActor
final class NetworkMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    // MARK: - Private Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Types
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    // MARK: - Initialization
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stopMonitoring()
        }
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionStatus(path)
            }
        }
        monitor.start(queue: queue)
        Logger.network.info("Network monitoring started")
    }
    
    func stopMonitoring() {
        monitor.cancel()
        Logger.network.info("Network monitoring stopped")
    }
    
    // MARK: - Private Methods
    
    private func updateConnectionStatus(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        
        // Connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
        
        // Log status change
        if wasConnected != isConnected {
            if isConnected {
                Logger.network.info("Connected via \(String(describing: self.connectionType))")
                NotificationCenter.default.post(name: .networkDidConnect, object: nil)
            } else {
                Logger.network.warning("Disconnected")
                NotificationCenter.default.post(name: .networkDidDisconnect, object: nil)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkDidConnect    = Notification.Name("networkDidConnect")
    static let networkDidDisconnect = Notification.Name("networkDidDisconnect")
}
