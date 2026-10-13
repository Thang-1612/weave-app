import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';

/// Một công thức bảng tin do người dùng tự đặt.
class FeedRecipe {
  final String id;
  final String name;
  final List<String> spaceIds; // rỗng = mọi chủ đề
  final int minBlocks; // 0 = không giới hạn
  final bool withUpdates; // chỉ bài sống (có cập nhật)
  final bool withImages; // chỉ bài có ảnh
  final int maxAgeDays; // 0 = không giới hạn; tính từ lần cập nhật gần nhất

  const FeedRecipe({
    required this.id,
    required this.name,
    this.spaceIds = const <String>[],
    this.minBlocks = 0,
    this.withUpdates = false,
    this.withImages = false,
    this.maxAgeDays = 0,
  });

  bool matches(Post p) {
    if (spaceIds.isNotEmpty && !spaceIds.contains(p.spaceId)) return false;
    if (minBlocks > 0 && p.blocks.length < minBlocks) return false;
    if (withUpdates && p.updateCount <= 0) return false;
    if (withImages && !p.blocks.any((b) => b['type'] == 'image')) return false;
    if (maxAgeDays > 0) {
      // Bài sống được coi là "mới" theo lần cập nhật gần nhất
      final last = p.lastUpdateAt != null && p.lastUpdateAt!.isAfter(p.createdAt)
          ? p.lastUpdateAt!
          : p.createdAt;
      if (DateTime.now().difference(last).inDays > maxAgeDays) return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'spaceIds': spaceIds,
    'minBlocks': minBlocks,
    'withUpdates': withUpdates,
    'withImages': withImages,
    'maxAgeDays': maxAgeDays,
  };

  factory FeedRecipe.fromMap(Map<String, dynamic> m) {
    return FeedRecipe(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? '',
      spaceIds: [
        for (final s in (m['spaceIds'] as List? ?? const [])) s.toString(),
      ],
      minBlocks: (m['minBlocks'] as num?)?.toInt() ?? 0,
      withUpdates: m['withUpdates'] as bool? ?? false,
      withImages: m['withImages'] as bool? ?? false,
      maxAgeDays: (m['maxAgeDays'] as num?)?.toInt() ?? 0,
    );
  }
}

class FeedRecipeState {
  final List<FeedRecipe> items;
  final String? activeId;
  const FeedRecipeState(this.items, this.activeId);

  FeedRecipe? get active {
    for (final r in items) {
      if (r.id == activeId) return r;
    }
    return null;
  }
}

class FeedRecipeService {
  static DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('private')
        .doc('feed_recipes');
  }

  static Future<FeedRecipeState> load() async {
    final ref = _doc();
    if (ref == null) return const FeedRecipeState([], null);
    final s = await ref.get();
    final d = s.data();
    if (d == null) return const FeedRecipeState([], null);
    final items = <FeedRecipe>[
      for (final m in (d['items'] as List? ?? const []))
        if (m is Map) FeedRecipe.fromMap(Map<String, dynamic>.from(m)),
    ];
    return FeedRecipeState(items, d['activeId'] as String?);
  }

  /// Lưu lỗi thì bỏ qua (công thức vẫn dùng được trong phiên hiện tại).
  static Future<void> save(FeedRecipeState s) async {
    try {
      await _doc()?.set({
        'items': s.items.map((e) => e.toMap()).toList(),
        'activeId': s.activeId,
      });
    } catch (_) {}
  }
}