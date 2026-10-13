import 'user_prefs.dart';

/// Chọn chuỗi theo ngôn ngữ đang dùng: tr('Tiếng Việt', 'English').
String tr(String vi, String en) =>
    UserPrefs.instance.language == 'en' ? en : vi;

/// Tên chủ đề theo ngôn ngữ đang dùng.
String spaceName(String id, String vi) {
  const en = {
    'study': 'Study',
    'cooking': 'Cooking',
    'travel': 'Travel',
    'maker': 'Maker',
  };
  return UserPrefs.instance.language == 'en' ? (en[id] ?? vi) : vi;
}
/// Nhãn hiển thị của lý do báo cáo (giá trị lưu trên Firestore giữ nguyên).
String reportReasonLabel(String vi) {
  const en = {
    'Spam hoặc quảng cáo': 'Spam or advertising',
    'Quấy rối hoặc ngôn từ thù ghét': 'Harassment or hate speech',
    'Thông tin sai lệch': 'Misinformation',
    'Nội dung không phù hợp': 'Inappropriate content',
    'Lý do khác': 'Other reason',
  };
  return UserPrefs.instance.language == 'en' ? (en[vi] ?? vi) : vi;
}
// Thông báo dùng chung cho lớp dữ liệu (hiện trong các hộp báo lỗi).
String get msgNotSignedIn => tr('Bạn chưa đăng nhập', 'You are not signed in');
String get msgPostGone =>
    tr('Bài viết không còn tồn tại', 'This post no longer exists');
String get msgCommentGone =>
    tr('Bình luận không còn tồn tại', 'This comment no longer exists');
String get msgCommentEmpty => tr('Bình luận đang trống', 'The comment is empty');
String get msgNoFriendRequests => tr(
  'Người này hiện không nhận lời mời kết bạn',
  'This person is not accepting friend requests right now',
);
String get msgUser => tr('Người dùng', 'User');