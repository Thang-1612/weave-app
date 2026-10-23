import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/weave_layer.dart';
import 'layer_access.dart';

typedef PostRef = DocumentReference<Map<String, dynamic>>;

/// Quản lý các lớp của bài đăng. Truyền `post.ref` làm [postRef].
///
/// Mỗi thay đổi ghi đồng thời lớp (`{post}/layers/{id}`) và mảng tóm tắt
/// `layers` trong bài, trong một transaction, để hai nơi không lệch nhau.
class LayerService {
  LayerService._();

  static final _db = FirebaseFirestore.instance;

  static List<Map<String, dynamic>> _metaMaps(List<LayerMeta> metas) => [
    for (final m in metas) m.toMap(),
  ];

  /// Thêm một lớp mới. Trả về id lớp.
  static Future<String> addLayer(
    PostRef postRef, {
    required String authorId,
    required String name,
    required LayerAudience audience,
    List<Map<String, dynamic>> blocks = const [],
    bool commentsEnabled = true,
  }) async {
    final layerRef = postRef.collection('layers').doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      final metas = LayerMeta.listFrom(snap.data());
      final meta = LayerMeta(
        id: layerRef.id,
        name: name,
        audienceType: audience.type,
        groupId: audience.groupId,
        order: metas.length,
      );
      tx.set(layerRef, {
        'authorId': authorId,
        'name': name,
        'audienceType': audience.type,
        'audienceGroupId': audience.groupId ?? '',
        'blocks': blocks,
        'order': meta.order,
        'commentsEnabled': commentsEnabled,
        'comments': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(postRef, {
        'isWeave': true,
        'layers': _metaMaps([...metas, meta]),
      });
    });
    return layerRef.id;
  }

  /// Đổi quyền xem của một lớp, KHÔNG đăng lại nội dung.
  static Future<void> setAudience(
    PostRef postRef,
    String layerId,
    LayerAudience audience,
  ) => _edit(postRef, layerId, {
    'audienceType': audience.type,
    'audienceGroupId': audience.groupId ?? '',
  }, (m) => m.copyWith(audience: audience));

  static Future<void> rename(PostRef postRef, String layerId, String name) =>
      _edit(postRef, layerId, {'name': name}, (m) => m.copyWith(name: name));

  static Future<void> setBlocks(
    PostRef postRef,
    String layerId,
    List<Map<String, dynamic>> blocks,
  ) => postRef.collection('layers').doc(layerId).update({
    'blocks': blocks,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  static Future<void> setCommentsEnabled(
    PostRef postRef,
    String layerId,
    bool enabled,
  ) => postRef.collection('layers').doc(layerId).update({
    'commentsEnabled': enabled,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Xóa lớp. Lưu ý: bình luận con của lớp (nếu có) không tự xóa theo,
  /// cần dọn bằng Cloud Function hoặc xóa tay trước khi gọi.
  static Future<void> deleteLayer(PostRef postRef, String layerId) async {
    final layerRef = postRef.collection('layers').doc(layerId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      final metas = LayerMeta.listFrom(snap.data())
          .where((m) => m.id != layerId)
          .toList();
      final reindexed = [
        for (var i = 0; i < metas.length; i++) metas[i].copyWith(order: i),
      ];
      tx.delete(layerRef);
      for (final m in reindexed) {
        tx.update(postRef.collection('layers').doc(m.id), {'order': m.order});
      }
      tx.update(postRef, {'layers': _metaMaps(reindexed)});
    });
  }

  /// Sắp xếp lại theo danh sách id mới.
  static Future<void> reorder(PostRef postRef, List<String> orderedIds) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      final byId = {for (final m in LayerMeta.listFrom(snap.data())) m.id: m};
      final next = <LayerMeta>[];
      for (final id in orderedIds) {
        final m = byId[id];
        if (m != null) next.add(m.copyWith(order: next.length));
      }
      for (final m in next) {
        tx.update(postRef.collection('layers').doc(m.id), {'order': m.order});
      }
      tx.update(postRef, {'layers': _metaMaps(next)});
    });
  }

  /// Tải các lớp người xem được phép thấy.
  ///
  /// [metas] lấy từ `LayerMeta.listFrom(...)` hoặc `post.layerMetas`.
  /// Mỗi lớp được `get` riêng; lớp bị rules từ chối sẽ bị bỏ qua.
  static Future<List<WeaveLayer>> fetchVisible(
    PostRef postRef,
    List<LayerMeta> metas,
    LayerAccess access,
  ) async {
    final allowed = metas.where(access.canViewMeta);
    final results = await Future.wait(
      allowed.map((m) async {
        try {
          final d = await postRef.collection('layers').doc(m.id).get();
          return d.exists ? WeaveLayer.fromDoc(d) : null;
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') return null;
          rethrow;
        }
      }),
    );
    return results.whereType<WeaveLayer>().toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Các lớp có tồn tại nhưng người xem chưa đủ quyền (dùng cho gợi ý
  /// "còn nội dung dành cho bạn thân"). Bỏ qua nếu không muốn lộ sự tồn tại.
  static List<LayerMeta> lockedMetas(
    List<LayerMeta> metas,
    LayerAccess access,
  ) => metas.where((m) => !access.canViewMeta(m)).toList();

  static Future<void> _edit(
    PostRef postRef,
    String layerId,
    Map<String, dynamic> layerChanges,
    LayerMeta Function(LayerMeta) change,
  ) async {
    final layerRef = postRef.collection('layers').doc(layerId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      final metas = [
        for (final m in LayerMeta.listFrom(snap.data()))
          m.id == layerId ? change(m) : m,
      ];
      tx.update(layerRef, {
        ...layerChanges,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(postRef, {'layers': _metaMaps(metas)});
    });
  }
}
