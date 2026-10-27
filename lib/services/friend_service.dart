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
  /// Xóa luôn cả hai cạnh công khai trong cùng một batch để không sót dữ liệu.
  /// Nếu hai người đang là bạn bè, thu hồi ngay quyền xem bài chỉ-bạn-bè của nhau.
  static Future<void> remove(String other) async {
    final me = _me;
    final ref = _col.doc(_id(me, other));
    bool wasFriends = false;
    try {
      wasFriends = (await ref.get()).data()?['status'] == 'accepted';
    } catch (_) {}

    // Việc bắt buộc: xóa quan hệ. Không gộp chung batch với việc dọn phụ để
    // một lỗi ở phần phụ (ví dụ rules chưa cập nhật) không chặn được việc này.
    await ref.delete();

    // Việc phụ, lỗi thì bỏ qua: cạnh công khai còn sót lại sẽ bị rules từ chối
    // đọc (mất đồng thuận), và syncPublicEdges sẽ dọn ở lần sau.
    await _deleteEdgesQuietly(me, other);
    if (wasFriends) await _revokePostAccess(me, other);
  }

  static Future<void> _deleteEdgesQuietly(String a, String b) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      _deleteEdges(batch, a, b);
      await batch.commit();
    } catch (_) {}
  }

  /// Gỡ [other] khỏi audience các bài chỉ-bạn-bè của tôi, và gỡ tôi khỏi
  /// audience các bài chỉ-bạn-bè của [other]. Chạy ngay trong thao tác hủy kết
  /// bạn thay vì chờ [FriendPostSync] của tác giả (chỉ chạy khi app của tác giả
  /// đang mở). Lỗi được bỏ qua: FriendPostSync vẫn là lưới an toàn.
  static Future<void> _revokePostAccess(String me, String other) async {
    try {
      final db = FirebaseFirestore.instance;
      final posts = db.collection('friend_posts');
      // Hai truy vấn dùng chỉ mục đơn trường có sẵn, lọc phần còn lại ở client.
      final mine = await posts.where('authorId', isEqualTo: me).get();
      final theirs = await posts.where('audience', arrayContains: me).get();

      final ops = <void Function(WriteBatch)>[];
      for (final d in mine.docs) {
        final a = d.data()['audience'];
        if (a is List && a.contains(other)) {
          ops.add((b) => b.update(d.reference, {
            'audience': FieldValue.arrayRemove([other]),
          }));
        }
      }
      for (final d in theirs.docs) {
        if (d.data()['authorId'] == other) {
          ops.add((b) => b.update(d.reference, {
            'audience': FieldValue.arrayRemove([me]),
          }));
        }
      }
      for (var i = 0; i < ops.length; i += 400) {
        final batch = db.batch();
        for (final op in ops.skip(i).take(400)) {
          op(batch);
        }
        await batch.commit();
      }
    } catch (_) {}
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
  ///
  ///  - Ẩn: đổi visibility và xóa cả hai cạnh công khai trong một batch.
  ///  - Công khai: đổi visibility; nếu bên kia cũng đã công khai thì ghi luôn
  ///    cả hai cạnh trong cùng batch (rules dùng getAfter để kiểm tra).
  static Future<void> setVisibility(String other, EdgeVisibility v) async {
    final me = _me;
    final ref = _col.doc(_id(me, other));
    await ref.update({
      'visibility.$me': v.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Phần cạnh công khai là việc phụ: lỗi thì bỏ qua, syncPublicEdges tự chữa.
    try {
      if (v == EdgeVisibility.hidden) {
        await _deleteEdgesQuietly(me, other);
      } else {
        final snap = await ref.get();
        final vis = snap.data()?['visibility'];
        final otherPublic = vis is Map && vis[other] == 'public';
        final accepted = snap.data()?['status'] == 'accepted';
        if (otherPublic && accepted) {
          final batch = FirebaseFirestore.instance.batch();
          _putEdges(batch, me, other);
          await batch.commit();
        }
      }
    } catch (_) {}
  }

  static DocumentReference<Map<String, dynamic>> _edgeRef(
      String owner, String friend) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(owner)
          .collection('public_edges')
          .doc(friend);

  static void _putEdges(WriteBatch batch, String a, String b) {
    batch.set(_edgeRef(a, b), {
      'friendUid': b,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_edgeRef(b, a), {
      'friendUid': a,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static void _deleteEdges(WriteBatch batch, String a, String b) {
    batch.delete(_edgeRef(a, b));
    batch.delete(_edgeRef(b, a));
  }

  /// Tự chữa cho phía của tôi: xóa cạnh không còn hợp lệ, bổ sung cạnh còn
  /// thiếu, và dọn tài liệu `public/edges` kiểu cũ. Chạy ở client vì gói Spark
  /// không có Cloud Functions; rules vẫn là chốt chặn cuối cùng.
  static Future<void> syncPublicEdges() async {
    final me = _me;
    final db = FirebaseFirestore.instance;
    final snap = await _col.where('users', arrayContains: me).get();
    final valid = snap.docs
        .map(Friendship.fromDoc)
        .where((f) => f.accepted && f.isPublic)
        .map((f) => f.otherUid(me))
        .where((u) => u.isNotEmpty)
        .toSet();

    final mine = db.collection('users').doc(me).collection('public_edges');
    final existing = await mine.get();
    final have = existing.docs.map((d) => d.id).toSet();

    final ops = <void Function(WriteBatch)>[];
    for (final id in have.difference(valid)) {
      ops.add((b) => b.delete(mine.doc(id)));
    }
    for (final id in valid.difference(have)) {
      ops.add((b) => b.set(mine.doc(id), {
        'friendUid': id,
        'updatedAt': FieldValue.serverTimestamp(),
      }));
    }
    // Mỗi batch tối đa 500 thao tác.
    for (var i = 0; i < ops.length; i += 400) {
      final batch = db.batch();
      for (final op in ops.skip(i).take(400)) {
        op(batch);
      }
      await batch.commit();
    }

    // Dọn dữ liệu cũ (mảng friends trong public/edges), bỏ qua nếu không có.
    try {
      await db.doc('users/$me/public/edges').delete();
    } catch (_) {}
  }
}
