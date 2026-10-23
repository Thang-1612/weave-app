import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Giữ danh sách người xem (audience) của các bài chỉ-bạn-bè khớp với danh sách
/// bạn bè hiện tại của tác giả. Chạy ngầm khi app đang mở.
class FriendPostSync {
  static final _db = FirebaseFirestore.instance;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  static String? _last;

  static List<String> _accepted(
    Iterable<Map<String, dynamic>> docs,
    String me,
  ) {
    final out = <String>{};
    for (final d in docs) {
      if (d['status'] != 'accepted') continue;
      final users = List<String>.from(d['users'] as List? ?? const []);
      for (final u in users) {
        if (u != me) out.add(u);
      }
    }
    return out.toList()..sort();
  }

  /// Mã của các bạn bè đã chấp nhận (đọc trực tiếp từ máy chủ).
  static Future<List<String>> acceptedFriendUids() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return [];
    final snap = await _db
        .collection('friendships')
        .where('users', arrayContains: me)
        .get();
    return _accepted(snap.docs.map((d) => d.data()), me);
  }

  /// Bắt đầu theo dõi danh sách bạn bè và đồng bộ audience khi nó thay đổi.
  static void start() {
    stop();
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    _sub = _db
        .collection('friendships')
        .where('users', arrayContains: me)
        .snapshots()
        .listen((snap) {
          // Dữ liệu từ bộ nhớ đệm có thể chưa đầy đủ: bỏ qua để không xóa nhầm
          if (snap.metadata.isFromCache) return;
          final friends = _accepted(snap.docs.map((d) => d.data()), me);
          final key = friends.join(',');
          if (key == _last) return;
          _last = key;
          _sync(me, friends).catchError((_) {});
        }, onError: (_) {});
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
    _last = null;
  }

  static Future<void> _sync(String me, List<String> friends) async {
    final snap = await _db
        .collection('friend_posts')
        .where('authorId', isEqualTo: me)
        .get();

    final target = friends.toSet();
    var batch = _db.batch();
    var count = 0;

    for (final doc in snap.docs) {
      if (doc.data()['visibility'] == 'me')
        continue; // chỉ mình tôi: không có người xem
      final current = {
        for (final v in (doc.data()['audience'] as List? ?? const []))
          if (v is String) v,
      };
      if (current.length == target.length && current.containsAll(target)) {
        continue;
      }
      batch.update(doc.reference, {'audience': friends});
      count++;
      if (count == 400) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
  }
}
