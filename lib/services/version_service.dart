import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';
import 'l10n.dart';
import 'post_service.dart';
import 'social_extras_service.dart';

class PostVersion {
  final String id;
  final String text;
  final List<Map<String, dynamic>> blocks;
  final DateTime savedAt;
  final String reason;
  const PostVersion(this.id, this.text, this.blocks, this.savedAt, this.reason);
}

/// Lịch sử phiên bản của một bài công khai. Giữ tối đa [keep] bản gần nhất
/// (ảnh lưu dạng base64 nên mỗi bản có thể khá nặng).
class VersionService {
  static const keep = 5;

  static CollectionReference<Map<String, dynamic>> _col(String postId) =>
      FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('versions');

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Lưu nội dung hiện tại của bài thành một phiên bản, rồi dọn bớt bản cũ.
  static Future<void> snapshot(Post p, String reason) async {
    await _col(p.id).add({
      'blocks': p.blocks,
      'text': p.text,
      'savedAt': FieldValue.serverTimestamp(),
      'reason': reason.length > 200 ? reason.substring(0, 200) : reason,
    });
    try {
      final s = await _col(p.id)
          .orderBy('savedAt', descending: true)
          .limit(keep + 5)
          .get();
      final extra = s.docs.skip(keep).toList();
      if (extra.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in extra) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  static Future<List<PostVersion>> load(Post p) async {
    final s = await _col(p.id)
        .orderBy('savedAt', descending: true)
        .limit(keep)
        .get();
    return s.docs.map((d) {
      final m = d.data();
      final ts = m['savedAt'];
      final blocks = <Map<String, dynamic>>[];
      final raw = m['blocks'];
      if (raw is List) {
        for (final b in raw) {
          if (b is Map) blocks.add(Map<String, dynamic>.from(b));
        }
      }
      return PostVersion(
        d.id,
        m['text'] as String? ?? '',
        blocks,
        ts is Timestamp ? ts.toDate() : DateTime.now(),
        m['reason'] as String? ?? '',
      );
    }).toList();
  }

  /// Khôi phục một phiên bản. Nội dung hiện tại được lưu lại trước, nên
  /// việc khôi phục cũng hoàn tác được.
  static Future<void> restore(Post current, PostVersion v) async {
    final fresh = await PostService.getPost(current.id) ?? current;
    await snapshot(
      fresh,
      tr(
        'Trước khi khôi phục bản ngày ${_fmt(v.savedAt)}',
        'Before restoring the version from ${_fmt(v.savedAt)}',
      ),
    );
    await fresh.ref.update({'blocks': v.blocks, 'text': v.text});
    await LivePostService.addSystemUpdate(
      fresh,
      tr(
        'Đã khôi phục phiên bản ngày ${_fmt(v.savedAt)}',
        'Restored the version from ${_fmt(v.savedAt)}',
      ),
      'restore',
    );
  }
}
