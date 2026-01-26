import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/global_push_settings.dart';
import 'firestore_paths.dart';

class PushSettingsRepo {
  final FirebaseFirestore _db;
  PushSettingsRepo(this._db);

  Stream<GlobalPushSettings> watchGlobal(String uid) {
    return _db.doc(FirestorePaths.userGlobalPush(uid)).snapshots().map((doc) {
      return GlobalPushSettings.fromMap(doc.data());
    });
  }

  Future<GlobalPushSettings> getGlobal(String uid) async {
    final doc = await _db.doc(FirestorePaths.userGlobalPush(uid)).get();
    return GlobalPushSettings.fromMap(doc.data());
  }

  Future<void> setGlobal(String uid, GlobalPushSettings s) async {
    final path = FirestorePaths.userGlobalPush(uid);
    final data = s.toMap();
    
    if (kDebugMode) {
      debugPrint('📝 setGlobal: path=$path');
      debugPrint('📝 setGlobal: data=$data');
    }
    
    try {
      await _db.doc(path).set(data, SetOptions(merge: true));
      if (kDebugMode) {
        debugPrint('✅ setGlobal: 寫入成功');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ setGlobal: 寫入失敗 - $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }
}
