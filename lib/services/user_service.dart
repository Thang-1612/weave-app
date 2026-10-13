import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import 'post_service.dart';
import 'text_utils.dart';
import 'user_prefs.dart';
import 'l10n.dart';

class UserService {
  static final _users = FirebaseFirestore.instance.collection('users');

  static Stream<UserProfile?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map(
          (s) => s.exists ? UserProfile.fromMap(uid, s.data()!) : null,
    );
  }

  /// Tạo hồ sơ nếu chưa có; bổ sung tên và dữ liệu tìm kiếm nếu còn thiếu.
  /// An toàn khi gọi nhiều lần.
  static Future<void> ensureProfile(User user) async {
    final ref = _users.doc(user.uid);
    final authName = user.displayName?.trim() ?? '';

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'ho': hoOf(authName),
          'ten': tenOf(authName),
          'name': authName,
          'searchTokens': searchTokensOf(authName),
          'bio': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final data = snap.data() ?? <String, dynamic>{};
      final current = (data['name'] as String? ?? '').trim();
      final updates = <String, dynamic>{};
      if (current.isEmpty && authName.isNotEmpty) {
        updates['ho'] = hoOf(authName);
        updates['ten'] = tenOf(authName);
        updates['name'] = authName;
        updates['searchTokens'] = searchTokensOf(authName);
      } else if (current.isNotEmpty && data['searchTokens'] == null) {
        updates['searchTokens'] = searchTokensOf(current);
      }
      if (updates.isNotEmpty) tx.update(ref, updates);
    });
  }

  /// Lưu hồ sơ của tài khoản đang đăng nhập.
  static Future<void> saveProfile({
    required String ho,
    required String ten,
    String bio = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(msgNotSignedIn);

    final name = '${ho.trim()} ${ten.trim()}'.trim();
    await _users.doc(user.uid).set({
      'ho': ho.trim(),
      'ten': ten.trim(),
      'name': name,
      'searchTokens': searchTokensOf(name),
      'bio': bio.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await user.updateDisplayName(name);
    await user.reload();
    // Cập nhật tên trên các bài viết cũ
    await PostService.updateAuthorName(user.uid, name);
  }

  /// Tìm người dùng theo tên (không phân biệt dấu, hoa thường).
  static Future<List<UserProfile>> searchUsers(String query) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final words = normalizeVi(query)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return [];

    final first =
    words.first.length > 20 ? words.first.substring(0, 20) : words.first;
    final snap = await _users
        .where('searchTokens', arrayContains: first)
        .limit(30)
        .get();

    final results = <UserProfile>[];
    for (final doc in snap.docs) {
      if (doc.id == me) continue;
      final p = UserProfile.fromMap(doc.id, doc.data());
      if (p.name.isEmpty || !p.discoverable) continue;
      if (UserPrefs.instance.isBlocked(doc.id)) continue;
      final tokens = normalizeVi(p.name).split(RegExp(r'\s+'));
      final ok = words.every((w) => tokens.any((t) => t.startsWith(w)));
      if (ok) results.add(p);
    }
    return results;
  }
}