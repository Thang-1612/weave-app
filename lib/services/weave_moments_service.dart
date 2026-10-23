import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/weave_moment.dart';
import 'l10n.dart';

/// weave_activities/{activityId}/moments/{momentId} -> WeaveMoment
class WeaveMomentService {
  WeaveMomentService._();

  static const maxCaption = 500;

  static CollectionReference<Map<String, dynamic>> _col(String activityId) =>
      FirebaseFirestore.instance
          .collection('weave_activities')
          .doc(activityId)
          .collection('moments');

  static String get _me {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('msgNotSignedIn');
    return uid;
  }

  /// Mới nhất trước. Sắp xếp phía client để khỏi tạo chỉ mục.
  static Stream<List<WeaveMoment>> watch(String activityId) =>
      _col(activityId).snapshots().map((s) {
        final list = s.docs.map(WeaveMoment.fromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  /// [imageBytes] phải là ảnh đã nén (compressImage).
  static Future<void> add(
    String activityId, {
    String caption = '',
    Uint8List? imageBytes,
  }) async {
    final text = caption.trim();
    if (text.isEmpty && imageBytes == null) {
      throw Exception(
        tr(
          'Hãy thêm ảnh hoặc vài dòng ghi chú.',
          'Add a photo or a short note.',
        ),
      );
    }
    if (text.length > maxCaption) {
      throw Exception(
        tr(
          'Ghi chú tối đa $maxCaption ký tự.',
          'Notes are limited to $maxCaption characters.',
        ),
      );
    }
    await _col(activityId).add({
      'authorId': _me,
      'caption': text,
      if (imageBytes != null) 'image': base64Encode(imageBytes),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String activityId, String momentId) =>
      _col(activityId).doc(momentId).delete();
}
