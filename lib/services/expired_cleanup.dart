import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post.dart';
import 'trash_service.dart';

/// Dọn các bài tự hết hạn của chính người dùng: chuyển vào thùng rác (giữ
/// 30 ngày, khôi phục được). Không có Cloud Functions nên việc này chạy ở
/// phía app, một lần cho mỗi lần đăng nhập.
class ExpiredCleanup {
  static String? _doneFor; // uid đã dọn xong (hoặc đang dọn)

  /// Gọi từ AuthGate khi đã đăng nhập. Gọi nhiều lần cũng chỉ dọn một lần
  /// cho mỗi tài khoản; đổi tài khoản thì tài khoản mới được dọn.
  static Future<void> runOnce(String uid) async {
    if (_doneFor == uid) return;
    _doneFor = uid;
    try {
      // Chỉ lọc theo authorId rồi kiểm tra hạn trên máy, để không cần tạo
      // thêm chỉ mục Firestore.
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: uid)
          .get();
      for (final d in snap.docs) {
        final post = Post.fromDoc(d);
        if (!post.isExpired) continue;
        try {
          await TrashService.moveToTrash(post);
        } catch (_) {
          // Một bài lỗi thì bỏ qua, các bài khác vẫn được dọn
        }
      }
    } catch (_) {
      // Lỗi mạng hoặc quyền: cho phép thử lại ở lần đăng nhập sau
      _doneFor = null;
    }
  }
}