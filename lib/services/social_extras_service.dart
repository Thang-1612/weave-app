import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post.dart';
import 'l10n.dart';

/// "5 phút trước", "2 ngày trước"... hoặc ngày tháng nếu đã lâu.
String extrasAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return tr('vừa xong', 'just now');
  if (d.inMinutes < 60) {
    return tr('${d.inMinutes} phút trước', '${d.inMinutes} min ago');
  }
  if (d.inHours < 24) return tr('${d.inHours} giờ trước', '${d.inHours} h ago');
  if (d.inDays < 30) return tr('${d.inDays} ngày trước', '${d.inDays} d ago');
  return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
}

DateTime _ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

String _myName(User u) {
  final n = u.displayName?.trim() ?? '';
  return n.isNotEmpty ? n : (u.email ?? tr('Người dùng', 'User'));
}

// ---------------------------------------------------------------------------
// Bài sống
// ---------------------------------------------------------------------------

class LiveUpdate {
  final String id;
  final String text;
  final DateTime createdAt;

  /// 'manual' (tác giả tự viết, mọi người thấy) hoặc do hệ thống tự sinh
  /// ('merge', 'proposal', 'restore', chỉ tác giả thấy). Mục cũ chưa có
  /// trường này được coi là 'manual'.
  final String kind;
  const LiveUpdate(this.id, this.text, this.createdAt, {this.kind = 'manual'});
}

class LivePostService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _post(String id) =>
      _db.collection('posts').doc(id);

  /// Tác giả thêm một bản cập nhật: ghi một dòng vào `updates` và tăng bộ đếm
  /// trên bài (cùng một lần ghi, không cần Cloud Functions).
  /// Đây là cập nhật tác giả tự viết nên tính cả vào bộ đếm công khai.
  static Future<void> addUpdate(Post p, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final batch = _db.batch();
    batch.set(_post(p.id).collection('updates').doc(), {
      'text': text,
      'kind': 'manual',
      'authorId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_post(p.id), {
      'updateCount': FieldValue.increment(1),
      'lastUpdateAt': FieldValue.serverTimestamp(),
      'publicUpdateCount': FieldValue.increment(1),
      'lastPublicUpdateAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Ghi một mục do hệ thống tự sinh (gộp nhánh, nhận đề xuất, khôi phục
  /// phiên bản). Chỉ tác giả thấy mục này và không tăng bộ đếm công khai.
  /// [kind]: 'merge', 'proposal' hoặc 'restore'.
  static Future<void> addSystemUpdate(Post p, String text, String kind) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final batch = _db.batch();
    batch.set(_post(p.id).collection('updates').doc(), {
      'text': text,
      'kind': kind,
      'authorId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_post(p.id), {
      'updateCount': FieldValue.increment(1),
      'lastUpdateAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Chỉ tải danh sách cập nhật khi người dùng mở dòng thời gian.
  static Future<List<LiveUpdate>> loadUpdates(Post p) async {
    final s = await _post(p.id)
        .collection('updates')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return s.docs
        .map(
          (d) => LiveUpdate(
            d.id,
            d.data()['text'] as String? ?? '',
            _ts(d.data()['createdAt']),
            kind: d.data()['kind'] as String? ?? 'manual',
          ),
        )
        .toList();
  }

  static DocumentReference<Map<String, dynamic>>? _follow(String postId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('following_posts')
        .doc(postId);
  }

  /// null = chưa theo dõi; có giá trị = đang theo dõi (kèm lastSeenAt).
  static Stream<Map<String, dynamic>?> watchFollow(String postId) {
    final ref = _follow(postId);
    if (ref == null) return Stream.value(null);
    return ref.snapshots().map(
      (s) => s.exists ? (s.data() ?? <String, dynamic>{}) : null,
    );
  }

  static Future<void> setFollow(String postId, bool on) async {
    final ref = _follow(postId);
    if (ref == null) return;
    if (on) {
      await ref.set({
        'followedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  static Future<void> markSeen(String postId) async {
    try {
      await _follow(postId)
          ?.update({'lastSeenAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Lời cảm ơn
// ---------------------------------------------------------------------------

class ThanksItem {
  final String id;
  final String fromName;
  final String postPreview;
  final String note;
  final DateTime createdAt;
  const ThanksItem(
    this.id,
    this.fromName,
    this.postPreview,
    this.note,
    this.createdAt,
  );
}

class ThanksService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _db.collection('users').doc(uid).collection('thanks_inbox');

  /// Gửi lời cảm ơn riêng tư cho tác giả. Mỗi người một lời cho mỗi bài
  /// (gửi lại thì ghi đè).
  static Future<void> send(Post p, String note) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == p.authorId) return;
    final preview = p.text.length > 80 ? '${p.text.substring(0, 80)}…' : p.text;
    await _inbox(p.authorId).doc('${p.id}_${me.uid}').set({
      'fromUserId': me.uid,
      'fromName': _myName(me),
      'postId': p.id,
      'postPreview': preview,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<ThanksItem>> loadMine() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final s = await _inbox(uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return s.docs.map((d) {
      final m = d.data();
      return ThanksItem(
        d.id,
        m['fromName'] as String? ?? '',
        m['postPreview'] as String? ?? '',
        m['note'] as String? ?? '',
        _ts(m['createdAt']),
      );
    }).toList();
  }

  static Future<void> delete(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _inbox(uid).doc(id).delete();
  }
}

// ---------------------------------------------------------------------------
// Ghi chú theo khối
// ---------------------------------------------------------------------------

class BlockNote {
  final String id;
  final int blockIndex;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  const BlockNote(
    this.id,
    this.blockIndex,
    this.authorId,
    this.authorName,
    this.text,
    this.createdAt,
  );
}

class BlockNoteService {
  static CollectionReference<Map<String, dynamic>> _col(Post p) =>
      FirebaseFirestore.instance
          .collection('posts')
          .doc(p.id)
          .collection('block_notes');

  static Stream<List<BlockNote>> watch(Post p) {
    return _col(p)
        .orderBy('createdAt')
        .limit(200)
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
            final m = d.data();
            return BlockNote(
              d.id,
              (m['blockIndex'] as num?)?.toInt() ?? 0,
              m['authorId'] as String? ?? '',
              m['authorName'] as String? ?? '',
              m['text'] as String? ?? '',
              _ts(m['createdAt']),
            );
          }).toList(),
        );
  }

  static Future<void> add(Post p, int blockIndex, String text) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    await _col(p).add({
      'blockIndex': blockIndex,
      'authorId': me.uid,
      'authorName': _myName(me),
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(Post p, String id) => _col(p).doc(id).delete();
}
