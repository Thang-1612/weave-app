class UserProfile {
  final String uid;
  final String name; // họ tên đầy đủ
  final String ho;
  final String ten;
  final String bio;

  /// Cho phép người khác tìm thấy qua tìm kiếm và gợi ý kết bạn.
  final bool discoverable;

  /// Cho phép người khác gửi lời mời kết bạn.
  final bool allowFriendRequests;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.ho,
    required this.ten,
    required this.bio,
    this.discoverable = true,
    this.allowFriendRequests = true,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> d) {
    return UserProfile(
      uid: uid,
      name: (d['name'] as String? ?? '').trim(),
      ho: (d['ho'] as String? ?? '').trim(),
      ten: (d['ten'] as String? ?? '').trim(),
      bio: (d['bio'] as String? ?? '').trim(),
      discoverable: d['discoverable'] as bool? ?? true,
      allowFriendRequests: d['allowFriendRequests'] as bool? ?? true,
    );
  }
}

List<String> _words(String full) =>
    full.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Họ = tất cả các từ trừ từ cuối. Ví dụ "Nguyễn Văn An" -> "Nguyễn Văn"
String hoOf(String full) {
  final w = _words(full);
  return w.length <= 1 ? '' : w.sublist(0, w.length - 1).join(' ');
}

/// Tên = từ cuối. Ví dụ "Nguyễn Văn An" -> "An"
String tenOf(String full) {
  final w = _words(full);
  return w.isEmpty ? '' : w.last;
}