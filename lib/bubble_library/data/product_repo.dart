import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import 'firestore_paths.dart';

class ProductRepo {
  final FirebaseFirestore _db;
  ProductRepo(this._db);

  Future<Map<String, Product>> getAll() async {
    final snap = await _db
        .collection(FirestorePaths.products())
        .where('published', isEqualTo: true)
        .get();
    return {for (final d in snap.docs) d.id: Product.fromMap(d.id, d.data())};
  }
}
