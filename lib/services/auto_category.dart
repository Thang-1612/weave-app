import 'dart:typed_data';

import 'ai_classifier.dart';
import 'category_classifier.dart';
import '../models/space.dart';

class CategoryDecision {
  final String? spaceId;
  final bool confident;
  final String source; // ai, keyword

  const CategoryDecision(this.spaceId, this.confident, this.source);
}

/// Ghép các lớp nhận biết: AI trước (biết toàn bộ chủ đề), từ khóa làm dự
/// phòng khi AI không dùng được, cuối cùng nhờ người dùng chọn.
class AutoCategory {
  static Future<CategoryDecision> decide({
    required List<Map<String, dynamic>> blocks,
    Uint8List? imageBytes,
  }) async {
    final text = blocks
        .where((b) => b['type'] == 'text')
        .map((b) => (b['text'] as String? ?? '').trim())
        .where((t) => t.isNotEmpty)
        .join('\n');

    final links = blocks.where((b) => b['type'] == 'link').toList();
    final urls = links.map((b) => b['url'] as String? ?? '').toList();
    final linkTitles = links.map((b) => b['title'] as String? ?? '').join(' ');
    final fullText = '$text $linkTitles';

    // Lớp 1: AI hiểu cả chữ lẫn ảnh và biết toàn bộ danh sách chủ đề
    final ai = await AiClassifier.classify(
      text: fullText,
      imageBytes: imageBytes,
    );
    if (ai != null && ai != 'none' && findSpace(ai) != null) {
      return CategoryDecision(ai, true, 'ai');
    }

    // Lớp 2: từ khóa (dự phòng khi AI lỗi, quá thời gian hoặc không rõ)
    final guess = CategoryClassifier.guess(text: fullText, urls: urls);
    if (guess.confident) {
      return CategoryDecision(guess.spaceId, true, 'keyword');
    }

    // Không chắc chắn: trả về gợi ý yếu nhất (nếu có) để hỏi người dùng
    return CategoryDecision(guess.spaceId, false, 'keyword');
  }
}