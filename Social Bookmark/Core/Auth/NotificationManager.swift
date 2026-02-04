//
//  NotificationManager.swift
//  Social Bookmark
//
//  Created by Antigravity on 28.01.2026.
//

import Foundation
import UserNotifications
import UIKit
import OneSignalFramework
import Combine

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    private override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    /// Bildirim izinlerini kontrol eder
    func checkAuthorizationStatus() {
        Task {
            let permission = await OneSignal.Notifications.permission
            await MainActor.run {
                self.isAuthorized = permission
            }
        }
    }
    
    /// Bildirim izni ister
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        Task {
            await OneSignal.Notifications.requestPermission()
            // Check permission status after request
            let accepted = await OneSignal.Notifications.permission
            await MainActor.run {
                self.isAuthorized = accepted
                completion?(accepted)
            }
        }
    }
    
    /// External User ID set eder (Böylece kullanıcıyı Supabase ID'si ile eşleştirebilirsiniz)
    func setExternalUserId(_ userId: String) {
        OneSignal.login(userId)
        print("🚀 OneSignal External User ID set edildi: \(userId)")
    }
    
    /// Kullanıcı çıkış yaptığında OneSignal oturumunu kapatır
    func logout() {
        OneSignal.logout()
    }
    
    /// Cihaz token'ını kaydeder (OneSignal bunu otomatik yapar ama referans için tutuyoruz)
    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        print("🚀 APNs Device Token: \(tokenString)")
    }
    
    /// Kayıt hatasını yönetir
    func handleRegistrationError(_ error: Error) {
        print("❌ Bildirim kaydı başarısız: \(error.localizedDescription)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Uygulama foreground'dayken bildirim geldiğinde çağrılır
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Bildirimi göster (banner, sound, badge)
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Kullanıcı bildirime tıkladığında çağrılır
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Bildirim tıklama işlemlerini burada yönetin
        print("📱 Bildirime tıklandı: \(response.notification.request.identifier)")
        completionHandler()
    }
}

