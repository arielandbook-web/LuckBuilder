import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/content_item.dart';
import 'firestore_paths.dart';

class ContentRepo {
  final FirebaseFirestore _db;
  ContentRepo(this._db);

  Future<List<ContentItem>> getByProduct(String productId) async {
    final snap = await _db
        .collection(FirestorePaths.contentItems())
        .where('productId', isEqualTo: productId)
        .orderBy('seq')
        .get();
    return snap.docs.map((d) => ContentItem.fromMap(d.id, d.data())).toList();
  }

  Future<ContentItem> getOne(String id) async {
    final doc = await _db.collection(FirestorePaths.contentItems()).doc(id).get();
    final data = doc.data();
    if (data == null) throw StateError('content_item not found: $id');
    return ContentItem.fromMap(doc.id, data);
  }
}
