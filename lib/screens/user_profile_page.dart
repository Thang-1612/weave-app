import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/mutual_friends_row.dart';
import 'constellation_screen.dart';
import 'contribution_screen.dart';
import 'on_this_day_screen.dart';
import 'profile_screen.dart';

/// Trang cá nhân của một người dùng khác, có menu yêu thích, tắt tiếng, chặn.
class UserProfilePage extends StatelessWidget {
  final String userId;
  final String title;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.title,
  });

  Future<void> _block(BuildContext context) async {
    final navigator = Navigator.of(context);
    final name = title.isEmpty ? tr('người này', 'this person') : title;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WeaveRadius.card),
        ),
        title: Text(tr('Chặn $name?', 'Block $name?')),
        content: Text(
          tr(
            'Bạn sẽ không thấy bài viết và bình luận của họ, và hai bạn không còn là bạn bè. Họ sẽ không được thông báo.',
            'You will not see their posts and comments, and you will stop being friends. They will not be notified.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Chặn', 'Block')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await UserPrefs.instance.block(userId, title);
    navigator.pop();
  }

  void _openContribution(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContributionScreen(userId: userId, name: title),
      ),
    );
  }

  void _openOnThisDay(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnThisDayScreen()),
    );
  }

  void _openConstellation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConstellationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = userId == FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          // Bản đồ kết nối và Ngày này năm xưa chỉ có ý nghĩa với chính mình
          if (isMe)
            IconButton(
              icon: const Icon(Icons.hub_outlined),
              tooltip: tr('Bản đồ kết nối', 'Connection map'),
              onPressed: () => _openConstellation(context),
            ),
          if (isMe)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: tr('Ngày này năm xưa', 'On this day'),
              onPressed: () => _openOnThisDay(context),
            ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: tr('Dấu vết đóng góp', 'Contribution trail'),
            onPressed: () => _openContribution(context),
          ),
          if (!isMe)
            ListenableBuilder(
              listenable: UserPrefs.instance,
              builder: (context, _) {
                final prefs = UserPrefs.instance;
                final fav = prefs.isFavoriteUser(userId);
                final muted = prefs.mutedUsers.contains(userId);
                return PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'fav') prefs.setFavoriteUser(userId, !fav);
                    if (v == 'mute') prefs.setMuted(userId, !muted);
                    if (v == 'block') _block(context);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'fav',
                      child: Text(
                        fav
                            ? tr('Bỏ yêu thích', 'Remove from favorites')
                            : tr('Thêm vào yêu thích', 'Add to favorites'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'mute',
                      child: Text(
                        muted
                            ? tr('Bỏ tắt tiếng', 'Unmute')
                            : tr('Tắt tiếng', 'Mute'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'block',
                      child: Text(
                        tr('Chặn', 'Block'),
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
      body: isMe
          ? ProfileScreen(userId: userId)
          : Column(
              children: [
                MutualFriendsRow(otherUid: userId),
                Expanded(child: ProfileScreen(userId: userId)),
              ],
            ),
    );
  }
}