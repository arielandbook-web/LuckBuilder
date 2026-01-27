import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 推送排除存储：简洁版本，只用于排程排除
/// 
/// 核心数据结构：
/// - opened: Set<String> - 已读的内容（contentItemId）
/// - missed: Set<String> - 滑掉/错过的内容（contentItemId）
/// - scheduled: Map<String, int> - 排程时间记录（contentItemId -> whenMs）
class PushExclusionStore {
  // Keys
  static String _kOpened(String uid) => 'push_excluded_opened_$uid';
  static String _kMissed(String uid) => 'push_excluded_missed_$uid';
  static String _kScheduled(String uid) => 'push_scheduled_when_$uid';
  
  // 过期阈值：5分钟
  static const int _expirationThresholdMs = 5 * 60 * 1000;
  
  /// 标记内容为已读
  static Future<void> markOpened(String uid, String contentItemId) async {
    if (uid.isEmpty || contentItemId.isEmpty) return;
    
    final opened = await loadOpened(uid);
    opened.add(contentItemId);
    await _saveSet(_kOpened(uid), opened);
    
    // 如果已在 missed 列表中，移除（已读优先于错过）
    final missed = await loadMissed(uid);
    if (missed.contains(contentItemId)) {
      missed.remove(contentItemId);
      await _saveSet(_kMissed(uid), missed);
    }
    
    if (kDebugMode) {
      debugPrint('✅ PushExclusionStore.markOpened: $contentItemId');
    }
  }
  
  /// 标记内容为滑掉/错过
  static Future<void> markMissed(String uid, String contentItemId) async {
    if (uid.isEmpty || contentItemId.isEmpty) return;
    
    // 如果已读，不标记为错过（已读优先）
    final opened = await loadOpened(uid);
    if (opened.contains(contentItemId)) {
      if (kDebugMode) {
        debugPrint('ℹ️ PushExclusionStore.markMissed: $contentItemId 已读，不标记为错过');
      }
      return;
    }
    
    final missed = await loadMissed(uid);
    missed.add(contentItemId);
    await _saveSet(_kMissed(uid), missed);
    
    if (kDebugMode) {
      debugPrint('✅ PushExclusionStore.markMissed: $contentItemId');
    }
  }
  
  /// 记录排程时间
  static Future<void> recordScheduled(String uid, String contentItemId, DateTime when) async {
    if (uid.isEmpty || contentItemId.isEmpty) return;
    
    // 如果已读，不记录排程（已读的内容不应该再排程）
    final opened = await loadOpened(uid);
    if (opened.contains(contentItemId)) {
      if (kDebugMode) {
        debugPrint('ℹ️ PushExclusionStore.recordScheduled: $contentItemId 已读，不记录排程');
      }
      return;
    }
    
    final scheduled = await loadScheduled(uid);
    scheduled[contentItemId] = when.millisecondsSinceEpoch;
    await _saveMap(_kScheduled(uid), scheduled);
  }
  
  /// 获取所有需要排除的内容（已读 + 错过）
  static Future<Set<String>> getExcludedContentItemIds(String uid) async {
    final opened = await loadOpened(uid);
    final missed = await loadMissed(uid);
    return {...opened, ...missed};
  }
  
  /// 扫描并自动标记过期未读的内容为错过
  static Future<void> sweepExpired(String uid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final scheduled = await loadScheduled(uid);
    final opened = await loadOpened(uid);
    final missed = await loadMissed(uid);
    
    bool hasChanges = false;
    
    for (final entry in scheduled.entries) {
      final contentItemId = entry.key;
      final whenMs = entry.value;
      
      // 如果已读，跳过
      if (opened.contains(contentItemId)) continue;
      
      // 如果已在 missed 列表中，跳过
      if (missed.contains(contentItemId)) continue;
      
      // 如果过期5分钟以上，标记为错过
      if (whenMs < (now - _expirationThresholdMs)) {
        missed.add(contentItemId);
        hasChanges = true;
        
        if (kDebugMode) {
          debugPrint('⏰ PushExclusionStore.sweepExpired: $contentItemId 已过期，标记为错过');
        }
      }
    }
    
    if (hasChanges) {
      await _saveSet(_kMissed(uid), missed);
    }
  }
  
  /// 检查内容是否过期未读（用于红框显示）
  static Future<bool> isExpiredUnread(String uid, String contentItemId) async {
    final scheduled = await loadScheduled(uid);
    final opened = await loadOpened(uid);
    
    // 如果已读，不算过期未读
    if (opened.contains(contentItemId)) return false;
    
    // 如果不在排程记录中，不算过期未读
    final whenMs = scheduled[contentItemId];
    if (whenMs == null) return false;
    
    // 检查是否过期5分钟以上
    final now = DateTime.now().millisecondsSinceEpoch;
    return whenMs < (now - _expirationThresholdMs);
  }
  
  /// 检查内容是否已读
  static Future<bool> isOpened(String uid, String contentItemId) async {
    final opened = await loadOpened(uid);
    return opened.contains(contentItemId);
  }
  
  /// 检查内容是否错过
  static Future<bool> isMissed(String uid, String contentItemId) async {
    final missed = await loadMissed(uid);
    return missed.contains(contentItemId);
  }
  
  // 私有方法：加载和保存
  static Future<Set<String>> loadOpened(String uid) async {
    return _loadSet(_kOpened(uid));
  }
  
  static Future<Set<String>> loadMissed(String uid) async {
    return _loadSet(_kMissed(uid));
  }
  
  static Future<Map<String, int>> loadScheduled(String uid) async {
    return _loadMap(_kScheduled(uid));
  }
  
  static Future<Set<String>> _loadSet(String key) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(key) ?? [];
    return list.toSet();
  }
  
  static Future<void> _saveSet(String key, Set<String> set) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(key, set.toList());
  }
  
  static Future<Map<String, int>> _loadMap(String key) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }
  
  static Future<void> _saveMap(String key, Map<String, int> map) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(key, jsonEncode(map));
  }
  
  /// 清除特定产品的排除数据（用于重新学习）
  static Future<void> clearProduct(String uid, List<String> contentItemIds) async {
    if (contentItemIds.isEmpty) return;
    
    // 从 opened 中移除
    final opened = await loadOpened(uid);
    opened.removeAll(contentItemIds);
    await _saveSet(_kOpened(uid), opened);
    
    // 从 missed 中移除
    final missed = await loadMissed(uid);
    missed.removeAll(contentItemIds);
    await _saveSet(_kMissed(uid), missed);
    
    // 从 scheduled 中移除
    final scheduled = await loadScheduled(uid);
    for (final cid in contentItemIds) {
      scheduled.remove(cid);
    }
    await _saveMap(_kScheduled(uid), scheduled);
    
    if (kDebugMode) {
      debugPrint('🗑️ PushExclusionStore.clearProduct: 已清除 ${contentItemIds.length} 个内容的排除数据');
    }
  }
  
  /// 清除所有数据（用于重置）
  static Future<void> clearAll(String uid) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kOpened(uid));
    await sp.remove(_kMissed(uid));
    await sp.remove(_kScheduled(uid));
    
    if (kDebugMode) {
      debugPrint('🗑️ PushExclusionStore.clearAll: 已清除所有数据');
    }
  }
}
