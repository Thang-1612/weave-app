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

  /// Sở thích (tag đã chuẩn hóa, tối đa 10).
  final List<String> interests;

  /// Mục tiêu / dự án đang làm (tag đã chuẩn hóa, tối đa 10).
  final List<String> goalTags;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.ho,
    required this.ten,
    required this.bio,
    this.discoverable = true,
    this.allowFriendRequests = true,
    this.interests = const [],
    this.goalTags = const [],
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
      interests: List<String>.from(d['interests'] as List? ?? const []),
      goalTags: List<String>.from(d['goalTags'] as List? ?? const []),
    );
  }

  /// Tên ngắn để hiển thị trên bản đồ.
  String get shortName => ten.isNotEmpty ? ten : name;
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

/// Chuẩn hóa một tag: bỏ dấu #, chữ thường, gộp khoảng trắng, tối đa 24 ký tự.
String normalizeTag(String raw) {
  var t = raw.trim().toLowerCase().replaceAll(RegExp(r'^#+'), '');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > 24 ? t.substring(0, 24).trim() : t;
}

/// Chuẩn hóa danh sách tag: bỏ trùng, bỏ rỗng, giới hạn [max] tag.
List<String> normalizeTags(Iterable<String> raw, {int max = 10}) {
  final out = <String>[];
  for (final r in raw) {
    final t = normalizeTag(r);
    if (t.isEmpty || out.contains(t)) continue;
    out.add(t);
    if (out.length >= max) break;
  }
  return out;
}
