import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'l10n.dart';

class BoxNote {
  final String id;
  final String text;
  final bool pinned;
  final bool posted; // đã đăng thành bài
  final DateTime createdAt;
  const BoxNote({
    required this.id,
    required this.text,
    required this.pinned,
    required this.posted,
    required this.createdAt,
  });
}

/// "Hộp thư của tôi": ghi chú gửi riêng cho chính mình (kiểu tin lưu của
/// Telegram, Cloud của tôi của Zalo), có thể biến thành bài đăng chỉ bằng
/// một lần bấm. Lưu ở users/{uid}/my_box, chỉ chủ tài khoản đọc và ghi.
class MyBoxService {
  static CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('my_box');

  static String get _uid {
    final u = FirebaseAuth.instance.currentUser?.uid;
    if (u == null) throw Exception(msgNotSignedIn);
    return u;
  }

  /// Ghim lên đầu, rồi mới nhất trước.
  static Stream<List<BoxNote>> watch() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const <BoxNote>[]);
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) {
            final m = d.data();
            final ts = m['createdAt'];
            return BoxNote(
              id: d.id,
              text: m['text'] as String? ?? '',
              pinned: m['pinned'] as bool? ?? false,
              posted: m['posted'] as bool? ?? false,
              // createdAt tạm null ngay lúc vừa ghi, trước khi máy chủ xác nhận
              createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
            );
          }).toList();
          // sort ổn định: ghim trước, giữ nguyên thứ tự mới nhất trước
          final pinned = list.where((n) => n.pinned);
          final rest = list.where((n) => !n.pinned);
          return [...pinned, ...rest];
        });
  }

  static Future<void> add(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await _col(_uid).add({
      'text': clean,
      'pinned': false,
      'posted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateText(String id, String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await _col(_uid)
        .doc(id)
        .update({'text': clean, 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> setPinned(String id, bool pinned) =>
      _col(_uid).doc(id).update({'pinned': pinned});

  static Future<void> markPosted(String id) =>
      _col(_uid).doc(id).update({'posted': true});

  static Future<void> delete(String id) => _col(_uid).doc(id).delete();
}
