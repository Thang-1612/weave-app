import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import 'l10n.dart';
import 'interaction_service.dart';

class FeedbackItem {
  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final bool isPublic;
  final DateTime createdAt;

  /// Trả lời: id góp ý gốc và người viết góp ý gốc (rỗng nếu là góp ý gốc).
  final String parentId;
  final String parentAuthorId;

  /// Tên người được trả lời (để hiện "↩ Tên").
  final String replyToName;

  const FeedbackItem({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.isPublic,
    required this.createdAt,
    this.parentId = '',
    this.parentAuthorId = '',
    this.replyToName = '',
  });

  bool get isReply => parentId.isNotEmpty;
}

/// Góp ý cho bài công khai, lưu ở posts/{id}/feedback.
/// Công khai: ai cũng xem. Riêng tư: chỉ tác giả bài và người góp ý xem.
/// Trả lời là một góp ý có parentId, cùng chế độ với góp ý gốc; người viết
/// góp ý gốc luôn đọc được các câu trả lời dành cho mình.
class FeedbackService {
  static CollectionReference<Map<String, dynamic>> _col(Post post) =>
      post.ref.collection('feedback');

  static List<FeedbackItem> _parse(QuerySnapshot<Map<String, dynamic>> s) {
    return s.docs.map((d) {
      final m = d.data();
      final ts = m['createdAt'];
      return FeedbackItem(
        id: d.id,
        authorId: m['authorId'] as String? ?? '',
        authorName: m['authorName'] as String? ?? '',
        text: m['text'] as String? ?? '',
        isPublic: (m['visibility'] as String? ?? 'public') == 'public',
        createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
        parentId: m['parentId'] as String? ?? '',
        parentAuthorId: m['parentAuthorId'] as String? ?? '',
        replyToName: m['replyToName'] as String? ?? '',
      );
    }).toList();
  }

  /// Tác giả bài: thấy tất cả. Người khác: góp ý công khai + góp ý của mình
  /// + các câu trả lời dành cho góp ý của mình.
  /// Chia thành nhiều truy vấn để khớp luật Firestore và không cần chỉ mục.
  static Stream<List<FeedbackItem>> watch(Post post) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return Stream.value(const []);
    final col = _col(post);

    if (post.authorId == me.uid) {
      return col.limit(200).snapshots().map((s) {
        final l = _parse(s)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return l;
      });
    }

    late StreamController<List<FeedbackItem>> ctrl;
    final subs = <StreamSubscription>[];
    var pub = <FeedbackItem>[];
    var mine = <FeedbackItem>[];
    var toMe = <FeedbackItem>[];

    void emit() {
      final map = <String, FeedbackItem>{
        for (final i in [...pub, ...mine, ...toMe]) i.id: i,
      };
      final l = map.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      ctrl.add(l);
    }

    ctrl = StreamController<List<FeedbackItem>>(
      onListen: () {
        subs.add(col
            .where('visibility', isEqualTo: 'public')
            .limit(100)
            .snapshots()
            .listen((s) {
          pub = _parse(s);
          emit();
        }, onError: ctrl.addError));
        subs.add(col
            .where('authorId', isEqualTo: me.uid)
            .limit(100)
            .snapshots()
            .listen((s) {
          mine = _parse(s);
          emit();
        }, onError: ctrl.addError));
        // Câu trả lời riêng tư dành cho góp ý của mình
        subs.add(col
            .where('parentAuthorId', isEqualTo: me.uid)
            .limit(100)
            .snapshots()
            .listen((s) {
          toMe = _parse(s);
          emit();
        }, onError: ctrl.addError));
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
      },
    );
    return ctrl.stream;
  }

  /// Gửi góp ý mới, hoặc trả lời nếu có [replyRoot] (góp ý gốc của chuỗi).
  /// Trả lời luôn cùng chế độ công khai/riêng tư với góp ý gốc.
  static Future<void> send(
      Post post,
      String text, {
        required bool isPublic,
        FeedbackItem? replyRoot,
        String replyToName = '',
      }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);
    final name = (me.displayName?.trim().isNotEmpty ?? false)
        ? me.displayName!.trim()
        : (me.email ?? tr('Người dùng', 'User'));

    final data = <String, dynamic>{
      'authorId': me.uid,
      'authorName': name,
      'text': text.trim(),
      'visibility': isPublic ? 'public' : 'private',
      'createdAt': FieldValue.serverTimestamp(),
    };
    final root = replyRoot;
    if (root != null) {
      data['visibility'] = root.isPublic ? 'public' : 'private';
      data['parentId'] = root.id;
      data['parentAuthorId'] = root.authorId;
      if (replyToName.isNotEmpty) data['replyToName'] = replyToName;
    }

    final ref = await _col(post).add(data);

    // Báo cho tác giả khi người khác góp ý. Lỗi ở bước này không làm hỏng góp ý.
    if (post.authorId != me.uid) {
      try {
        await NotificationService.notifyFeedback(
          post: post,
          feedbackId: ref.id,
        );
      } catch (_) {}
    }
  }

  static Future<void> delete(Post post, String id) =>
      _col(post).doc(id).delete();
}