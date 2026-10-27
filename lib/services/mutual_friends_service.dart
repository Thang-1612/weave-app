import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import 'friend_service.dart';
import 'user_prefs.dart';

/// Bạn chung giữa tôi và một người khác.
///
/// Quy tắc riêng tư: một người chỉ được tính là "bạn chung" khi cạnh giữa họ và
/// [other] là cạnh công khai (cả hai bên đồng ý, do rules kiểm tra). Bạn nào đặt
/// quan hệ ở chế độ riêng tư thì không bao giờ hiện ở đây.
class MutualFriendsService {
  static final _db = FirebaseFirestore.instance;

  /// Số bạn của tôi được kiểm tra tối đa với người lạ (mỗi bạn tốn một lượt đọc).
  static const _maxProbe = 60;

  static final Map<String, _Entry> _cache = {};
  static const _ttl = Duration(minutes: 10);

  static void invalidate() => _cache.clear();

  /// uid các bạn chung. Rỗng nếu không có hoặc không thể xác định.
  static Future<List<String>> mutualUids(String other) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || me == other) return const [];

    final key = '$me|$other';
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.at) < _ttl) {
      return hit.uids;
    }

    final mine = await FriendService.watchMine().first;
    final myFriends = mine
        .where((f) => f.accepted)
        .map((f) => f.otherUid(me))
        .where((u) =>
    u.isNotEmpty && u != other && !UserPrefs.instance.isBlocked(u))
        .toList();
    if (myFriends.isEmpty) return const [];

    List<String> result;
    final iAmFriendWithOther = mine.any(
          (f) => f.accepted && f.users.contains(other),
    );

    if (iAmFriendWithOther) {
      // Bạn bè được phép liệt kê các cạnh công khai của nhau: một truy vấn.
      final s = await _db
          .collection('users')
          .doc(other)
          .collection('public_edges')
          .limit(500)
          .get();
      final theirs = s.docs.map((d) => d.id).toSet();
      result = myFriends.where(theirs.contains).toList();
    } else {
      // Người lạ: không được liệt kê, chỉ dò được từng cặp (other, bạn của tôi).
      final probe = myFriends.take(_maxProbe).toList();
      final hits = await Future.wait(probe.map((m) async {
        try {
          final d = await _db
              .collection('users')
              .doc(other)
              .collection('public_edges')
              .doc(m)
              .get();
          return d.exists ? m : null;
        } catch (_) {
          return null;
        }
      }));
      result = hits.whereType<String>().toList();
    }

    _cache[key] = _Entry(DateTime.now(), result);
    return result;
  }

  /// Hồ sơ của các bạn chung (tối đa [limit] người, dùng để hiển thị tên).
  static Future<List<UserProfile>> mutualProfiles(String other,
      {int limit = 10}) async {
    final uids = (await mutualUids(other)).take(limit).toList();
    final out = <UserProfile>[];
    for (var i = 0; i < uids.length; i += 10) {
      final chunk = uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10);
      try {
        final snap = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          out.add(UserProfile.fromMap(d.id, d.data()));
        }
      } catch (_) {}
    }
    return out;
  }
}

class _Entry {
  final DateTime at;
  final List<String> uids;
  _Entry(this.at, this.uids);
}
