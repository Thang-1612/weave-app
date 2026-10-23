import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/interactions.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
import 'interaction_service.dart';
import 'interest_service.dart';
import 'l10n.dart';

/// Bình luận nâng cao: trả lời, tag bạn bè, cảm xúc, báo cáo, bình luận của AI.
class ThreadService {
  // ignore: unused_field
  static final _posts = FirebaseFirestore.instance.collection('posts');

  static const List<String> reportReasons = [
    'Spam hoặc quảng cáo',
    'Quấy rối hoặc ngôn từ thù ghét',
    'Thông tin sai lệch',
    'Nội dung không phù hợp',
    'Lý do khác',
  ];

  static User get _me {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw Exception(msgNotSignedIn);
    return u;
  }

  static String _nameOf(User u) {
    final n = u.displayName?.trim() ?? '';
    return n.isNotEmpty ? n : (u.email ?? msgUser);
  }

  static String _preview(String t) {
    final s = t.trim().replaceAll('\n', ' ');
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }

  static Future<void> _notify(
    String toUid,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (toUid.isEmpty || toUid == 'ai') return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(toUid)
          .collection('notifications')
          .doc(id)
          .set({
            ...data,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      // Đã tồn tại (chống trùng) hoặc không có quyền: bỏ qua
    }
  }

  /// Gửi bình luận (gốc hoặc trả lời). Trả về mã bình luận vừa tạo.
  static Future<String> addComment({
    required Post post,
    required String text,
    List<Mention> mentions = const [],
    Comment? replyTo,
  }) async {
    final me = _me;
    final clean = text.trim();
    if (clean.isEmpty) throw Exception(msgCommentEmpty);

    final postRef = post.ref;
    final commentRef = postRef.collection('comments').doc();
    // Trả lời một câu trả lời thì vẫn gắn vào bình luận gốc (chỉ một cấp)
    final parentId = replyTo == null
        ? ''
        : (replyTo.parentId.isNotEmpty ? replyTo.parentId : replyTo.id);
    var total = 0;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      if (!snap.exists) throw Exception(msgPostGone);
      final d = snap.data()!;
      final reactions = (d['reactions'] as num?)?.toInt() ?? 0;
      final comments = (d['comments'] as num?)?.toInt() ?? 0;

      tx.set(commentRef, {
        'authorId': me.uid,
        'authorName': _nameOf(me),
        'text': clean,
        'parentId': parentId,
        'replyToUid': replyTo?.authorId ?? '',
        'replyToName': replyTo?.authorName ?? '',
        'mentions': mentions.map((m) => m.toMap()).toList(),
        'reactions': 0,
        'reactionSummary': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(postRef, {
        'comments': FieldValue.increment(1),
      }, SetOptions(merge: true));
      total = reactions + comments + 1;
    });

    InterestService.track(post.spaceId, 3);

    // Thông báo: mỗi người nhận tối đa một thông báo cho bình luận này
    final notified = <String>{me.uid};
    final base = {
      'fromUserId': me.uid,
      'fromName': _nameOf(me),
      'postId': post.id,
      'preview': _preview(clean),
    };

    final replyUid = replyTo?.authorId ?? '';
    if (replyUid.isNotEmpty && replyUid != 'ai' && notified.add(replyUid)) {
      await _notify(replyUid, 'reply_${commentRef.id}', {
        ...base,
        'type': 'reply',
      });
    }
    for (final m in mentions) {
      if (m.uid == 'ai' || !notified.add(m.uid)) continue;
      await _notify(m.uid, 'mention_${commentRef.id}_${m.uid}', {
        ...base,
        'type': 'mention',
      });
    }
    if (post.authorId.isNotEmpty && notified.add(post.authorId)) {
      await NotificationService.notifyComment(
        post: post,
        text: clean,
        commentId: commentRef.id,
      );
    }
    await NotificationService.maybeMilestone(post: post, total: total);

    return commentRef.id;
  }

  /// Ghi câu trả lời của trợ lý AI vào chuỗi bình luận [topId].
  static Future<void> addAiComment({
    required Post post,
    required String text,
    required String topId,
    required String askerUid,
    required String askerName,
  }) async {
    final me = _me;
    final postRef = post.ref;
    final commentRef = postRef.collection('comments').doc();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      if (!snap.exists) throw Exception(msgPostGone);

      tx.set(commentRef, {
        'authorId': 'ai',
        'authorName': 'Trợ lý AI',
        'isAi': true,
        'requestedBy': me.uid,
        'text': '@$askerName $text',
        'parentId': topId,
        'replyToUid': askerUid,
        'replyToName': askerName,
        'mentions': [Mention(askerUid, askerName).toMap()],
        'reactions': 0,
        'reactionSummary': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(postRef, {
        'comments': FieldValue.increment(1),
      }, SetOptions(merge: true));
    });
  }

  // -------------------------------------------------------------------------
  // Cảm xúc trên bình luận
  // -------------------------------------------------------------------------

  static DocumentReference<Map<String, dynamic>> _commentRef(
    String postId,
    String commentId, [
    String collection = 'posts',
  ]) {
    return FirebaseFirestore.instance
        .collection(collection)
        .doc(postId)
        .collection('comments')
        .doc(commentId);
  }

  static Stream<String?> watchMyCommentReaction(
    String postId,
    String commentId, {
    String collection = 'posts',
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _commentRef(postId, commentId, collection)
        .collection('reactions')
        .doc(uid)
        .snapshots()
        .map((s) => s.data()?['emoji'] as String?);
  }

  /// Thả cảm xúc: chưa thả thì thêm, chọn lại cùng icon thì bỏ, icon khác thì đổi.
  static Future<void> setCommentReaction(
    Post post,
    Comment comment,
    String emoji,
  ) async {
    final me = _me;
    final commentRef = _commentRef(post.id, comment.id, post.collection);
    final myRef = commentRef.collection('reactions').doc(me.uid);
    var added = false;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      added = false;
      final cSnap = await tx.get(commentRef);
      if (!cSnap.exists) throw Exception(msgCommentGone);
      final mySnap = await tx.get(myRef);
      final old = mySnap.data()?['emoji'] as String?;

      if (old == null) {
        tx.set(myRef, {
          'emoji': emoji,
          'userId': me.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(commentRef, {
          'reactions': FieldValue.increment(1),
          'reactionSummary': {emoji: FieldValue.increment(1)},
        }, SetOptions(merge: true));
        added = true;
      } else if (old == emoji) {
        tx.delete(myRef);
        tx.set(commentRef, {
          'reactions': FieldValue.increment(-1),
          'reactionSummary': {emoji: FieldValue.increment(-1)},
        }, SetOptions(merge: true));
      } else {
        tx.update(myRef, {
          'emoji': emoji,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(commentRef, {
          'reactionSummary': {
            old: FieldValue.increment(-1),
            emoji: FieldValue.increment(1),
          },
        }, SetOptions(merge: true));
      }
    });

    if (added) {
      InterestService.track(post.spaceId, 1);
      if (comment.authorId != me.uid && comment.authorId != 'ai') {
        // Mỗi người chỉ tạo một thông báo cho mỗi bình luận
        await _notify(comment.authorId, 'creaction_${comment.id}_${me.uid}', {
          'type': 'comment_reaction',
          'fromUserId': me.uid,
          'fromName': _nameOf(me),
          'postId': post.id,
          'preview': _preview(comment.text),
          'emoji': emoji,
        });
      }
    }
  }

  // -------------------------------------------------------------------------
  // Báo cáo
  // -------------------------------------------------------------------------

  /// Gửi báo cáo bình luận. Trả về false nếu không gửi được, thường là vì
  /// bạn đã báo cáo bình luận này trước đó (mỗi người báo cáo một lần).
  static Future<bool> reportComment({
    required Post post,
    required Comment comment,
    required String reason,
    String note = '',
  }) async {
    final me = _me;
    final snippet = comment.text.length > 300
        ? comment.text.substring(0, 300)
        : comment.text;
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc('${comment.id}_${me.uid}')
          .set({
            'type': 'comment',
            'postId': post.id,
            'commentId': comment.id,
            'commentAuthorId': comment.authorId,
            'commentText': snippet,
            'reporterId': me.uid,
            'reason': reason,
            'note': note.trim(),
            'status': 'open',
            'createdAt': FieldValue.serverTimestamp(),
          });
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Tag bạn bè
  // -------------------------------------------------------------------------

  /// Danh sách bạn bè (đã chấp nhận) để gợi ý khi gõ @.
  static Future<List<UserProfile>> loadFriends() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return [];

    final snap = await FirebaseFirestore.instance
        .collection('friendships')
        .where('users', arrayContains: me)
        .get();

    final uids = <String>[];
    for (final d in snap.docs) {
      final data = d.data();
      if (data['status'] != 'accepted') continue;
      final users = List<String>.from(data['users'] as List? ?? const []);
      final other = users.firstWhere((u) => u != me, orElse: () => '');
      if (other.isNotEmpty) uids.add(other);
    }

    final result = <UserProfile>[];
    for (var i = 0; i < uids.length; i += 10) {
      final end = i + 10 > uids.length ? uids.length : i + 10;
      final chunk = uids.sublist(i, end);
      final users = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .limit(10)
          .get();
      for (final u in users.docs) {
        final p = UserProfile.fromMap(u.id, u.data());
        if (p.name.isNotEmpty) result.add(p);
      }
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }
}
