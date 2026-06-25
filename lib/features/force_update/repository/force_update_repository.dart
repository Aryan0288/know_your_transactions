import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/version_config_model.dart';

class ForceUpdateRepository {
  final FirebaseFirestore _firestore;

  ForceUpdateRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetches the version config from Firestore.
  /// Returns null if the document doesn't exist or on any network error
  /// (graceful fallback — app should proceed normally if Firestore is unreachable).
  Future<VersionConfigModel?> fetchVersionConfig() async {
    try {
      final doc = await _firestore
          .collection('app_config')
          .doc('version_control')
          .get();

      if (!doc.exists || doc.data() == null) return null;

      return VersionConfigModel.fromMap(doc.data()!);
    } catch (_) {
      // Graceful fallback: network error, offline, Firestore unavailable, etc.
      return null;
    }
  }
}
