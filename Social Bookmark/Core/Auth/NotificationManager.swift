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
        self.isAuthorized = OneSignal.Notifications.permissionStatus == .authorized
    }
    
    /// Bildirim izni ister
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        OneSignal.Notifications.requestPermission({ accepted in
            DispatchQueue.main.async {
                self.isAuthorized = accepted
                completion?(accepted)
            }
        }, fallbackToSettings: true)
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
}

// MARK: - OneSignal Notification Delegate
// OneSignal kendi delegelerini yönetir ancak isterseniz ek özelleştirme yapabiliriz.
