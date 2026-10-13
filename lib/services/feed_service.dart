import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import '../models/space.dart';
import 'post_service.dart';

/// Kết quả bảng tin: danh sách bài và các danh mục đang được ưu tiên
/// (rỗng nghĩa là bảng tin thường, không cá nhân hóa).
class FeedResult {
  final List<Post> posts;
  final List<Space> priority;

  const FeedResult(this.posts, [this.priority = const <Space>[]]);
}

class FeedService {
  /// Số bài tối thiểu của danh mục được ưu tiên hiện ở đầu bảng tin.
  static const minPriorityPosts = 20;

  /// Điểm quan tâm tối thiểu để bật chế độ đề xuất (một lần chọn xem danh mục).
  static const minAffinity = 2.0;

  static final _posts = FirebaseFirestore.instance.collection('posts');

  static Query<Map<String, dynamic>> _spaceQuery(String spaceId, int limit) {
    return _posts
        .where('spaceId', isEqualTo: spaceId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  /// Bài của một danh mục, mới nhất trước. Nếu chưa tạo chỉ mục kết hợp thì
  /// tạm lọc từ 100 bài mới nhất.
  static Stream<List<Post>> _watchSpacePosts(String spaceId, int limit) async* {
    try {
      await for (final s in _spaceQuery(spaceId, limit).snapshots()) {
        yield s.docs.map(Post.fromDoc).toList();
      }
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      yield* _posts
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map(
            (s) => s.docs
            .map(Post.fromDoc)
            .where((p) => p.spaceId == spaceId)
            .take(limit)
            .toList(),
      );
    }
  }

  /// Bài của nhiều danh mục (một chủ đề lớn), mới nhất trước. Dùng cùng chỉ mục
  /// spaceId + createdAt. Firestore giới hạn tối đa 30 giá trị trong whereIn.
  static Stream<List<Post>> _watchGroupPosts(
      List<String> spaceIds, int limit) async* {
    try {
      final query = _posts
          .where('spaceId', whereIn: spaceIds)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      await for (final s in query.snapshots()) {
        yield s.docs.map(Post.fromDoc).toList();
      }
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      final ids = spaceIds.toSet();
      yield* _posts
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map(
            (s) => s.docs
            .map(Post.fromDoc)
            .where((p) => ids.contains(p.spaceId))
            .take(limit)
            .toList(),
      );
    }
  }
  /// Bảng tin của một danh sách chủ đề (dùng cho công thức bảng tin).
  static Stream<FeedResult> watchSpaces(List<String> ids) {
    return _watchGroupPosts(ids.take(30).toList(), 60)
        .map((p) => FeedResult(p));
  }
  /// Bảng tin khi chọn riêng một danh mục.
  static Stream<FeedResult> watchSpace(String spaceId) {
    return _watchSpacePosts(spaceId, 40).map((posts) => FeedResult(posts));
  }

  /// Bảng tin khi chọn cả một chủ đề lớn (gồm nhiều chủ đề nhỏ).
  static Stream<FeedResult> watchGroup(SpaceGroup group) {
    return _watchGroupPosts(group.childIds, 60).map((p) => FeedResult(p));
  }

  /// Bảng tin "Tất cả" có đề xuất theo sở thích.
  static Stream<FeedResult> watchForYou(Map<String, double> affinity) {
    final ranked = defaultSpaces
        .where((s) => (affinity[s.id] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (affinity[b.id] ?? 0).compareTo(affinity[a.id] ?? 0));

    final maxAff = ranked.isEmpty ? 0.0 : affinity[ranked.first.id]!;

    // Chưa đủ dữ liệu sở thích: bảng tin mới nhất như bình thường
    if (maxAff < minAffinity) {
      return PostService.watchPosts().map((posts) => FeedResult(posts));
    }

    // Tối đa 2 danh mục ưu tiên: danh mục đứng đầu và danh mục có điểm xấp xỉ
    final priority =
    ranked.where((s) => affinity[s.id]! >= maxAff * 0.6).take(2).toList();
    final priorityIds = priority.map((s) => s.id).toList();
    const recentKey = '_recent';

    late StreamController<FeedResult> controller;
    final subs = <StreamSubscription<List<Post>>>[];
    final latest = <String, List<Post>>{};

    void emit() {
      if (controller.isClosed) return;
      // Chờ các danh mục ưu tiên và luồng bài mới nhất tải xong rồi mới hiện
      if (!priorityIds.every(latest.containsKey) ||
          !latest.containsKey(recentKey)) {
        return;
      }
      controller.add(
        FeedResult(_rank(latest, affinity, priorityIds), priority),
      );
    }

    controller = StreamController<FeedResult>(
      onListen: () {
        void onError(Object e, StackTrace st) {
          if (!controller.isClosed) controller.addError(e, st);
        }

        // Chỉ theo dõi các danh mục ưu tiên (25 bài mỗi danh mục)...
        for (final id in priorityIds) {
          subs.add(
            _watchSpacePosts(id, 25).listen(
                  (posts) {
                latest[id] = posts;
                emit();
              },
              onError: onError,
            ),
          );
        }
        // ...cộng một luồng bài mới nhất chung cho phần còn lại của bảng tin.
        subs.add(
          PostService.watchPosts().listen(
                (posts) {
              latest[recentKey] = posts;
              emit();
            },
            onError: onError,
          ),
        );
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return controller.stream;
  }

  static List<Post> _rank(
      Map<String, List<Post>> latest,
      Map<String, double> affinity,
      List<String> priorityIds,
      ) {
    // 1. Khối ưu tiên: xen kẽ bài mới nhất của các danh mục ưu tiên cho đến
    //    khi đủ 20 bài (hoặc hết bài).
    final first = <Post>[];
    final used = <String>{};
    final lists = [
      for (final id in priorityIds) [...(latest[id] ?? const <Post>[])],
    ];
    var i = 0;
    while (first.length < minPriorityPosts && lists.any((l) => i < l.length)) {
      for (final l in lists) {
        if (i < l.length && first.length < minPriorityPosts) {
          first.add(l[i]);
          used.add(l[i].id);
        }
      }
      i++;
    }

    // 2. Phần còn lại: xếp theo độ mới, danh mục được quan tâm hơn thì được
    //    cộng thêm tối đa 36 giờ.
    final maxAff = affinity.values.fold<double>(0, (a, b) => a > b ? a : b);
    double effective(Post p) {
      final bonusHours =
      maxAff <= 0 ? 0.0 : (affinity[p.spaceId] ?? 0) / maxAff * 36;
      return p.createdAt.millisecondsSinceEpoch + bonusHours * 3600 * 1000;
    }

    // Một bài có thể xuất hiện ở cả danh sách ưu tiên và danh sách mới nhất,
    // nên loại trùng theo id.
    final seen = {...used};
    final rest = <Post>[];
    for (final l in latest.values) {
      for (final p in l) {
        if (seen.add(p.id)) rest.add(p);
      }
    }
    rest.sort((a, b) => effective(b).compareTo(effective(a)));

    return [...first, ...rest];
  }

  /// CHỈ ĐỂ THỬ NGHIỆM: tạo nhiều bài mẫu trong một danh mục.
  static Future<void> debugSeed(String spaceId, int count) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = user.displayName?.trim() ?? '';
    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();

    for (var i = 0; i < count; i++) {
      final ref = _posts.doc();
      final text = 'Bài mẫu số ${i + 1} (chủ đề $spaceId)';
      batch.set(ref, {
        'authorId': user.uid,
        'authorName': name.isNotEmpty ? name : (user.email ?? 'Người dùng'),
        'spaceId': spaceId,
        'text': text,
        'blocks': [
          {'type': 'text', 'text': text},
        ],
        'reactions': 0,
        'comments': 0,
        'reactionSummary': <String, dynamic>{},
        'createdAt': Timestamp.fromDate(now.subtract(Duration(minutes: i * 7))),
      });
    }
    await batch.commit();
  }
}