import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/interactions.dart';
import '../models/post.dart';
import 'interest_service.dart';
import 'l10n.dart';

final _posts = FirebaseFirestore.instance.collection('posts');

// ---------------------------------------------------------------------------
// Thông báo
// ---------------------------------------------------------------------------
class NotificationService {
  static CollectionReference<Map<String, dynamic>> _col(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');
  }

  static String get _myName {
    final u = FirebaseAuth.instance.currentUser;
    final n = u?.displayName?.trim() ?? '';
    return n.isNotEmpty ? n : (u?.email ?? msgUser);
  }

  static String _preview(String t) {
    final s = t.trim().replaceAll('\n', ' ');
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }

  /// Mốc tương tác: 10, 20, ..., 100, sau đó mỗi 100 (200, 300, ...).
  static bool isMilestone(int n) {
    if (n <= 0) return false;
    return n <= 100 ? n % 10 == 0 : n % 100 == 0;
  }

  static Future<void> _create(
      String toUid,
      String id,
      Map<String, dynamic> data,
      ) async {
    if (toUid.isEmpty) return;
    try {
      await _col(toUid).doc(id).set({
        ...data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Thông báo này đã tồn tại (chống trùng) hoặc không có quyền: bỏ qua
    }
  }

  static Stream<List<AppNotification>> watchMine() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const <AppNotification>[]);
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(AppNotification.fromDoc).toList());
  }

  static Stream<int> watchUnreadCount() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return _col(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.size);
  }

  static Future<void> markRead(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _col(uid).doc(id).update({'read': true});
  }

  static Future<void> markAllRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await _col(uid).where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  static Future<void> notifyPostCreated({
    required String postId,
    required String text,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    await _create(me.uid, 'post_$postId', {
      'type': 'post_created',
      'fromUserId': me.uid,
      'fromName': _myName,
      'postId': postId,
      'preview': _preview(text),
    });
  }

  static Future<void> notifyReaction({
    required Post post,
    required String emoji,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    // Mỗi người chỉ tạo một thông báo cho mỗi bài viết
    await _create(post.authorId, 'reaction_${post.id}_${me.uid}', {
      'type': 'reaction',
      'fromUserId': me.uid,
      'fromName': _myName,
      'postId': post.id,
      'preview': _preview(post.text),
      'emoji': emoji,
    });
  }

  static Future<void> notifyComment({
    required Post post,
    required String text,
    required String commentId,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    await _create(post.authorId, 'comment_$commentId', {
      'type': 'comment',
      'fromUserId': me.uid,
      'fromName': _myName,
      'postId': post.id,
      'preview': _preview(text),
    });
  }
  static Future<void> notifyFeedback({
    required Post post,
    required String feedbackId,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    await _create(post.authorId, 'feedback_$feedbackId', {
      'type': 'feedback',
      'fromUserId': me.uid,
      'fromName': _myName,
      'postId': post.id,
      'preview': '',
    });
  }

  static Future<void> maybeMilestone({
    required Post post,
    required int total,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || !isMilestone(total)) return;
    await _create(post.authorId, 'milestone_${post.id}_$total', {
      'type': 'milestone',
      'fromUserId': me.uid,
      'fromName': _myName,
      'postId': post.id,
      'preview': _preview(post.text),
      'count': total,
    });
  }
}

// ---------------------------------------------------------------------------
// Cảm xúc
// ---------------------------------------------------------------------------
class ReactionService {
  static const _recentKey = 'recent_custom_emojis';

  /// Cảm xúc hiện tại của tôi trên một bài viết (null nếu chưa thả).
  static Stream<String?> watchMyReaction(
      String postId, {
        String collection = 'posts',
      }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection(collection)
        .doc(postId)
        .collection('reactions')
        .doc(uid)
        .snapshots()
        .map((s) => s.data()?['emoji'] as String?);
  }

  /// Thả cảm xúc: chưa thả thì thêm, chọn lại cùng icon thì bỏ, chọn icon khác thì đổi.
  static Future<void> setReaction(Post post, String emoji) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);

    final postRef = post.ref;
    final myRef = postRef.collection('reactions').doc(me.uid);
    var added = false;
    var total = 0;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      added = false;
      final postSnap = await tx.get(postRef);
      if (!postSnap.exists) throw Exception('msgPostGone');
      final mySnap = await tx.get(myRef);

      final d = postSnap.data()!;
      final reactions = (d['reactions'] as num?)?.toInt() ?? 0;
      final comments = (d['comments'] as num?)?.toInt() ?? 0;
      final old = mySnap.data()?['emoji'] as String?;

      if (old == null) {
        tx.set(myRef, {
          'emoji': emoji,
          'userId': me.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(
          postRef,
          {
            'reactions': FieldValue.increment(1),
            'reactionSummary': {emoji: FieldValue.increment(1)},
          },
          SetOptions(merge: true),
        );
        added = true;
        total = reactions + 1 + comments;
      } else if (old == emoji) {
        tx.delete(myRef);
        tx.set(
          postRef,
          {
            'reactions': FieldValue.increment(-1),
            'reactionSummary': {emoji: FieldValue.increment(-1)},
          },
          SetOptions(merge: true),
        );
      } else {
        tx.update(myRef, {
          'emoji': emoji,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(
          postRef,
          {
            'reactionSummary': {
              old: FieldValue.increment(-1),
              emoji: FieldValue.increment(1),
            },
          },
          SetOptions(merge: true),
        );
      }
    });

    if (added) {
      InterestService.track(post.spaceId, 2);
      if (post.authorId != me.uid) {
        await NotificationService.notifyReaction(post: post, emoji: emoji);
      }
      await NotificationService.maybeMilestone(post: post, total: total);
    }
  }

  /// Các icon tự chọn gần đây (hiện cạnh cảm xúc chính).
  static Future<List<String>> recentCustom() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.from(prefs.getStringList(_recentKey) ?? []);
  }

  static Future<void> rememberCustom(String emoji) async {
    if (mainReactions.any((r) => r.emoji == emoji)) return;
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(prefs.getStringList(_recentKey) ?? []);
    list.remove(emoji);
    list.insert(0, emoji);
    await prefs.setStringList(_recentKey, list.take(3).toList());
  }
}

// ---------------------------------------------------------------------------
// Bình luận
// ---------------------------------------------------------------------------
class CommentService {
  static Stream<List<Comment>> watchComments(
      String postId, {
        String collection = 'posts',
      }) {
    return FirebaseFirestore.instance
        .collection(collection)
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(Comment.fromDoc).toList());
  }

  static Future<void> addComment(Post post, String text) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);
    final clean = text.trim();
    if (clean.isEmpty) return;

    final name = me.displayName?.trim() ?? '';
    final postRef = post.ref;
    final commentRef = postRef.collection('comments').doc();
    var total = 0;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      if (!snap.exists) throw Exception(msgPostGone);
      final d = snap.data()!;
      final reactions = (d['reactions'] as num?)?.toInt() ?? 0;
      final comments = (d['comments'] as num?)?.toInt() ?? 0;

      tx.set(commentRef, {
        'authorId': me.uid,
        'authorName': name.isNotEmpty ? name : (me.email ?? msgUser),
        'text': clean,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        postRef,
        {'comments': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
      total = reactions + comments + 1;
    });

    InterestService.track(post.spaceId, 3);
    if (post.authorId != me.uid) {
      await NotificationService.notifyComment(
        post: post,
        text: clean,
        commentId: commentRef.id,
      );
    }
    await NotificationService.maybeMilestone(post: post, total: total);
  }

  static Future<void> deleteComment(Post post, Comment comment) async {
    final postRef = post.ref;
    final commentRef = postRef.collection('comments').doc(comment.id);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.delete(commentRef);
      tx.set(
        postRef,
        {'comments': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );
    });
  }
}