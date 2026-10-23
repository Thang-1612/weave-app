import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post.dart';

/// Các bài của mình đăng vào cùng ngày, cách đây [yearsAgo] năm.
class OnThisDayGroup {
  final int yearsAgo;
  final DateTime date;
  final List<Post> posts;

  const OnThisDayGroup(this.yearsAgo, this.date, this.posts);
}

/// "Ngày này năm xưa": bài của chính mình đăng vào ngày hôm nay của các năm
/// trước. Chỉ đọc dữ liệu có sẵn (bài công khai và bài bạn bè/riêng tư của
/// mình), không ghi gì và không cần thay đổi luật Firestore.
///
/// Mỗi năm một truy vấn khoảng thời gian trên mỗi loại bài nên chỉ đọc đúng
/// những bài trùng ngày, không quét toàn bộ bài viết. Truy vấn cần chỉ mục
/// ghép (authorId + createdAt) cho `posts` và `friend_posts`: lần chạy đầu
/// nếu thiếu, thông báo lỗi trong cửa sổ Run có sẵn đường link để tạo.
class OnThisDayService {
  /// Nhìn lại tối đa bao nhiêu năm.
  static const maxYears = 5;

  static final _db = FirebaseFirestore.instance;

  static Future<List<Post>> _postsOnDay(
    String collection,
    String uid,
    DateTime start,
    DateTime end,
  ) async {
    final snap = await _db
        .collection(collection)
        .where('authorId', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map(Post.fromDoc).toList();
  }

  static Future<OnThisDayGroup?> _year(
    String uid,
    DateTime today,
    int yearsAgo,
  ) async {
    final year = today.year - yearsAgo;
    final start = DateTime(year, today.month, today.day);
    // 29/2 không có ở năm thường: DateTime tự nhảy sang tháng sau, bỏ qua
    if (start.month != today.month) return null;
    final end = DateTime(year, today.month, today.day + 1);

    final lists = await Future.wait([
      _postsOnDay('posts', uid, start, end),
      _postsOnDay('friend_posts', uid, start, end),
    ]);
    final posts = [...lists[0], ...lists[1]]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (posts.isEmpty) return null;
    return OnThisDayGroup(yearsAgo, start, posts);
  }

  /// Danh sách theo năm, gần nhất trước. Rỗng nếu chưa có bài nào.
  static Future<List<OnThisDayGroup>> load({DateTime? today}) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return const <OnThisDayGroup>[];
    final now = today ?? DateTime.now();

    final results = await Future.wait([
      for (var n = 1; n <= maxYears; n++) _year(me.uid, now, n),
    ]);
    return [for (final g in results) ?g];
  }
}
