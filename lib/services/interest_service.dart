import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/space.dart';

/// Ghi nhận và đọc sở thích xem bài của tài khoản đang đăng nhập.
class InterestService {
  static DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('private')
        .doc('interests');
  }

  /// Cộng điểm cho một danh mục. Lỗi được bỏ qua để không ảnh hưởng thao tác chính.
  static Future<void> track(String spaceId, double weight) async {
    if (spaceId.isEmpty) return;
    final doc = _doc();
    if (doc == null) return;
    try {
      await doc.set({
        'scores': {spaceId: FieldValue.increment(weight)},
        'updated': {spaceId: FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Điểm quan tâm của từng danh mục, đã giảm dần theo thời gian
  /// (một nửa sau 14 ngày). Danh mục chưa có điểm thì không có trong kết quả.
  static Future<Map<String, double>> loadAffinity() async {
    final doc = _doc();
    if (doc == null) return {};
    try {
      final snap = await doc.get();
      final data = snap.data();
      if (data == null) return {};

      final scores = Map<String, dynamic>.from(data['scores'] as Map? ?? {});
      final updated = Map<String, dynamic>.from(data['updated'] as Map? ?? {});
      final now = DateTime.now();

      final result = <String, double>{};
      for (final s in defaultSpaces) {
        final score = (scores[s.id] as num?)?.toDouble() ?? 0;
        if (score <= 0) continue;
        final ts = updated[s.id];
        final last = ts is Timestamp ? ts.toDate() : now;
        final days = now.difference(last).inHours / 24.0;
        result[s.id] = score * pow(0.5, days / 14).toDouble();
      }
      return result;
    } catch (_) {
      return {};
    }
  }
}
