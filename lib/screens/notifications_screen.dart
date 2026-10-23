import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/interactions.dart';
import '../services/friend_service.dart';
import '../services/interaction_service.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/friend_button.dart';
import 'comments_screen.dart';
import 'feedback_screen.dart';
import 'user_profile_page.dart';

/// Gắn số thông báo chưa đọc lên một widget (dùng cho biểu tượng thư).
class UnreadBadge extends StatefulWidget {
  final Widget child;

  const UnreadBadge({super.key, required this.child});

  @override
  State<UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<UnreadBadge> {
  // Chỉ đếm các loại thông báo đang được bật trong Cài đặt
  late final Stream<int> _stream = NotificationService.watchMine().map(
    (list) => list
        .where((n) => !n.read && UserPrefs.instance.notifEnabled(n.type))
        .length,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,
      initialData: 0,
      builder: (context, snap) {
        final n = snap.data ?? 0;
        if (n <= 0) return widget.child;
        return Badge(label: Text(n > 99 ? '99+' : '$n'), child: widget.child);
      },
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Màu nền thông báo cột mốc: tông Teal (thành công) thay cho màu vàng ngoài bảng màu.
  static final _milestoneTile = AppColors.teal.withValues(alpha: 0.10);
  static final _milestoneAvatar = AppColors.teal.withValues(alpha: 0.20);

  late final Stream<List<AppNotification>> _stream =
      NotificationService.watchMine();
  late final Stream<List<Friendship>> _friendsStream =
      FriendService.watchMine();

  Future<void> _open(AppNotification n) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!n.read) {
      try {
        await NotificationService.markRead(n.id);
      } catch (_) {}
    }

    // Thông báo kết bạn: mở trang cá nhân của người đó
    if (n.type == 'friend_request' || n.type == 'friend_accepted') {
      if (n.fromUserId.isEmpty || !mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              UserProfilePage(userId: n.fromUserId, title: n.fromName),
        ),
      );
      return;
    }

    if (n.postId.isEmpty) return;
    try {
      final post = await PostService.getPost(n.postId);
      if (post == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              tr('Bài viết không còn tồn tại', 'This post no longer exists'),
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      // Thông báo góp ý mở màn Góp ý, các loại khác mở bình luận
      navigator.push(
        MaterialPageRoute(
          builder: (_) => n.type == 'feedback'
              ? FeedbackScreen(post: post)
              : CommentsScreen(post: post),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${tr('Không mở được', 'Could not open')}: $e')),
      );
    }
  }

  /// Lời mời kết bạn còn chờ: hiện nút chấp nhận / từ chối ngay trên thông báo.
  Widget? _trailing(AppNotification n, List<Friendship> fs, String me) {
    if (n.type != 'friend_request') return null;
    final status = FriendService.statusWith(fs, me, n.fromUserId);
    if (status != FriendStatus.incoming) return null;
    return FriendActionButton(
      uid: n.fromUserId,
      friendships: fs,
      compact: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${tr('Không tải được thông báo.', 'Could not load notifications.')}\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data!
            .where((n) => UserPrefs.instance.notifEnabled(n.type))
            .toList();
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mail_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      'Chưa có thông báo nào.\nKhi có người tương tác với bạn, thông báo sẽ hiện ở đây.',
                      'No notifications yet.\nWhen someone interacts with you, it will show up here.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        final hasUnread = items.any((n) => !n.read);
        final me = FirebaseAuth.instance.currentUser?.uid ?? '';

        return StreamBuilder<List<Friendship>>(
          stream: _friendsStream,
          builder: (context, fSnap) {
            final friendships = fSnap.data ?? const <Friendship>[];

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  children: [
                    if (hasUnread)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => NotificationService.markAllRead(),
                          child: Text(
                            tr('Đánh dấu đã đọc tất cả', 'Mark all as read'),
                          ),
                        ),
                      ),
                    for (final n in items) ...[
                      // ListTile cần Material ngay phía trên để hiện màu nền
                      // và hiệu ứng chạm: không bọc nó trong ColoredBox/Container.
                      ListTile(
                        tileColor: n.type == 'milestone'
                            ? _milestoneTile
                            : (n.read ? null : AppColors.soft),
                        leading: CircleAvatar(
                          backgroundColor: n.type == 'milestone'
                              ? _milestoneAvatar
                              : AppColors.soft,
                          child: Text(
                            n.icon,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(
                          n.message,
                          style: TextStyle(
                            fontWeight: n.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(formatTimeAgo(n.createdAt)),
                        trailing: _trailing(n, friendships, me),
                        onTap: () => _open(n),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
