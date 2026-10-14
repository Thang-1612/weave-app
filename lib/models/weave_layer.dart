import 'package:cloud_firestore/cloud_firestore.dart';

/// Đối tượng xem của một lớp.
/// type: 'public' | 'friends' | 'close' (bạn thân) | 'group' (nhóm riêng) | 'me'
class LayerAudience {
  static const kPublic = 'public';
  static const kFriends = 'friends';
  static const kClose = 'close';
  static const kGroup = 'group';
  static const kMe = 'me';
  static const kAll = [kPublic, kFriends, kClose, kGroup, kMe];

  final String type;

  /// Chỉ dùng khi type == 'group'.
  final String? groupId;

  const LayerAudience(this.type, {this.groupId});

  bool get isGroup => type == kGroup;

  @override
  bool operator ==(Object other) =>
      other is LayerAudience && other.type == type && other.groupId == groupId;

  @override
  int get hashCode => Object.hash(type, groupId);
}

/// Thông tin tóm tắt của lớp, lưu trong mảng `layers` của tài liệu bài đăng.
/// Cho client biết bài có những lớp nào mà không cần đọc nội dung lớp.
class LayerMeta {
  final String id;
  final String name;
  final String audienceType;
  final String? groupId;
  final int order;

  const LayerMeta({
    required this.id,
    required this.name,
    required this.audienceType,
    this.groupId,
    required this.order,
  });

  LayerAudience get audience => LayerAudience(audienceType, groupId: groupId);

  LayerMeta copyWith({String? name, LayerAudience? audience, int? order}) =>
      LayerMeta(
        id: id,
        name: name ?? this.name,
        audienceType: audience?.type ?? audienceType,
        groupId: audience != null ? audience.groupId : groupId,
        order: order ?? this.order,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'audienceType': audienceType,
    'audienceGroupId': groupId ?? '',
    'order': order,
  };

  factory LayerMeta.fromMap(Map m) {
    final g = m['audienceGroupId'];
    return LayerMeta(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? '',
      audienceType: m['audienceType'] as String? ?? LayerAudience.kMe,
      groupId: (g is String && g.isNotEmpty) ? g : null,
      order: (m['order'] as num?)?.toInt() ?? 0,
    );
  }

  /// Đọc mảng `layers` từ dữ liệu tài liệu bài đăng, đã sắp theo order.
  static List<LayerMeta> listFrom(Map<String, dynamic>? postData) {
    final raw = postData?['layers'];
    final out = <LayerMeta>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) out.add(LayerMeta.fromMap(e));
      }
    }
    out.sort((a, b) => a.order.compareTo(b.order));
    return out;
  }
}

/// Một lớp đầy đủ: lưu ở `{post.ref}/layers/{layerId}`.
class WeaveLayer {
  final String id;
  final String postId;
  final String authorId;
  final String name;
  final LayerAudience audience;

  /// Cùng định dạng với Post.blocks (text, image, link, emoji) nên dùng
  /// lại được PostBlocks.
  final List<Map<String, dynamic>> blocks;
  final int order;
  final bool commentsEnabled;
  final int comments;
  final DateTime createdAt;

  const WeaveLayer({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.name,
    required this.audience,
    required this.blocks,
    required this.order,
    required this.commentsEnabled,
    required this.comments,
    required this.createdAt,
  });

  factory WeaveLayer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final blocks = <Map<String, dynamic>>[];
    final rawBlocks = d['blocks'];
    if (rawBlocks is List) {
      for (final b in rawBlocks) {
        if (b is Map) blocks.add(Map<String, dynamic>.from(b));
      }
    }
    final g = d['audienceGroupId'];
    final ts = d['createdAt'];
    return WeaveLayer(
      id: doc.id,
      postId: doc.reference.parent.parent?.id ?? '',
      authorId: d['authorId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      audience: LayerAudience(
        d['audienceType'] as String? ?? LayerAudience.kMe,
        groupId: (g is String && g.isNotEmpty) ? g : null,
      ),
      blocks: blocks,
      order: (d['order'] as num?)?.toInt() ?? 0,
      commentsEnabled: d['commentsEnabled'] != false,
      comments: (d['comments'] as num?)?.toInt() ?? 0,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}