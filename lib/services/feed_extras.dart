import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post.dart';

class FeedExtras {
  /// Các bài công khai mới nhất (dùng để lọc ra bài của người yêu thích).
  static Stream<List<Post>> watchLatest(int limit) {
    return FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Post.fromDoc).toList());
  }

  /// Bài chỉ-bạn-bè mà bạn được xem: của chính bạn và của bạn bè hiện tại.
  /// Luôn kiểm tra lại danh sách bạn bè phía ứng dụng, nên bài của người vừa
  /// hủy kết bạn biến mất ngay.
  static Stream<List<Post>> watchFriendPosts() {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return Stream.value(const <Post>[]);
    final db = FirebaseFirestore.instance;

    late StreamController<List<Post>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subMine;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subShared;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subFriends;

    var mine = <Post>[];
    var shared = <Post>[];
    var friends = <String>{};

    void emit() {
      if (controller.isClosed) return;
      final all = [
        ...mine,
        ...shared.where((p) => friends.contains(p.authorId)),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(all);
    }

    controller = StreamController<List<Post>>(
      onListen: () {
        subMine = db
            .collection('friend_posts')
            .where('authorId', isEqualTo: me)
            .snapshots()
            .listen((s) {
              mine = s.docs.map(Post.fromDoc).toList();
              emit();
            }, onError: (_) {});

        subShared = db
            .collection('friend_posts')
            .where('audience', arrayContains: me)
            .snapshots()
            .listen((s) {
              shared = s.docs.map(Post.fromDoc).toList();
              emit();
            }, onError: (_) {});

        subFriends = db
            .collection('friendships')
            .where('users', arrayContains: me)
            .snapshots()
            .listen((s) {
              final set = <String>{};
              for (final d in s.docs) {
                final data = d.data();
                if (data['status'] != 'accepted') continue;
                for (final u in (data['users'] as List? ?? const [])) {
                  if (u is String && u != me) set.add(u);
                }
              }
              friends = set;
              emit();
            }, onError: (_) {});
      },
      onCancel: () async {
        await subMine?.cancel();
        await subShared?.cancel();
        await subFriends?.cancel();
      },
    );
    return controller.stream;
  }
}
