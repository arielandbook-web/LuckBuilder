# 📱 安装与重置指南

本指南说明如何将 app 安装到手机，以及如何将 app 恢复到完全未使用的状态。

---

## 🚀 安装到手机

### 方法 1：使用安装脚本（推荐）

```bash
# 自动检测设备并安装
./install_to_device.sh

# 或指定平台
./install_to_device.sh android  # Android 设备
./install_to_device.sh ios      # iOS 设备
```

### 方法 2：使用 Flutter 命令

#### Android

1. **连接设备**
   - 启用 USB 调试（设置 > 关于手机 > 连续点击版本号 7 次）
   - 连接 USB 线
   - 授权此电脑

2. **检查连接**
   ```bash
   adb devices
   ```

3. **安装**
   ```bash
   flutter run --release
   ```

#### iOS

1. **连接设备或启动模拟器**
   - 真机：信任此电脑（设置 > 通用 > 设备管理）
   - 模拟器：启动 Xcode Simulator

2. **检查连接**
   ```bash
   # 真机
   idevice_id -l
   
   # 模拟器
   xcrun simctl list devices
   ```

3. **安装**
   ```bash
   flutter run --release
   ```

---

## 🔄 重置 App 到完全未使用的状态

### 方法 1：使用 App 内重置功能（推荐）

1. 打开 app
2. 进入「我的」页面（底部导航栏最右侧）
3. 找到「重置所有数据」选项
4. 点击后确认重置
5. 等待重置完成

**重置内容包括：**
- ✅ Firestore 数据（学习进度、设置、收藏等）
- ✅ 本地 SharedPreferences 数据
- ✅ 所有已排程的本地通知

### 方法 2：使用系统设置（仅清除本地数据）

#### Android

```bash
# 方法 1：使用 adb
adb shell pm clear com.example.learningbubbles

# 方法 2：手动操作
# 设置 > 应用 > LearningBubbles > 存储 > 清除数据
```

#### iOS

1. 设置 > 通用 > iPhone 存储空间
2. 找到 LearningBubbles
3. 选择「卸载 App」或「删除 App」

**注意：** 此方法只清除本地数据，不会清除 Firestore 云端数据。

---

## 📋 重置功能说明

### ResetService 功能

`lib/services/reset_service.dart` 提供了完整的数据重置功能：

#### `resetAll()`
- 清除所有 Firestore 用户数据
- 清除所有本地 SharedPreferences 数据
- 取消所有本地通知

#### `resetLocalOnly()`
- 仅清除本地数据
- 保留 Firestore 云端数据

### 清除的数据类型

#### Firestore（云端）
- `users/{uid}/library_products` - 产品库
- `users/{uid}/wishlist` - 愿望清单
- `users/{uid}/saved_items` - 已保存内容
- `users/{uid}/push_settings` - 推播设置
- `users/{uid}/topicProgress` - 主题进度
- `users/{uid}/contentState` - 内容状态
- `users/{uid}/progress` - 进度记录

#### SharedPreferences（本地）
- 推播相关：排程缓存、收件匣、跳过清单、日常顺序
- 用户状态：学习记录、兴趣标签、搜索历史
- 通知相关：已读状态、错失通知
- 其他：主题设置、收藏句子等

---

## ⚠️ 注意事项

1. **数据备份**
   - 重置前请确保重要数据已备份
   - Firestore 数据一旦删除无法恢复

2. **匿名登录**
   - App 使用匿名登录
   - 重置后仍会保持登录状态（新的匿名用户）

3. **多设备同步**
   - Firestore 数据会在所有设备间同步
   - 本地数据仅影响当前设备

4. **测试环境**
   - 建议在测试环境先测试重置功能
   - 确认所有数据已正确清除

---

## 🔍 验证重置结果

重置完成后，可以检查：

1. **Firestore Console**
   - 登录 Firebase Console
   - 检查 `users/{uid}` 下的所有子集合是否已清空

2. **App 状态**
   - 所有学习进度应为 0
   - 推播设置应为默认值
   - 收藏和愿望清单应为空
   - 通知收件匣应为空

3. **本地存储**
   - 使用调试工具检查 SharedPreferences
   - 确认所有相关 key 已清除

---

## 🛠️ 故障排除

### 安装问题

**Android: 设备未检测到**
- 检查 USB 调试是否启用
- 尝试更换 USB 线或 USB 端口
- 运行 `adb kill-server && adb start-server`

**iOS: 代码签名错误**
- 检查 Xcode 项目设置
- 确认开发者证书已配置
- 在 Xcode 中手动构建一次

### 重置问题

**重置失败**
- 检查网络连接（Firestore 需要网络）
- 确认用户已登录
- 查看控制台日志获取详细错误信息

**部分数据未清除**
- 检查 Firestore 规则是否允许删除
- 确认所有 Store 类的方法已正确调用
- 手动检查 SharedPreferences 中剩余的 key

---

## 📝 相关文件

- `install_to_device.sh` - 安装脚本
- `lib/services/reset_service.dart` - 重置服务
- `lib/pages/me_page.dart` - 我的页面（包含重置按钮）
- `DATA_ARCHITECTURE.md` - 数据架构文档

---

**最后更新**：2026-01-26
