import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/account_service.dart';
import '../../services/l10n.dart';
import '../../services/text_utils.dart';
import '../../services/user_prefs.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_widgets.dart';
import '../edit_profile_screen.dart';
import 'about_screen.dart';
import 'activity_screen.dart';
import 'blocked_screen.dart';
import 'category_settings_screen.dart';
import 'favorites_screen.dart';
import 'help_screen.dart';
import 'invite_screen.dart';
import 'language_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_screen.dart';
import 'saved_screen.dart';
import 'time_management_screen.dart';

class _Item {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _Item(this.icon, this.title, this.onTap, {this.subtitle});
}

class SettingsHubScreen extends StatefulWidget {
  const SettingsHubScreen({super.key});

  @override
  State<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends State<SettingsHubScreen> {
  String _query = '';

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _editProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final navigator = Navigator.of(context);
    final profile = await UserService.watchProfile(user.uid).first;
    if (!mounted) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: profile,
          fallbackName: displayNameOf(user),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(tr('Đăng xuất?', 'Log out?')),
        content: Text(
          tr(
            'Bạn có chắc muốn đăng xuất khỏi tài khoản này không?',
            'Are you sure you want to log out of this account?',
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
            child: Text(tr('Đăng xuất', 'Log out')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    UserPrefs.instance.bind(null);
    navigator.popUntil((r) => r.isFirst);
    await FirebaseAuth.instance.signOut();
  }

  Map<String, List<_Item>> _sections() {
    final prefs = UserPrefs.instance;
    return {
      tr('Tài khoản', 'Account'): [
        _Item(
          Icons.person_outline,
          tr('Chỉnh sửa hồ sơ', 'Edit profile'),
          _editProfile,
        ),
        _Item(
          Icons.password,
          tr('Đổi mật khẩu', 'Change password'),
              () => confirmPasswordReset(context),
          subtitle: tr('Gửi email đặt lại mật khẩu', 'Send a reset email'),
        ),
      ],
      tr('Hoạt động của bạn', 'Your activity'): [
        _Item(
          Icons.bookmark_border,
          tr('Đã lưu', 'Saved'),
              () => _open(const SavedScreen()),
          subtitle: '${prefs.savedIds.length} ${tr('bài viết', 'posts')}',
        ),
        _Item(
          Icons.history,
          tr('Lịch sử hoạt động tương tác', 'Interaction history'),
              () => _open(const ActivityScreen()),
          subtitle: tr(
            'Cảm xúc, bình luận, chia sẻ',
            'Reactions, comments, shares',
          ),
        ),
        _Item(
          Icons.star_border,
          tr('Yêu thích', 'Favorites'),
              () => _open(const FavoritesScreen()),
          subtitle: tr(
            'Người và chủ đề ưu tiên',
            'Priority people and topics',
          ),
        ),
      ],
      tr('Cài đặt', 'Settings'): [
        _Item(
          Icons.notifications_none,
          tr('Thông báo', 'Notifications'),
              () => _open(const NotificationSettingsScreen()),
        ),
        _Item(
          Icons.lock_outline,
          tr('Quyền riêng tư', 'Privacy'),
              () => _open(const PrivacyScreen()),
          subtitle: tr(
            'Tìm kiếm, lời mời, dữ liệu của bạn',
            'Search, requests, your data',
          ),
        ),
        _Item(
          Icons.block,
          tr('Đã chặn và tắt tiếng', 'Blocked and muted'),
              () => _open(const BlockedScreen()),
          subtitle:
          '${prefs.blocked.length} ${tr('đã chặn', 'blocked')} · ${prefs.mutedUsers.length} ${tr('tắt tiếng', 'muted')}',
        ),
        _Item(
          Icons.tune,
          tr('Hạn chế chủ đề', 'Restrict topics'),
              () => _open(const CategorySettingsScreen()),
          subtitle: tr(
            'Ẩn chủ đề, đề xuất theo sở thích',
            'Hide topics, personalized feed',
          ),
        ),
        _Item(
          Icons.language,
          tr('Ngôn ngữ hiển thị', 'Display language'),
              () => _open(const LanguageScreen()),
          subtitle: prefs.language == 'en' ? 'English' : 'Tiếng Việt',
        ),
        _Item(
          Icons.timer_outlined,
          tr('Quản lý thời gian', 'Time management'),
              () => _open(const TimeManagementScreen()),
          subtitle: tr(
            'Thống kê, giới hạn, nhắc nghỉ',
            'Stats, limit, break reminders',
          ),
        ),
      ],
      tr('Bạn bè', 'People'): [
        _Item(
          Icons.group_add_outlined,
          tr('Theo dõi và mời bạn bè', 'Follow and invite friends'),
              () => _open(const InviteScreen()),
        ),
      ],
      tr('Hỗ trợ', 'Support'): [
        _Item(
          Icons.help_outline,
          tr('Trợ giúp', 'Help'),
              () => _open(const HelpScreen()),
        ),
        _Item(
          Icons.info_outline,
          tr('Giới thiệu', 'About'),
              () => _open(const AboutScreen()),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserPrefs.instance,
      builder: (context, _) {
        final q = normalizeVi(_query.trim());
        final sections = _sections();

        final children = <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: tr('Tìm kiếm trong cài đặt', 'Search settings'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
        ];

        var any = false;
        sections.forEach((label, items) {
          final shown = q.isEmpty
              ? items
              : items.where((i) => normalizeVi(i.title).contains(q)).toList();
          if (shown.isEmpty) return;
          any = true;
          children.add(SectionLabel(label));
          children.add(
            SettingsCard(
              children: [
                for (final i in shown)
                  SettingsTile(
                    icon: i.icon,
                    title: i.title,
                    subtitle: i.subtitle,
                    onTap: i.onTap,
                  ),
              ],
            ),
          );
        });

        if (!any) {
          children.add(
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  tr('Không tìm thấy mục nào', 'No settings found'),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          );
        }

        if (q.isEmpty) {
          children.add(const SizedBox(height: 16));
          children.add(
            SettingsCard(
              children: [
                SettingsTile(
                  icon: Icons.logout,
                  title: tr('Đăng xuất', 'Log out'),
                  color: AppColors.danger,
                  onTap: _logout,
                ),
              ],
            ),
          );
        }

        return SettingsScaffold(
          title: tr('Cài đặt và hoạt động', 'Settings and activity'),
          body: settingsList(children),
        );
      },
    );
  }
}