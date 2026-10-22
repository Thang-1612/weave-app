import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_prefs.dart';

class ActivityService {
  static CollectionReference<Map<String, dynamic>>? _shares() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('shares');
  }

  /// Ghi lại việc chia sẻ một bài viết (mỗi bài một dòng, cập nhật thời gian).
  static Future<void> logShare(String postId) async {
    try {
      await _shares()?.doc(postId).set({
        'postId': postId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  loadShares() async {
    final col = _shares();
    if (col == null) return [];
    final snap =
    await col.orderBy('createdAt', descending: true).limit(100).get();
    return snap.docs;
  }

  static Future<void> removeShare(String postId) async {
    await _shares()?.doc(postId).delete();
  }

  /// Xuất dữ liệu cá nhân thành JSON (không gồm nội dung ảnh).
  static Future<String> exportMyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('msgNotSignedIn');
    final db = FirebaseFirestore.instance;
    final prefs = UserPrefs.instance;

    String iso(Object? v) => v is Timestamp ? v.toDate().toIso8601String() : '';

    final profileSnap = await db.collection('users').doc(user.uid).get();
    final profileRaw = Map<String, dynamic>.from(profileSnap.data() ?? {})
      ..remove('searchTokens');
    final profile = {
      for (final e in profileRaw.entries)
        e.key: e.value is Timestamp ? iso(e.value) : e.value,
    };

    final postsSnap = await db
        .collection('posts')
        .where('authorId', isEqualTo: user.uid)
        .get();
    final posts = [
      for (final d in postsSnap.docs)
        {
          'id': d.id,
          'spaceId': d.data()['spaceId'],
          'text': d.data()['text'],
          'createdAt': iso(d.data()['createdAt']),
          'reactions': d.data()['reactions'] ?? 0,
          'comments': d.data()['comments'] ?? 0,
          'imageCount': ((d.data()['blocks'] as List?) ?? const [])
              .where((b) => b is Map && b['type'] == 'image')
              .length,
        },
    ];

    final data = {
      'exportedAt': DateTime.now().toIso8601String(),
      'account': {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
      },
      'profile': profile,
      'posts': posts,
      'savedPostIds': prefs.savedIds,
      'favoriteUsers': prefs.favoriteUsers.toList(),
      'favoriteSpaces': prefs.favoriteSpaces.toList(),
      'mutedUsers': prefs.mutedUsers.toList(),
      'blockedUsers': prefs.blocked,
      'restrictedSpaces': prefs.restrictedSpaces.toList(),
      'language': prefs.language,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}