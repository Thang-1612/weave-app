import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import 'dart:async';

class CapsuleService {
  static final _col = FirebaseFirestore.instance.collection('capsules');

  static String fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Danh sách bạn bè đã chấp nhận (chụp lại tại thời điểm niêm phong).
  static Future<List<String>> _friendIds(String me) async {
    final snap = await FirebaseFirestore.instance
        .collection('friendships')
        .where('users', arrayContains: me)
        .get();
    final out = <String>[];
    for (final d in snap.docs) {
      final data = d.data();
      if (data['status'] != 'accepted') continue;
      for (final u in List<String>.from(data['users'] as List)) {
        if (u != me) out.add(u);
      }
    }
    return out.take(500).toList();
  }
  /// Luồng hộp đã mở (của mình và gửi cho mình) để trộn vào bảng tin.
  /// Dùng snapshots nên hộp bị xóa biến mất ngay. Mỗi 5 phút nghe lại với mốc
  /// thời gian mới để hộp vừa tới hạn tự hiện, không cần mở lại app.
  static Stream<List<Post>> watchOpened() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const <Post>[]);

    late StreamController<List<Post>> controller;
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    Timer? timer;
    var forMe = <Post>[];
    var fromMe = <Post>[];

    void emit() {
      if (controller.isClosed) return;
      final byId = <String, Post>{
        for (final p in [...forMe, ...fromMe]) p.id: p,
      };
      controller.add(byId.values.toList());
    }

    void listen() {
      for (final s in subs) {
        s.cancel();
      }
      subs.clear();
      final safeNow = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 2)));

      subs.add(_col
          .where('audience', arrayContains: uid)
          .where('openAt', isLessThanOrEqualTo: safeNow)
          .orderBy('openAt', descending: true)
          .limit(20)
          .snapshots()
          .listen((s) {
        forMe = s.docs.map(Post.fromDoc).toList();
        emit();
      }, onError: (_) {
        forMe = <Post>[]; // lỗi thì bảng tin vẫn chạy bình thường
        emit();
      }));

      subs.add(_col
          .where('authorId', isEqualTo: uid)
          .where('openAt', isLessThanOrEqualTo: safeNow)
          .orderBy('openAt', descending: true)
          .limit(20)
          .snapshots()
          .listen((s) {
        fromMe = s.docs.map(Post.fromDoc).toList();
        emit();
      }, onError: (_) {
        fromMe = <Post>[];
        emit();
      }));
    }

    controller = StreamController<List<Post>>(
      onListen: () {
        listen();
        timer = Timer.periodic(const Duration(minutes: 5), (_) => listen());
      },
      onCancel: () {
        timer?.cancel();
        for (final s in subs) {
          s.cancel();
        }
      },
    );
    return controller.stream;
  }

  static Future<void> create({
    required String spaceId,
    required List<Map<String, dynamic>> blocks,
    required DateTime openAt,
    required String visibility, // 'friends' hoặc 'me'
    String spaceSource = 'user',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = user.displayName?.trim() ?? '';
    final firstText = blocks
        .firstWhere((b) => b['type'] == 'text', orElse: () => {'text': ''})['text']
    as String;
    await _col.add({
      'authorId': user.uid,
      'authorName': name.isNotEmpty ? name : (user.email ?? 'Người dùng'),
      'spaceId': spaceId,
      'spaceSource': spaceSource,
      'text': firstText,
      'blocks': blocks,
      'reactions': 0,
      'comments': 0,
      'reactionSummary': <String, dynamic>{},
      'createdAt': Timestamp.now(),
      'openAt': Timestamp.fromDate(openAt),
      'visibility': visibility,
      'audience': visibility == 'friends' ? await _friendIds(user.uid) : <String>[],
    });
  }

  /// Hộp người khác gửi cho mình và đã tới hạn mở.
  /// Lùi 2 phút so với giờ máy để không lệch giờ máy chủ.
  static Future<List<Post>> openedForMe() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final safeNow = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 2)));
    final s = await _col
        .where('audience', arrayContains: uid)
        .where('openAt', isLessThanOrEqualTo: safeNow)
        .orderBy('openAt', descending: true)
        .limit(30)
        .get();
    return s.docs.map(Post.fromDoc).toList();
  }

  /// Hộp do mình niêm phong (cả đã mở lẫn chưa mở).
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> mine() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final s = await _col
        .where('authorId', isEqualTo: uid)
        .orderBy('openAt', descending: true)
        .limit(50)
        .get();
    return s.docs;
  }

  static Future<void> delete(String id) => _col.doc(id).delete();
}