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

/// Từ chiều rộng này trở lên: menu bên trái, nội dung cài đặt bên phải.
const double _kSettingsWideBreakpoint = 900;
const double _kSettingsMenuWidth = 320;

/// Một mục trong menu cài đặt.
/// - [page]: màn hình cài đặt. Desktop mở trong khung phải, mobile mở trang mới.
/// - [onTap]: hành động riêng (hộp thoại, mở màn hình đầy đủ...). Không chọn được
///   như một trang nên không được tô sáng.
class _Item {
  final String id;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget Function()? page;
  final VoidCallback? action;

  const _Item(
    this.id,
    this.icon,
    this.title, {
    this.subtitle,
    this.page,
    this.action,
  }) : assert(page != null || action != null);
}

class _Section {
  final String label;
  final List<_Item> items;
  const _Section(this.label, this.items);
}

class SettingsHubScreen extends StatefulWidget {
  const SettingsHubScreen({super.key});

  @override
  State<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends State<SettingsHubScreen> {
  String _query = '';
  String? _selectedId; // mục đang mở ở khung phải (desktop)

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

  List<_Section> _sections() {
    final prefs = UserPrefs.instance;
    return [
      _Section(tr('Tài khoản', 'Account'), [
        _Item(
          'edit_profile',
          Icons.person_outline,
          tr('Chỉnh sửa hồ sơ', 'Edit profile'),
          action: _editProfile,
        ),
        _Item(
          'password',
          Icons.password,
          tr('Đổi mật khẩu', 'Change password'),
          subtitle: tr('Gửi email đặt lại mật khẩu', 'Send a reset email'),
          action: () => confirmPasswordReset(context),
        ),
      ]),
      _Section(tr('Hoạt động của bạn', 'Your activity'), [
        _Item(
          'saved',
          Icons.bookmark_border,
          tr('Đã lưu', 'Saved'),
          subtitle: '${prefs.savedIds.length} ${tr('bài viết', 'posts')}',
          page: () => const SavedScreen(),
        ),
        _Item(
          'activity',
          Icons.history,
          tr('Lịch sử hoạt động tương tác', 'Interaction history'),
          subtitle: tr(
            'Cảm xúc, bình luận, chia sẻ',
            'Reactions, comments, shares',
          ),
          page: () => const ActivityScreen(),
        ),
        _Item(
          'favorites',
          Icons.star_border,
          tr('Yêu thích', 'Favorites'),
          subtitle: tr('Người và chủ đề ưu tiên', 'Priority people and topics'),
          page: () => const FavoritesScreen(),
        ),
      ]),
      _Section(tr('Cài đặt', 'Settings'), [
        _Item(
          'notifications',
          Icons.notifications_none,
          tr('Thông báo', 'Notifications'),
          page: () => const NotificationSettingsScreen(),
        ),
        _Item(
          'privacy',
          Icons.lock_outline,
          tr('Quyền riêng tư', 'Privacy'),
          subtitle: tr(
            'Tìm kiếm, lời mời, dữ liệu của bạn',
            'Search, requests, your data',
          ),
          page: () => const PrivacyScreen(),
        ),
        _Item(
          'blocked',
          Icons.block,
          tr('Đã chặn và tắt tiếng', 'Blocked and muted'),
          subtitle:
              '${prefs.blocked.length} ${tr('đã chặn', 'blocked')} · ${prefs.mutedUsers.length} ${tr('tắt tiếng', 'muted')}',
          page: () => const BlockedScreen(),
        ),
        _Item(
          'topics',
          Icons.tune,
          tr('Hạn chế chủ đề', 'Restrict topics'),
          subtitle: tr(
            'Ẩn chủ đề, đề xuất theo sở thích',
            'Hide topics, personalized feed',
          ),
          page: () => const CategorySettingsScreen(),
        ),
        _Item(
          'language',
          Icons.language,
          tr('Ngôn ngữ hiển thị', 'Display language'),
          subtitle: prefs.language == 'en' ? 'English' : 'Tiếng Việt',
          page: () => const LanguageScreen(),
        ),
        _Item(
          'time',
          Icons.timer_outlined,
          tr('Quản lý thời gian', 'Time management'),
          subtitle: tr(
            'Thống kê, giới hạn, nhắc nghỉ',
            'Stats, limit, break reminders',
          ),
          page: () => const TimeManagementScreen(),
        ),
      ]),
      _Section(tr('Bạn bè', 'People'), [
        _Item(
          'invite',
          Icons.group_add_outlined,
          tr('Theo dõi và mời bạn bè', 'Follow and invite friends'),
          page: () => const InviteScreen(),
        ),
      ]),
      _Section(tr('Hỗ trợ', 'Support'), [
        _Item(
          'help',
          Icons.help_outline,
          tr('Trợ giúp', 'Help'),
          page: () => const HelpScreen(),
        ),
        _Item(
          'about',
          Icons.info_outline,
          tr('Giới thiệu', 'About'),
          page: () => const AboutScreen(),
        ),
      ]),
    ];
  }

  /// Lọc theo ô tìm kiếm (bỏ dấu tiếng Việt); bỏ nhóm không còn mục nào.
  List<_Section> _filtered(List<_Section> all, String q) {
    if (q.isEmpty) return all;
    return [
      for (final s in all)
        if (s.items.any((i) => normalizeVi(i.title).contains(q)))
          _Section(
            s.label,
            s.items.where((i) => normalizeVi(i.title).contains(q)).toList(),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserPrefs.instance,
      builder: (context, _) {
        final q = normalizeVi(_query.trim());
        final all = _sections();
        final shown = _filtered(all, q);
        final wide =
            MediaQuery.sizeOf(context).width >= _kSettingsWideBreakpoint;
        return wide ? _buildWide(all, shown, q) : _buildNarrow(shown, q);
      },
    );
  }

  // ───────────── Hẹp (điện thoại): danh sách như cũ ─────────────
  Widget _buildNarrow(List<_Section> shown, String q) {
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        // Viền, bo góc 12 và màu focus lấy từ theme
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: tr('Tìm kiếm trong cài đặt', 'Search settings'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
      ),
    ];

    for (final s in shown) {
      children.add(SectionLabel(s.label));
      children.add(
        SettingsCard(
          children: [
            for (final i in s.items)
              SettingsTile(
                icon: i.icon,
                title: i.title,
                subtitle: i.subtitle,
                onTap: i.page != null ? () => _open(i.page!()) : i.action!,
              ),
          ],
        ),
      );
    }

    if (shown.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              tr('Không tìm thấy mục nào', 'No settings found'),
              style: const TextStyle(color: AppColors.textSecondary),
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
  }

  // ───────────── Rộng (desktop): menu trái | nội dung phải ─────────────
  Widget _buildWide(List<_Section> all, List<_Section> shown, String q) {
    final pages = [
      for (final s in all)
        for (final i in s.items)
          if (i.page != null) i,
    ];
    // Chưa chọn (hoặc mục đã chọn không còn) thì mở mục trang đầu tiên
    final selected = pages.firstWhere(
      (i) => i.id == _selectedId,
      orElse: () => pages.first,
    );

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: _kSettingsMenuWidth,
            // Material (không phải ColoredBox) để ListTile vẽ được màu mục chọn
            child: Material(
              color: AppColors.surface,
              child: Column(
                children: [
                  // Cao bằng AppBar của màn hình bên phải để hai bên thẳng hàng
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: tr('Quay lại', 'Back'),
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            Expanded(
                              child: Text(
                                tr(
                                  'Cài đặt và hoạt động',
                                  'Settings and activity',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: tr(
                          'Tìm kiếm trong cài đặt',
                          'Search settings',
                        ),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        for (final s in shown) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                              s.label.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          for (final i in s.items)
                            ListTile(
                              leading: Icon(i.icon),
                              title: Text(i.title),
                              subtitle: i.subtitle == null
                                  ? null
                                  : Text(
                                      i.subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              // Màu mục đang chọn lấy từ listTileTheme
                              selected: i.page != null && i.id == selected.id,
                              onTap: i.page != null
                                  ? () => setState(() => _selectedId = i.id)
                                  : i.action,
                            ),
                        ],
                        if (shown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                tr(
                                  'Không tìm thấy mục nào',
                                  'No settings found',
                                ),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        if (q.isEmpty) ...[
                          const Divider(height: 24),
                          ListTile(
                            leading: const Icon(
                              Icons.logout,
                              color: AppColors.danger,
                            ),
                            title: Text(
                              tr('Đăng xuất', 'Log out'),
                              style: const TextStyle(color: AppColors.danger),
                            ),
                            onTap: _logout,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // Navigator riêng: màn cài đặt con mở ngay trong khung phải,
          // nút quay lại của chúng vẫn hoạt động trong khung này.
          Expanded(
            child: Navigator(
              key: ValueKey(selected.id),
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => selected.page!()),
            ),
          ),
        ],
      ),
    );
  }
}
