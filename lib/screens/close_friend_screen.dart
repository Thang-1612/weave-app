import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/close_friend_service.dart';
import '../services/friend_service.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// Chọn ai trong số bạn bè của tôi là "bạn thân".
/// Chỉ người đã là bạn bè mới hiện ở đây.
class CloseFriendsScreen extends StatelessWidget {
  const CloseFriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(tr('Bạn thân', 'Close friends'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: StreamBuilder<List<Friendship>>(
            stream: FriendService.watchMine(),
            builder: (context, friendsSnap) {
              if (friendsSnap.hasError) {
                return Center(child: Text('${friendsSnap.error}'));
              }
              if (!friendsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final friendIds = [
                for (final f in friendsSnap.data!)
                  if (f.accepted && f.otherUid(me).isNotEmpty) f.otherUid(me),
              ];
              if (friendIds.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      tr(
                        'Bạn chưa có bạn bè nào. Hãy kết bạn trước, sau đó chọn bạn thân ở đây.',
                        'You have no friends yet. Add friends first, then choose close friends here.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              return StreamBuilder<Set<String>>(
                stream: CloseFriendService.watchIds(),
                builder: (context, closeSnap) {
                  final close = closeSnap.data ?? <String>{};
                  final count = friendIds.where(close.contains).length;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                        child: Text(
                          tr(
                            'Đã chọn $count người. Họ xem được các lớp có đối tượng "Bạn thân" của bạn. Họ không được thông báo.',
                            '$count selected. They can see your layers shared with "Close friends". They are not notified.',
                          ),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      for (final uid in friendIds)
                        _FriendTile(
                          key: ValueKey(uid),
                          uid: uid,
                          selected: close.contains(uid),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final String uid;
  final bool selected;

  const _FriendTile({super.key, required this.uid, required this.selected});

  // Bộ nhớ tạm uid -> tên để không tải lại mỗi lần danh sách cập nhật
  static final Map<String, String> _names = {};

  /// Tên hiển thị lấy từ users/{uid}. Mình chưa thấy cấu trúc hồ sơ của bạn
  /// nên thử vài tên trường phổ biến; chỉnh lại nếu hồ sơ dùng tên khác.
  static Future<String> _nameOf(String uid) async {
    final cached = _names[uid];
    if (cached != null) return cached;
    try {
      final s = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final d = s.data() ?? <String, dynamic>{};
      for (final key in const ['displayName', 'name', 'fullName', 'username']) {
        final v = d[key];
        if (v is String && v.trim().isNotEmpty) {
          _names[uid] = v.trim();
          return v.trim();
        }
      }
    } catch (_) {}
    return tr('Người dùng', 'User');
  }

  Future<void> _toggle(BuildContext context, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (value) {
        await CloseFriendService.add(uid);
      } else {
        await CloseFriendService.remove(uid);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Card lấy màu, viền và bo góc từ cardTheme (Card là Material nên
    // CheckboxListTile hiện đúng hiệu ứng chạm).
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<String>(
        future: _nameOf(uid),
        builder: (context, snap) {
          final name = snap.data ?? '…';
          final initial = name.isNotEmpty ? name.characters.first : '?';
          return CheckboxListTile(
            value: selected,
            onChanged: (v) => _toggle(context, v ?? false),
            controlAffinity: ListTileControlAffinity.trailing,
            secondary: CircleAvatar(
              backgroundColor: AppColors.soft,
              child: Text(
                initial.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: selected ? Text(tr('Bạn thân', 'Close friend')) : null,
          );
        },
      ),
    );
  }
}
