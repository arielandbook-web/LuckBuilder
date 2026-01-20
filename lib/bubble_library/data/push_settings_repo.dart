import 'package:cloud_firestore/cloud_firestore.dart';
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
    await _db.doc(FirestorePaths.userGlobalPush(uid)).set(s.toMap(), SetOptions(merge: true));
  }
}
