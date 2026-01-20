# Flutter SDK 安裝指南

## 方法一：使用 Homebrew 安裝（推薦）

如果遇到權限問題，請先執行：
```bash
sudo chown -R $(whoami) /opt/homebrew/Cellar
sudo chown -R $(whoami) /Users/$(whoami)/Library/Caches/Homebrew
```

然後執行：
```bash
brew install --cask flutter
```

## 方法二：手動安裝

### 步驟 1：下載 Flutter SDK

1. 前往 Flutter 官網下載頁面：
   https://docs.flutter.dev/get-started/install/macos

2. 下載最新的穩定版本（Stable channel）

3. 解壓縮到您想要的位置，例如：
   ```bash
   cd ~/development
   unzip ~/Downloads/flutter_macos_*.zip
   ```

### 步驟 2：設定環境變數

將 Flutter 添加到您的 PATH：

1. 編輯 shell 設定檔（根據您使用的 shell）：
   - **Bash**: `~/.bash_profile` 或 `~/.bashrc`
   - **Zsh**: `~/.zshrc`

2. 添加以下行：
   ```bash
   export PATH="$PATH:$HOME/development/flutter/bin"
   ```
   （請根據您的實際安裝路徑調整）

3. 重新載入設定檔：
   ```bash
   source ~/.zshrc  # 或 source ~/.bash_profile
   ```

### 步驟 3：驗證安裝

執行以下命令檢查安裝：
```bash
flutter doctor
```

這個命令會檢查您的環境並顯示需要安裝的額外工具。

## 方法三：使用 Git 安裝

```bash
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/development/flutter/bin"
flutter doctor
```

## 安裝後的設定

### 1. 接受 Android 授權（如果開發 Android 應用）
```bash
flutter doctor --android-licenses
```

### 2. 安裝 Xcode（如果開發 iOS 應用）
- 從 App Store 安裝 Xcode
- 執行：`sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
- 執行：`sudo xcodebuild -runFirstLaunch`

### 3. 安裝 Android Studio（如果開發 Android 應用）
- 下載並安裝 Android Studio
- 安裝 Android SDK、Android SDK Platform-Tools 和 Android Emulator

## 驗證專案

安裝完成後，在專案目錄執行：
```bash
cd /Users/Ariel/開發中APP/LearningBubbles
flutter pub get
flutter doctor
flutter run
```

## 常見問題

### Flutter 命令找不到
- 確認 PATH 已正確設定
- 重新開啟終端機或執行 `source ~/.zshrc`

### 權限問題
- 確保 Flutter 目錄有讀取權限
- 使用 `chmod -R 755 ~/development/flutter` 設定權限
