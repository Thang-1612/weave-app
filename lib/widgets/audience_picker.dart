import 'package:flutter/material.dart';
import '../services/l10n.dart';
import 'audience_meta.dart';

// Giữ nguyên đường nhập cũ: nơi nào đã import audience_picker.dart vẫn dùng
// được audienceIcon / audienceLabel / audienceHint.
export 'audience_meta.dart' show audienceIcon, audienceLabel, audienceHint;

/// Ba mức đối tượng xem bài viết. (Bài có thêm lớp riêng cho bạn thân và nhóm
/// qua Weave Layers; xem layer_audience_picker.dart.)
const kAudiences = ['public', 'friends', 'me'];

/// Bảng chọn đối tượng. Trả về 'public', 'friends', 'me' hoặc null nếu đóng bảng.
Future<String?> showAudiencePicker(
    BuildContext context, {
      required String current,
      String? title,
    }) {
  return showAudienceTypeSheet(
    context,
    types: kAudiences,
    current: current,
    title: title ?? tr('Ai có thể xem bài viết?', 'Who can see this post?'),
  );
}
