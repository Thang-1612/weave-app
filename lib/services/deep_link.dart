import 'package:flutter/foundation.dart';

/// Đọc địa chỉ trang web lúc mở ứng dụng để mở thẳng một bài viết.
/// Liên kết có dạng: https://social-app-353f0.web.app/post/<mã bài viết>
class DeepLink {
  static String? _pendingPostId;

  /// Gọi một lần ở đầu main (chỉ có tác dụng trên web).
  static void captureInitial() {
    if (!kIsWeb) return;
    final seg = Uri.base.pathSegments.where((s) => s.isNotEmpty).toList();
    if (seg.length >= 2 && seg[0] == 'post') _pendingPostId = seg[1];
  }

  /// Lấy mã bài viết đang chờ mở (chỉ lấy được một lần).
  static String? takePostId() {
    final id = _pendingPostId;
    _pendingPostId = null;
    return id;
  }
}