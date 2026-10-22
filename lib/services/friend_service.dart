import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum FriendStatus { none, friends, outgoing, incoming }

/// Mức hiển thị của một mối quan hệ trên bản đồ của người khác.
enum EdgeVisibility { public, hidden }

class Friendship {
  final String id;
  final List<String> users;
  final String requesterId;
  final String status; // 'pending' hoặc 'accepted'

  /// uid -> 'public' | 'hidden'. Mỗi bên chỉ được ghi giá trị của chính mình.
  final Map<String, String> visibility;

  const Friendship({
    required this.id,
    required this.users,
    required this.requesterId,
    required this.status,
    this.visibility = const {},
  });

  factory Friendship.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Friendship(
      id: doc.id,
      users: List<String>.from(d['users'] as List? ?? const []),
      requesterId: d['requesterId'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      visibility: Map<String, String>.from(
        (d['visibility'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
            const <String, String>{},
      ),
    );
  }

  bool get accepted => status == 'accepted';

  String otherUid(String me) =>
      users.firstWhere((u) => u != me, orElse: () => '');

  /// Chưa có giá trị nghĩa là 'hidden' (an toàn cho dữ liệu cũ).
  bool isPublicBy(String uid) => (visibility[uid] ?? 'hidden') == 'public';

  bool isHiddenBy(String uid) => !isPublicBy(uid);

  /// Mối quan hệ chỉ hiện với người thứ ba khi CẢ HAI bên để public.
  bool get isPublic => users.isNotEmpty && users.every(isPublicBy);
}

class FriendService {
  static final _col = FirebaseFirestore.instance.collection('friendships');

  static String get _me {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('msgNotSignedIn');
    return uid;
  }

  // Mã cố định cho mỗi cặp người dùng, để không bị trùng lặp
  static String _id(String a, String b) {
    final s = [a, b]..sort();
    return '${s[0]}_${s[1]}';
  }

  /// Gửi thông báo kết bạn (friend_request hoặc friend_accepted).
  /// Mỗi cặp chỉ có một thông báo mỗi loại; nếu đã tồn tại thì bỏ qua.
  static Future<void> _notify(String toUid, String type) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final n = me.displayName?.trim() ?? '';
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(toUid)
          .collection('notifications')
          .doc('${type}_${me.uid}')
          .set({
        'type': type,
        'fromUserId': me.uid,
        'fromName': n.isNotEmpty ? n : (me.email ?? 'msgUser'),
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Mọi mối quan hệ của tôi: bạn bè, lời mời nhận được, lời mời đã gửi.
  static Stream<List<Friendship>> watchMine() {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return Stream.value(const <Friendship>[]);
    return _col
        .where('users', arrayContains: me)
        .snapshots()
        .map((s) => s.docs.map(Friendship.fromDoc).toList());
  }

  static FriendStatus statusWith(
      List<Friendship> all,
      String me,
      String other,
      ) {
    for (final f in all) {
      if (f.users.contains(me) && f.users.contains(other)) {
        if (f.accepted) return FriendStatus.friends;
        return f.requesterId == me
            ? FriendStatus.outgoing
            : FriendStatus.incoming;
      }
    }
    return FriendStatus.none;
  }

  static Future<void> sendRequest(String other) async {
    final me = _me;
    final users = [me, other]..sort();
    try {
      await _col.doc(_id(me, other)).set({
        'users': users,
        'requesterId': me,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('msgNoFriendRequests');
      }
      rethrow;
    }
    await _notify(other, 'friend_request');
  }

  static Future<void> accept(String other) async {
    await _col.doc(_id(_me, other)).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _notify(other, 'friend_accepted');
  }

  /// Hủy lời mời đã gửi, từ chối lời mời, hoặc hủy kết bạn.
  static Future<void> remove(String other) async {
    await _col.doc(_id(_me, other)).delete();
    await _syncQuietly();
  }

  /// Tôi và [other] đã là bạn bè chưa.
  static Future<bool> isFriend(String other) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || me == other) return false;
    final s = await _col.doc(_id(me, other)).get();
    return s.exists && s.data()?['status'] == 'accepted';
  }

  // ---------------------------------------------------------------------
  // Bản đồ quan hệ (Weave Constellation)
  // ---------------------------------------------------------------------

  /// Đổi mức hiển thị của mối quan hệ với [other]. Chỉ ghi phần của chính mình.
  static Future<void> setVisibility(String other, EdgeVisibility v) async {
    final me = _me;
    await _col.doc(_id(me, other)).update({
      'visibility.$me': v.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _syncQuietly();
  }

  /// Cập nhật `users/{me}/public/edges`: danh sách bạn mà CẢ HAI bên đều để
  /// public. Chạy ở client vì gói Spark không có Cloud Functions.
  static Future<void> syncPublicEdges() async {
    final me = _me;
    final snap = await _col.where('users', arrayContains: me).get();
    final friends = snap.docs
        .map(Friendship.fromDoc)
        .where((f) => f.accepted && f.isPublic)
        .map((f) => f.otherUid(me))
        .where((u) => u.isNotEmpty)
        .toList();
    await FirebaseFirestore.instance.doc('users/$me/public/edges').set({
      'friends': friends,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _syncQuietly() async {
    try {
      await syncPublicEdges();
    } catch (_) {}
  }
}