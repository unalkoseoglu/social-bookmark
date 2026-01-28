//
//  NotificationManager.swift
//  Social Bookmark
//
//  Created by Antigravity on 28.01.2026.
//

import Foundation
import UserNotifications
import UIKit
internal import Combine
class NotificationManager: NSObject, ObservableObject {
    
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    private override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    /// Bildirim izinlerini kontrol eder
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// Bildirim izni ister
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                } else if let error = error {
                    print("❌ Bildirim izni hatası: \(error.localizedDescription)")
                }
                completion?(granted)
            }
        }
    }
    
    /// Cihaz token'ını kaydeder
    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        print("🚀 APNs Device Token: \(tokenString)")
        
        // TODO: Token'ı Supabase'e gönder
        // uploadTokenToSupabase(tokenString)
    }
    
    /// Kayıt hatasını yönetir
    func handleRegistrationError(_ error: Error) {
        print("❌ Bildirim kaydı başarısız: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Uygulama ön plandayken bildirim gelirse
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Bildirime tıklandığında
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📩 Bildirim tıklandı: \(userInfo)")
        
        // Bildirim içeriğine göre aksiyon alınabilir
        completionHandler()
    }
}
