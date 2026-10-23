import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post.dart';
import 'friend_post_sync.dart';
import 'interaction_service.dart';
import 'interest_service.dart';
import 'l10n.dart';

import 'package:flutter/foundation.dart';

class PostService {
  /// Tăng lên mỗi khi có nhánh mới, để các thẻ bài tự đếm lại số nhánh.
  static final ValueNotifier<int> forkTick = ValueNotifier<int>(0);

  /// Số bài tối đa được ghim lên đầu hồ sơ.
  static const maxPinned = 3;

  /// Số lựa chọn tối đa của một bình chọn (mỗi lựa chọn tốn một truy vấn
  /// count() khi hiện kết quả, nên không nên đặt quá cao).
  static const maxPollOptions = 20;

  /// Số gợi ý tối đa tác giả được bổ sung vào một câu hỏi, và độ dài mỗi gợi ý.
  static const maxHints = 10;
  static const maxHintLength = 300;

  static final _db = FirebaseFirestore.instance;
  static final _posts = _db.collection('posts');
  static final _friendPosts = _db.collection('friend_posts');

  static List<Post> _sorted(Iterable<Post> posts) {
    final list = posts.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Số nhánh công khai của một bài.
  static Future<int> forkCount(String id) async {
    final agg = await _posts.where('forkedFrom', isEqualTo: id).count().get();
    return agg.count ?? 0;
  }

  /// Các nhánh công khai của một bài (sắp xếp phía app, không cần chỉ mục mới).
  static Future<List<Post>> getForks(String id) async {
    final s = await _posts.where('forkedFrom', isEqualTo: id).limit(50).get();
    return _sorted(s.docs.map(Post.fromDoc));
  }

  /// Ghép hai luồng danh sách bài. Luồng phụ lỗi (ví dụ chưa có quyền) thì
  /// coi như rỗng để luồng chính vẫn chạy.
  static Stream<List<Post>> _merge(
    Stream<List<Post>> primary,
    Stream<List<Post>> secondary,
  ) {
    late StreamController<List<Post>> c;
    StreamSubscription<List<Post>>? sa;
    StreamSubscription<List<Post>>? sb;
    List<Post>? a;
    List<Post>? b;

    void emit() {
      final first = a;
      if (first == null || c.isClosed) return;
      c.add(_sorted([...first, ...(b ?? const <Post>[])]));
    }

    c = StreamController<List<Post>>(
      onListen: () {
        sa = primary.listen(
          (v) {
            a = v;
            emit();
          },
          onError: (Object e, StackTrace st) {
            if (!c.isClosed) c.addError(e, st);
          },
        );
        sb = secondary.listen(
          (v) {
            b = v;
            emit();
          },
          onError: (_) {
            b = const <Post>[];
            emit();
          },
        );
      },
      onCancel: () async {
        await sa?.cancel();
        await sb?.cancel();
      },
    );
    return c.stream;
  }

  /// Luồng bài công khai mới nhất, tự cập nhật khi có bài mới.
  static Stream<List<Post>> watchPosts() {
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map(Post.fromDoc).toList());
  }

  /// Bài viết của một người dùng: bài công khai, cộng thêm bài chỉ-bạn-bè
  /// nếu đó là bạn hoặc bạn nằm trong danh sách người xem.
  static Stream<List<Post>> watchUserPosts(String uid) {
    final publicStream = _posts
        .where('authorId', isEqualTo: uid)
        .snapshots()
        .map((s) => _sorted(s.docs.map(Post.fromDoc)));

    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return publicStream;

    final Stream<List<Post>> friendStream;
    if (uid == me) {
      friendStream = _friendPosts
          .where('authorId', isEqualTo: me)
          .snapshots()
          .map((s) => s.docs.map(Post.fromDoc).toList());
    } else {
      friendStream = _friendPosts
          .where('audience', arrayContains: me)
          .snapshots()
          .map(
            (s) => s.docs
                .map(Post.fromDoc)
                .where((p) => p.authorId == uid)
                .toList(),
          );
    }
    return _merge(publicStream, friendStream);
  }

  /// Theo dõi một bài viết (null nếu đã bị xóa).
  static Stream<Post?> watchPost(Post post) {
    return post.ref.snapshots().map((s) => s.exists ? Post.fromDoc(s) : null);
  }

