#!/bin/bash

# Flutter SDK 安裝腳本
# 使用方法：在終端機執行：bash install_flutter.sh

set -e

echo "🚀 開始安裝 Flutter SDK..."

# 檢查是否已安裝 Flutter
if command -v flutter &> /dev/null; then
    echo "✅ Flutter 已經安裝！"
    flutter --version
    flutter doctor
    exit 0
fi

# 建立安裝目錄
INSTALL_DIR="$HOME/development"
echo "📁 建立安裝目錄: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# 下載並安裝 Flutter
cd "$INSTALL_DIR"
echo "⬇️  正在下載 Flutter SDK..."
if [ -d "flutter" ]; then
    echo "⚠️  Flutter 目錄已存在，正在更新..."
    cd flutter
    git pull
else
    git clone https://github.com/flutter/flutter.git -b stable
fi

# 設定 PATH（針對 zsh）
FLUTTER_PATH="$INSTALL_DIR/flutter/bin"
SHELL_CONFIG="$HOME/.zshrc"

if [ -f "$SHELL_CONFIG" ]; then
    if ! grep -q "flutter/bin" "$SHELL_CONFIG"; then
        echo "" >> "$SHELL_CONFIG"
        echo "# Flutter SDK" >> "$SHELL_CONFIG"
        echo "export PATH=\"\$PATH:$FLUTTER_PATH\"" >> "$SHELL_CONFIG"
        echo "✅ 已將 Flutter 添加到 $SHELL_CONFIG"
    else
        echo "ℹ️  Flutter 路徑已存在於 $SHELL_CONFIG"
    fi
fi

# 設定 PATH（針對 bash）
BASH_CONFIG="$HOME/.bash_profile"
if [ -f "$BASH_CONFIG" ]; then
    if ! grep -q "flutter/bin" "$BASH_CONFIG"; then
        echo "" >> "$BASH_CONFIG"
        echo "# Flutter SDK" >> "$BASH_CONFIG"
        echo "export PATH=\"\$PATH:$FLUTTER_PATH\"" >> "$BASH_CONFIG"
        echo "✅ 已將 Flutter 添加到 $BASH_CONFIG"
    fi
fi

# 將 Flutter 添加到當前 session 的 PATH
export PATH="$PATH:$FLUTTER_PATH"

echo ""
echo "✅ Flutter SDK 安裝完成！"
echo ""
echo "📋 下一步："
echo "1. 重新開啟終端機，或執行：source ~/.zshrc"
echo "2. 執行：flutter doctor"
echo "3. 在專案目錄執行：flutter pub get"
echo ""

# 執行 flutter doctor
if command -v flutter &> /dev/null; then
    echo "🔍 執行 Flutter 環境檢查..."
    flutter doctor
fi
