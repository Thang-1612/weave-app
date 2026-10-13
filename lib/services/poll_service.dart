import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import 'l10n.dart';

/// Kết quả một cuộc bình chọn tại thời điểm đếm.
class PollResults {
  /// id lựa chọn -> số người đã chọn
  final Map<String, int> counts;

  /// Tổng số người đã bình chọn (một người chọn nhiều đáp án vẫn tính một)
  final int voters;

  const PollResults(this.counts, this.voters);
}

/// Bình chọn trong bài: mỗi người một tài liệu `poll_votes/{uid}` dưới bài,
/// nên đổi hoặc rút phiếu chỉ là ghi đè hoặc xóa đúng tài liệu của mình.
/// Kết quả đếm bằng `count()` nên số người bình chọn không bị giới hạn bởi
/// kích thước tài liệu và không có bộ đếm nào bị tranh chấp ghi.
/// Bình chọn có thể có thời hạn khóa (`pollClosesAt`): quá hạn thì không bỏ,
/// đổi hay rút phiếu được nữa (luật Firestore cũng chặn).
class PollService {
  static CollectionReference<Map<String, dynamic>> _votes(Post post) =>
      post.ref.collection('poll_votes');

  static Exception _closed() => Exception(
    tr('Bình chọn đã khóa', 'This poll is closed'),
  );

  /// Phiếu của mình: danh sách id lựa chọn, hoặc null nếu chưa bình chọn.
  static Stream<List<String>?> watchMyVote(Post post) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _votes(post).doc(uid).snapshots().map((s) {
      if (!s.exists) return null;
      final raw = s.data()?['choices'];
      if (raw is! List) return null;
      return raw.map((e) => e.toString()).toList();
    });
  }

  /// Bình chọn (hoặc đổi bình chọn). Bài chọn một đáp án chỉ nhận một lựa chọn.
  static Future<void> vote(Post post, Iterable<String> choices) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);
    if (post.pollClosed) throw _closed();

    final valid = post.pollOptions.map((o) => o.id).toSet();
    final picked = choices.where(valid.contains).toSet().toList();
    if (picked.isEmpty) {
      throw Exception(
        tr('Hãy chọn ít nhất một lựa chọn', 'Pick at least one option'),
      );
    }
    if (picked.length > 1 && !post.pollMultiple) {
      throw Exception(
        tr('Bình chọn này chỉ cho chọn một đáp án',
            'This poll allows only one answer'),
      );
    }
    await _votes(post).doc(me.uid).set({
      'choices': picked,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Rút phiếu của mình.
  static Future<void> removeVote(Post post) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);
    if (post.pollClosed) throw _closed();
    await _votes(post).doc(me.uid).delete();
  }

  /// Đếm kết quả: mỗi lựa chọn một truy vấn `count()` chạy song song, cộng
  /// một truy vấn đếm tổng người bình chọn. Mỗi truy vấn tính tối thiểu một
  /// lượt đọc, nên chỉ gọi khi thật sự hiện kết quả.
  static Future<PollResults> results(Post post) async {
    final votes = _votes(post);
    final entries = await Future.wait(
      post.pollOptions.map((o) async {
        final agg =
        await votes.where('choices', arrayContains: o.id).count().get();
        return MapEntry(o.id, agg.count ?? 0);
      }),
    );
    final total = await votes.count().get();
    return PollResults(Map.fromEntries(entries), total.count ?? 0);
  }
}