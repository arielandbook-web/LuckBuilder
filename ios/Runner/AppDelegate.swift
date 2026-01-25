import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // ✅ 設定前景通知顯示（讓 App 在前景時也能顯示橫幅通知）
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // ✅ iOS 10+ 前景通知顯示設定
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // 允許在前景顯示通知橫幅、聲音和角標
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  // ✅ 用戶點擊或滑掉通知時的回調
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // 🔍 調試日誌：確認 iOS 是否收到通知響應
    let actionId = response.actionIdentifier
    let categoryId = response.notification.request.content.categoryIdentifier
    print("═══════════════════════════════════════════")
    print("📱 [iOS Native] didReceive response 觸發")
    print("   actionIdentifier: \(actionId)")
    print("   categoryIdentifier: \(categoryId)")
    print("   是否為滑掉: \(actionId == UNNotificationDismissActionIdentifier)")
    print("═══════════════════════════════════════════")
    
    // ✅ 讓 Flutter 處理通知響應
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
