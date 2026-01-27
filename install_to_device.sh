#!/bin/bash

# LearningBubbles 安装到手机脚本
# 使用方法：
#   ./install_to_device.sh          # 自动检测连接的设备
#   ./install_to_device.sh android  # 指定 Android
#   ./install_to_device.sh ios      # 指定 iOS

set -e

PLATFORM=${1:-auto}

echo "🚀 LearningBubbles 安装脚本"
echo "================================"

# 检测连接的设备
detect_device() {
    if [ "$PLATFORM" = "auto" ]; then
        # 检测 Android 设备
        if adb devices | grep -q "device$"; then
            echo "✅ 检测到 Android 设备"
            PLATFORM="android"
        # 检测 iOS 设备
        elif xcrun simctl list devices | grep -q "Booted"; then
            echo "✅ 检测到 iOS 模拟器"
            PLATFORM="ios"
        elif idevice_id -l 2>/dev/null | grep -q "."; then
            echo "✅ 检测到 iOS 真机"
            PLATFORM="ios"
        else
            echo "❌ 未检测到连接的设备"
            echo "   请确保："
            echo "   - Android: 已启用 USB 调试"
            echo "   - iOS: 已信任此电脑"
            exit 1
        fi
    fi
}

# 安装到 Android
install_android() {
    echo ""
    echo "📱 正在安装到 Android 设备..."
    
    # 检查 Flutter 环境
    if ! command -v flutter &> /dev/null; then
        echo "❌ 未找到 Flutter，请先安装 Flutter SDK"
        exit 1
    fi
    
    # 检查设备连接
    if ! adb devices | grep -q "device$"; then
        echo "❌ 未检测到 Android 设备"
        echo "   请确保："
        echo "   1. 已启用 USB 调试"
        echo "   2. 已连接 USB 线"
        echo "   3. 已授权此电脑"
        exit 1
    fi
    
    # 运行 Flutter
    echo "🔨 正在构建并安装..."
    flutter run --release
    
    echo ""
    echo "✅ 安装完成！"
}

# 安装到 iOS
install_ios() {
    echo ""
    echo "📱 正在安装到 iOS 设备..."
    
    # 检查 Flutter 环境
    if ! command -v flutter &> /dev/null; then
        echo "❌ 未找到 Flutter，请先安装 Flutter SDK"
        exit 1
    fi
    
    # 检查设备连接
    if xcrun simctl list devices | grep -q "Booted"; then
        echo "✅ 使用 iOS 模拟器"
        DEVICE_TYPE="simulator"
    elif idevice_id -l 2>/dev/null | grep -q "."; then
        echo "✅ 使用 iOS 真机"
        DEVICE_TYPE="device"
    else
        echo "❌ 未检测到 iOS 设备或模拟器"
        echo "   请确保："
        echo "   1. 已信任此电脑"
        echo "   2. 或已启动 iOS 模拟器"
        exit 1
    fi
    
    # 运行 Flutter
    echo "🔨 正在构建并安装..."
    flutter run --release
    
    echo ""
    echo "✅ 安装完成！"
}

# 主流程
detect_device

case $PLATFORM in
    android)
        install_android
        ;;
    ios)
        install_ios
        ;;
    *)
        echo "❌ 不支持的平台: $PLATFORM"
        exit 1
        ;;
esac

echo ""
echo "📝 提示："
echo "   - 如需重置 app 数据，请在 app 内使用「重置所有数据」功能"
echo "   - 或使用：adb shell pm clear com.example.learningbubbles (Android)"
echo "   - 或使用：Settings > General > iPhone Storage > LearningBubbles > Offload App (iOS)"