  /// Lấy một bài theo mã: thử bài công khai trước, rồi bài chỉ-bạn-bè.
  /// Trả về null nếu không tồn tại hoặc bạn không có quyền xem.
  static Future<Post?> getPost(String id) async {
    try {
      final s = await _posts.doc(id).get();
      if (s.exists) return Post.fromDoc(s);
    } catch (_) {}
    try {
      final s = await _friendPosts.doc(id).get();
      if (s.exists) return Post.fromDoc(s);
    } catch (_) {}
    return null;
  }

  /// Đăng bài gồm nhiều khối: text, image, link.
  /// [visibility]: 'public' (công khai), 'friends' (bạn bè) hoặc 'me' (chỉ mình tôi).
  /// [isQuestion]: đăng như câu hỏi, người xem trả lời bằng bình luận và
  /// tác giả chọn một bình luận làm đáp án. Câu hỏi không có chủ đề
  /// ([spaceId] để rỗng).
  /// [pollClosesAt]: thời điểm khóa bình chọn (null = không giới hạn).
  static Future<String> createPost({
    String spaceId = '',
    required List<Map<String, dynamic>> blocks,
    String spaceSource = 'user', // user, keyword hoặc ai
    String visibility = 'public',
    String? forkedFrom,
    String? forkedFromAuthor,
    DateTime? expiresAt,
    bool isQuestion = false,
    List<String>? pollOptions,
    bool pollMultiple = false,
    DateTime? pollClosesAt,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(msgNotSignedIn);

    final text = blocks
        .where((b) => b['type'] == 'text')
        .map((b) => (b['text'] as String? ?? '').trim())
        .where((t) => t.isNotEmpty)
        .join('\n');
    final hasImage = blocks.any((b) => b['type'] == 'image');
    final preview = text.isNotEmpty
        ? text
        : (hasImage ? tr('[Ảnh]', '[Image]') : tr('[Bài viết]', '[Post]'));

    final name = user.displayName?.trim() ?? '';
    final data = <String, dynamic>{
      'authorId': user.uid,
      'authorName': name.isNotEmpty ? name : (user.email ?? msgUser),
      'spaceId': isQuestion ? '' : spaceId,
      'spaceSource': spaceSource,
      'text': text,
      'blocks': blocks,
      'reactions': 0,
      'comments': 0,
      'reactionSummary': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'forkedFrom': ?forkedFrom,
      'forkedFromAuthor': ?forkedFromAuthor,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      // Chưa có đáp án khi mới đăng (luật Firestore không cho tạo sẵn đáp án)
      if (isQuestion) 'isQuestion': true,
    };

    // Bình chọn: id cố định o0, o1, ... và danh sách id riêng để luật
    // Firestore kiểm tra phiếu bầu hợp lệ
    final options = <String>[
      for (final o in pollOptions ?? const <String>[])
        if (o.trim().isNotEmpty) o.trim(),
    ];
    if (options.isNotEmpty) {
      if (options.length < 2) {
        throw Exception(
          tr(
            'Bình chọn cần ít nhất 2 lựa chọn',
            'A poll needs at least 2 options',
          ),
        );
      }
      if (options.length > maxPollOptions) {
        throw Exception(
          tr(
            'Bình chọn có tối đa $maxPollOptions lựa chọn',
            'A poll can have at most $maxPollOptions options',
          ),
        );
      }
      data['pollOptions'] = [
        for (var i = 0; i < options.length; i++)
          {'id': 'o$i', 'text': options[i]},
      ];
      data['pollOptionIds'] = [for (var i = 0; i < options.length; i++) 'o$i'];
      if (pollMultiple) data['pollMultiple'] = true;
      if (pollClosesAt != null) {
        data['pollClosesAt'] = Timestamp.fromDate(pollClosesAt);
      }
    }

    final DocumentReference<Map<String, dynamic>> ref;
    if (visibility == 'public') {
      ref = await _posts.add(data);
    } else {
      // Bạn bè: người xem là các bạn bè hiện tại. Chỉ mình tôi: không ai khác.
      final audience = visibility == 'friends'
          ? await FriendPostSync.acceptedFriendUids()
          : <String>[];
      ref = await _friendPosts.add({
        ...data,
        'visibility': visibility,
        'audience': audience,
      });
    }

    // Câu hỏi không có chủ đề nên không ghi nhận sở thích chủ đề
    if (!isQuestion && spaceId.isNotEmpty) InterestService.track(spaceId, 3);
    if (forkedFrom != null) forkTick.value++;
    await NotificationService.notifyPostCreated(postId: ref.id, text: preview);
    return ref.id;
  }

  // ---------------------------------------------------------------------
  // Hỏi đáp: gợi ý bổ sung, chọn đáp án và điểm đóng góp
  // ---------------------------------------------------------------------

  /// Tác giả bổ sung một gợi ý vào câu hỏi của mình.
  static Future<void> addHint(Post post, String text) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);
    if (post.authorId != me.uid) {
      throw Exception(
        tr(
          'Chỉ tác giả câu hỏi mới bổ sung gợi ý được',
          'Only the author of the question can add hints',
        ),
      );
    }
    if (!post.isQuestion) {
      throw Exception(
        tr('Bài viết này không phải câu hỏi', 'This post is not a question'),
      );
    }
    final t = text.trim();
    if (t.isEmpty) {
      throw Exception(tr('Gợi ý đang trống', 'The hint is empty'));
    }
    if (t.length > maxHintLength) {
      throw Exception(
        tr(
          'Gợi ý tối đa $maxHintLength ký tự',
          'A hint can have at most $maxHintLength characters',
        ),
      );
    }
    if (post.hints.length >= maxHints) {
      throw Exception(
        tr(
          'Chỉ bổ sung được tối đa $maxHints gợi ý',
          'You can add at most $maxHints hints',
        ),
      );
    }
    await post.ref.update({
      'hints': FieldValue.arrayUnion([
        {'text': t, 'at': Timestamp.now()},
      ]),
    });
  }

  /// Chọn một bình luận gốc làm đáp án (chỉ tác giả câu hỏi).
  ///
  /// [authorId] là uid người viết bình luận, để rỗng nếu là bình luận của AI.
  /// Hai trường được ghi trong cùng một lần cập nhật nên đổi đáp án là một
  /// thao tác duy nhất. Điểm đóng góp chỉ tính với bài công khai: bài bạn bè
  /// hoặc riêng tư luôn ghi `acceptedAuthorId` rỗng.
  static Future<void> acceptAnswer(
    Post post, {
    required String commentId,
    required String authorId,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);
    if (post.authorId != me.uid) {
      throw Exception(
        tr(
          'Chỉ tác giả câu hỏi mới chọn được đáp án',
          'Only the author of the question can pick the answer',
        ),
      );
    }
    if (!post.isQuestion) {
      throw Exception(
        tr('Bài viết này không phải câu hỏi', 'This post is not a question'),
      );
    }
    if (authorId == me.uid) {
      throw Exception(
        tr(
          'Bạn không thể chọn bình luận của chính mình',
          'You cannot pick your own comment',
        ),
      );
    }
    await post.ref.update({
      'acceptedCommentId': commentId,
      'acceptedAuthorId': post.collection == 'posts' ? authorId : '',
    });
  }

  /// Bỏ chọn đáp án: xóa cả hai trường để điểm của người trả lời cũng mất.
  static Future<void> clearAnswer(Post post) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);
    if (post.authorId != me.uid) {
      throw Exception(
        tr(
          'Chỉ tác giả câu hỏi mới bỏ chọn được đáp án',
          'Only the author of the question can unmark the answer',
        ),
      );
    }
    await post.ref.update({
      'acceptedCommentId': FieldValue.delete(),
      'acceptedAuthorId': FieldValue.delete(),
    });
  }

  /// Số lần câu trả lời của [uid] được chọn làm đáp án (dùng cho Dấu vết
  /// đóng góp). Đếm trực tiếp từ dữ liệu gốc bằng `count()`, không lưu điểm
  /// riêng nên không ai tự cộng điểm cho mình được; mỗi lần gọi chỉ tốn
  /// rất ít lượt đọc. Không cần chỉ mục mới.
  static Future<int> acceptedAnswerCount(String uid) async {
    if (uid.isEmpty) return 0;
    final agg = await _posts
        .where('acceptedAuthorId', isEqualTo: uid)
        .count()
        .get();
    return agg.count ?? 0;
  }

  /// Đổi đối tượng xem của một bài: 'public', 'friends' hoặc 'me'.
  static Future<void> changeVisibility(Post post, String target) async {
    if (post.visibility == target) return;

    // Giữa "bạn bè" và "chỉ mình tôi": cùng một collection, chỉ cần cập nhật
    if (post.friendsOnly && target != 'public') {
      final audience = target == 'friends'
          ? await FriendPostSync.acceptedFriendUids()
          : <String>[];
      await post.ref.update({'visibility': target, 'audience': audience});
      return;
    }

    // Giữa công khai và không công khai: bài phải chuyển sang collection khác,
    // bình luận và cảm xúc cũ không đi theo được. Chỉ cho phép khi chưa có tương tác.
    // Phiếu bầu nằm dưới bài cũ nên cũng không đi theo được
    if (post.hasPoll) {
      throw Exception(
        tr(
          'Bài viết có bình chọn nên không thể chuyển giữa công khai và không công khai. Hãy đăng lại bài viết.',
          'This post has a poll, so it cannot be switched between public and non-public. Please publish it again.',
        ),
      );
    }
    if (post.reactions > 0 || post.comments > 0) {
      throw Exception(
        tr(
          'Bài viết đã có cảm xúc hoặc bình luận nên không thể chuyển giữa công khai và không công khai. Hãy đăng lại bài viết.',
          'This post already has reactions or comments, so it cannot be switched between public and non-public. Please publish it again.',
        ),
      );
    }

    final snap = await post.ref.get();
    final data = Map<String, dynamic>.from(snap.data() ?? {});
    if (data.isEmpty) throw Exception(msgPostGone);

    // Kiểm tra theo dữ liệu thật vừa đọc, không theo đối tượng Post có thể đã cũ
    if (((data['reactions'] as num?) ?? 0) > 0 ||
        ((data['comments'] as num?) ?? 0) > 0) {
      throw Exception(
        tr(
          'Bài viết đã có cảm xúc hoặc bình luận nên không thể chuyển giữa công khai và không công khai. Hãy đăng lại bài viết.',
          'This post already has reactions or comments, so it cannot be switched between public and non-public. Please publish it again.',
        ),
      );
    }

    data.remove('acceptedCommentId');
    data.remove('acceptedAuthorId');
    // Dọn các khóa giá trị 0 còn sót để qua luật tạo bài
    data['reactions'] = 0;
    data['comments'] = 0;
    data['reactionSummary'] = <String, dynamic>{};
    // Luật chỉ cho thêm gợi ý bằng lần cập nhật sau khi tạo bài
    final hints = data.remove('hints');
    final DocumentReference<Map<String, dynamic>> targetRef;
    if (target == 'public') {
      data.remove('audience');
      data.remove('visibility');
      targetRef = _posts.doc(post.id);
    } else {
      data['visibility'] = target;
      data['audience'] = target == 'friends'
          ? await FriendPostSync.acceptedFriendUids()
          : <String>[];
      targetRef = _friendPosts.doc(post.id);
    }

    final batch = _db.batch();
    batch.set(targetRef, data);
    batch.delete(post.ref);
    await batch.commit();
    if (hints is List && hints.isNotEmpty) {
      await targetRef.update({'hints': hints});
    }
  }

  static Future<void> deletePost(Post post) => post.ref.delete();

  /// Ghim bài lên đầu hồ sơ (chỉ tác giả, tối đa [maxPinned] bài, tính cả
  /// bài công khai lẫn bài bạn bè/riêng tư).
  static Future<void> pin(Post post) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);
    if (post.authorId != me.uid) {
      throw Exception(
        tr(
          'Chỉ tác giả mới ghim được bài này',
          'Only the author can pin this post',
        ),
      );
    }
    if (post.isPinned) return;

    // Đếm bài đã ghim của mình (lọc phía app để không cần chỉ mục mới)
    var pinned = 0;
    for (final col in [_posts, _friendPosts]) {
      final snap = await col.where('authorId', isEqualTo: me.uid).get();
      pinned += snap.docs.where((d) => d.data()['pinnedAt'] != null).length;
    }
    if (pinned >= maxPinned) {
      throw Exception(
        tr(
          'Chỉ ghim được tối đa $maxPinned bài. Hãy bỏ ghim một bài trước.',
          'You can pin up to $maxPinned posts. Unpin one first.',
        ),
      );
    }
    await post.ref.update({'pinnedAt': Timestamp.now()});
  }

  /// Bỏ ghim bài khỏi đầu hồ sơ.
  static Future<void> unpin(Post post) =>
      post.ref.update({'pinnedAt': FieldValue.delete()});

  /// Đổi chủ đề của một bài viết (chỉ tác giả được phép).
  static Future<void> updateSpace(Post post, String spaceId) {
    return post.ref.update({'spaceId': spaceId, 'spaceSource': 'user'});
  }

  /// Đổi tên tác giả trên tất cả bài viết của một người dùng.
  static Future<void> updateAuthorName(String uid, String name) async {
    for (final col in [_posts, _friendPosts]) {
      final snap = await col.where('authorId', isEqualTo: uid).get();
      var batch = _db.batch();
      var count = 0;
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'authorName': name});
        count++;
        if (count == 400) {
          await batch.commit();
          batch = _db.batch();
          count = 0;
        }
      }
      if (count > 0) await batch.commit();
    }
  }
}
