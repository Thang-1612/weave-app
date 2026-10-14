import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Danh sách bạn thân của tôi: users/{tôi}/closeFriends/{uidBạn}.
/// Người trong danh sách xem được các lớp có đối tượng "Bạn thân" của tôi.
class CloseFriendService {
  CloseFriendService._();

  static String get _me {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('msgNotSignedIn');
    return uid;
  }

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_me)
          .collection('closeFriends');

  /// Tập uid những người tôi đã đánh dấu bạn thân (cập nhật trực tiếp).
  static Stream<Set<String>> watchIds() {
    if (FirebaseAuth.instance.currentUser == null) {
      return Stream.value(<String>{});
    }
    return _col.snapshots().map((s) => {for (final d in s.docs) d.id});
  }

  static Future<void> add(String friendUid) =>
      _col.doc(friendUid).set({'createdAt': FieldValue.serverTimestamp()});

  static Future<void> remove(String friendUid) => _col.doc(friendUid).delete();
}