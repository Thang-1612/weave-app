import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post.dart';

/// Một bài viết trong thùng rác.
class TrashItem {
  final String id;
  final String originalCollection;

  /// Dữ liệu gốc của bài viết (đã bỏ các trường phụ của thùng rác).
  final Map<String, dynamic> data;
  final DateTime deletedAt;

  const TrashItem(this.id, this.originalCollection, this.data, this.deletedAt);

  DateTime get expiresAt => deletedAt.add(TrashService.retention);
  bool get expired => !expiresAt.isAfter(DateTime.now());

  /// Số ngày còn lại trước khi bị xóa vĩnh viễn (làm tròn lên).
  int get daysLeft =>
      math.max(0, (expiresAt.difference(DateTime.now()).inHours / 24).ceil());

  String get spaceId => (data['spaceId'] as String?) ?? '';

  String get previewText {
    final t = data['text'];
    if (t is String && t.trim().isNotEmpty) return t.trim();
    final blocks = data['blocks'];
    if (blocks is List) {
      for (final b in blocks) {
        if (b is Map && b['type'] == 'text') {
          final s = b['text'];
          if (s is String && s.trim().isNotEmpty) return s.trim();
        }
      }
    }
    return '';
  }

  int _count(String type) {
    final blocks = data['blocks'];
    if (blocks is! List) return 0;
    return blocks.where((b) => b is Map && b['type'] == type).length;
  }

  int get imageCount => _count('image');
  int get linkCount => _count('link');
}

class TrashService {
  /// Thời gian giữ bài trong thùng rác.
  static const retention = Duration(days: 30);

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _trash =>
      _db.collection('trash');

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static TrashItem _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = Map<String, dynamic>.from(d.data() ?? <String, dynamic>{});
    final ts = data.remove('deletedAt');
    final col = (data.remove('originalCollection') as String?) ?? 'posts';
    // deletedAt có thể tạm null ngay sau khi ghi (chờ máy chủ): coi là vừa xóa
    return TrashItem(
      d.id,
      col,
      data,
      ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  /// Chuyển bài vào thùng rác: sao chép sang `trash` rồi xóa bài gốc
  /// (cùng một thao tác, hoặc cả hai cùng xong hoặc không gì thay đổi).
  /// Bình luận và cảm xúc của bài được giữ nguyên để khôi phục sau này.
  static Future<void> moveToTrash(Post post) async {
    final ref = _db.collection(post.collection).doc(post.id);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return; // bài đã không còn

    final batch = _db.batch();
    batch.set(_trash.doc(post.id), {
      ...data,
      'originalCollection': post.collection,
      'deletedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(ref);
    await batch.commit();
  }

  /// Danh sách bài trong thùng rác của người dùng hiện tại (mới xóa nhất trước).
  /// Bài quá hạn 30 ngày bị ẩn.
  static Stream<List<TrashItem>> watch() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <TrashItem>[]);
    return _trash.where('authorId', isEqualTo: uid).snapshots().map((s) {
      final items =
          [for (final d in s.docs) _fromDoc(d)]
              .where((i) => !i.expired)
              .toList()
            ..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return items;
    });
  }

  /// Khôi phục bài về đúng chỗ cũ, giữ nguyên ngày đăng.
  static Future<void> restore(TrashItem item) async {
    final batch = _db.batch();
    batch.set(_db.collection(item.originalCollection).doc(item.id), item.data);
    batch.delete(_trash.doc(item.id));
    await batch.commit();
  }

  /// Xóa vĩnh viễn một bài trong thùng rác.
  static Future<void> deleteForever(TrashItem item) async {
    await _deleteSubcollections(item);
    await _trash.doc(item.id).delete();
  }

  /// Dọn bình luận và cảm xúc còn sót của bài (cố gắng hết sức: lỗi quyền
  /// hoặc bài có hơn 400 mục thì bỏ qua phần còn lại).
  static Future<void> _deleteSubcollections(TrashItem item) async {
    final post = _db.collection(item.originalCollection).doc(item.id);
    for (final name in const ['comments', 'reactions']) {
      try {
        final snap = await post.collection(name).limit(400).get();
        if (snap.docs.isEmpty) continue;
        final batch = _db.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      } catch (_) {
        // bỏ qua, không chặn việc xóa bài
      }
    }
  }

  /// Xóa vĩnh viễn toàn bộ thùng rác.
  static Future<void> emptyTrash() async {
    final uid = _uid;
    if (uid == null) return;
    final snap = await _trash.where('authorId', isEqualTo: uid).get();
    for (final d in snap.docs) {
      await deleteForever(_fromDoc(d));
    }
  }

  /// Xóa vĩnh viễn các bài đã quá 30 ngày. Gọi khi mở app (không có
  /// Cloud Functions nên việc dọn dẹp chạy ở phía app).
  static Future<void> purgeExpired() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final snap = await _trash.where('authorId', isEqualTo: uid).get();
      for (final d in snap.docs) {
        final item = _fromDoc(d);
        if (item.expired) await deleteForever(item);
      }
    } catch (_) {
      // lần mở app sau sẽ thử lại
    }
  }
}
