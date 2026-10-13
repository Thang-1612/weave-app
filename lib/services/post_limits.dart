import 'dart:convert';
import 'l10n.dart';

/// Firestore giới hạn 1 MiB mỗi tài liệu; chừa chỗ cho các trường khác.
const int kMaxPostBytes = 900 * 1000;
const int kMaxImagesPerPost = 4;

int blocksBytes(List<Map<String, dynamic>> blocks) =>
    utf8.encode(jsonEncode(blocks)).length;

/// Trả về null nếu hợp lệ, ngược lại là thông báo lỗi để hiển thị.
String? validateBlocks(List<Map<String, dynamic>> blocks) {
  final images = blocks.where((b) => b['type'] == 'image').length;
  if (images > kMaxImagesPerPost) {
    return tr(
      'Mỗi bài chỉ đăng tối đa $kMaxImagesPerPost ảnh',
      'A post can have at most $kMaxImagesPerPost images',
    );
  }
  if (blocksBytes(blocks) > kMaxPostBytes) {
    return tr(
      'Bài viết quá nặng. Hãy bớt ảnh hoặc chọn ảnh nhỏ hơn',
      'This post is too large. Remove some images or pick smaller ones',
    );
  }
  return null;
}