# Firebase 設定指南

## 前置需求

1. 已安裝 Flutter SDK
2. 已執行 `flutter pub get` 安裝依賴

## 步驟 1：建立 Firebase 專案

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 點擊「新增專案」或「Add project」
3. 輸入專案名稱：`learningbubbles`（或您喜歡的名稱）
4. 按照指示完成專案建立

## 步驟 2：設定 iOS 應用

### 2.1 在 Firebase Console 註冊 iOS 應用

1. 在 Firebase Console 中，點擊專案設定（⚙️）
2. 在「您的應用程式」區塊，點擊 iOS 圖示
3. 輸入 iOS Bundle ID：
   - 預設通常是：`com.example.learningbubbles`
   - 您可以在 `ios/Runner.xcodeproj` 或 `ios/Runner/Info.plist` 中查看實際的 Bundle ID
4. 下載 `GoogleService-Info.plist` 檔案

### 2.2 將配置檔添加到 iOS 專案

1. 將下載的 `GoogleService-Info.plist` 複製到：
   ```
   ios/Runner/GoogleService-Info.plist
   ```

2. 在 Xcode 中開啟專案：
   ```bash
   open ios/Runner.xcworkspace
   ```

3. 在 Xcode 中：
   - 右鍵點擊 `Runner` 資料夾
   - 選擇「Add Files to Runner」
   - 選擇 `GoogleService-Info.plist`
   - **重要**：確保勾選「Copy items if needed」和「Runner」target

## 步驟 3：設定 Android 應用

### 3.1 在 Firebase Console 註冊 Android 應用

1. 在 Firebase Console 中，點擊專案設定（⚙️）
2. 在「您的應用程式」區塊，點擊 Android 圖示
3. 輸入 Android 套件名稱：
   - 預設通常是：`com.example.learningbubbles`
   - 您可以在 `android/app/build.gradle` 中的 `applicationId` 查看實際的套件名稱
4. 下載 `google-services.json` 檔案

### 3.2 將配置檔添加到 Android 專案

1. 將下載的 `google-services.json` 複製到：
   ```
   android/app/google-services.json
   ```

2. 確保 `android/build.gradle` 包含 Google Services 插件：
   ```gradle
   buildscript {
       dependencies {
           classpath 'com.google.gms:google-services:4.4.0'
       }
   }
   ```

3. 確保 `android/app/build.gradle` 底部包含：
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

## 步驟 4：安裝 Firebase CLI（可選，但推薦）

使用 Firebase CLI 可以自動化設定過程：

```bash
# 安裝 Firebase CLI
npm install -g firebase-tools

# 登入 Firebase
firebase login

# 在專案目錄初始化 Firebase
cd /Users/Ariel/開發中APP/LearningBubbles
flutterfire configure
```

`flutterfire configure` 會自動：
- 偵測您的 Firebase 專案
- 下載並配置所有必要的檔案
- 設定 iOS 和 Android

## 步驟 5：啟用 Cloud Firestore

1. 在 Firebase Console 中，前往「Firestore Database」
2. 點擊「建立資料庫」
3. 選擇「以測試模式啟動」（開發階段）或「以生產模式啟動」
4. 選擇資料庫位置（建議選擇離您最近的區域）

## 步驟 6：驗證設定

執行以下命令檢查設定是否正確：

```bash
flutter pub get
flutter run
```

如果看到 Firebase 初始化錯誤，請檢查：
- `GoogleService-Info.plist` 是否在正確位置
- `google-services.json` 是否在正確位置
- Bundle ID / Package Name 是否與 Firebase Console 中的設定一致

## 常見問題

### iOS 設定問題

**錯誤：`FirebaseApp.configure() failed`**
- 確認 `GoogleService-Info.plist` 已添加到 Xcode 專案中
- 確認檔案已包含在 Build Phases > Copy Bundle Resources

**錯誤：`Missing or insufficient permissions`**
- 檢查 Firebase Console 中的 iOS Bundle ID 是否正確

### Android 設定問題

**錯誤：`File google-services.json is missing`**
- 確認 `google-services.json` 在 `android/app/` 目錄下
- 確認檔案名稱完全正確（區分大小寫）

**錯誤：`Default FirebaseApp is not initialized`**
- 檢查 `android/app/build.gradle` 是否包含 `apply plugin: 'com.google.gms.google-services'`
- 檢查 `android/build.gradle` 是否包含 Google Services classpath

## 下一步

設定完成後，您可以：
1. 開始使用 Cloud Firestore 儲存資料
2. 使用 Riverpod 管理應用狀態
3. 參考 `lib/main.dart` 中的範例程式碼

## 參考資源

- [FlutterFire 文件](https://firebase.flutter.dev/)
- [Cloud Firestore 文件](https://firebase.google.com/docs/firestore)
- [Riverpod 文件](https://riverpod.dev/)
