import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// weave_activities/{activityId}/moments/{momentId}
///
/// Một khoảnh khắc chia sẻ trong hoạt động: ảnh (base64 đã nén) và/hoặc
/// lời ghi chú. Khoảnh khắc ở lại hoạt động khi tác giả rời đi.
class WeaveMoment {
  final String id;
  final String authorId;
  final String caption;
  final String? imageB64;
  final DateTime createdAt;

  const WeaveMoment({
    required this.id,
    required this.authorId,
    required this.caption,
    required this.createdAt,
    this.imageB64,
  });

  Uint8List? get imageBytes {
    final b = imageB64;
    if (b == null || b.isEmpty) return null;
    try {
      return base64Decode(b);
    } catch (_) {
      return null;
    }
  }

  factory WeaveMoment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return WeaveMoment(
      id: doc.id,
      authorId: (d['authorId'] ?? '') as String,
      caption: (d['caption'] ?? '') as String,
      imageB64: d['image'] as String?,
      // createdAt có thể null trong lúc serverTimestamp chưa ghi xong
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}