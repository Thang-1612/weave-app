import '../../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_profile.dart';
import '../../services/activity_service.dart';
import '../../services/l10n.dart';
import '../../services/user_prefs.dart';
import '../../services/user_service.dart';
import '../../widgets/settings_widgets.dart';
import 'blocked_screen.dart';
import 'category_settings_screen.dart';

/// Gửi email đặt lại mật khẩu cho tài khoản đang đăng nhập (có hỏi xác nhận).
Future<void> confirmPasswordReset(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final email = FirebaseAuth.instance.currentUser?.email;
  if (email == null) return;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(tr('Đổi mật khẩu', 'Change password')),
      content: Text(
        tr(
          'Gửi email đặt lại mật khẩu tới $email?',
          'Send a password reset email to $email?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(tr('Hủy', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(tr('Gửi email', 'Send email')),
        ),
      ],
    ),
  );
  if (ok != true) return;

  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'Đã gửi email. Hãy kiểm tra hộp thư (cả thư rác).',
            'Email sent. Check your inbox (and spam).',
          ),
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late final Stream<UserProfile?> _profile = _uid == null
      ? Stream.value(null)
      : UserService.watchProfile(_uid!);
  bool _exporting = false;

  Future<void> _setPublic(String field, bool value) async {
    final uid = _uid;
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({field: value}, SetOptions(merge: true));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final json = await ActivityService.exportMyData();
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(tr('Đã sao chép dữ liệu', 'Data copied')),
          content: Text(
            tr(
              'Dữ liệu của bạn (${json.length} ký tự, định dạng JSON) đã nằm trong bộ nhớ tạm. Hãy dán vào một tệp văn bản để lưu lại. Bản sao không gồm nội dung ảnh.',
              'Your data (${json.length} characters, JSON) is now on the clipboard. Paste it into a text file to keep it. The copy does not include image content.',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Quyền riêng tư', 'Privacy'),
      body: StreamBuilder<UserProfile?>(
        stream: _profile,
        builder: (context, snap) {
          final p = snap.data;
          final discoverable = p?.discoverable ?? true;
          final allowRequests = p?.allowFriendRequests ?? true;

          return ListenableBuilder(
            listenable: UserPrefs.instance,
            builder: (context, _) {
              final prefs = UserPrefs.instance;
              return settingsList([
                SectionLabel(tr('Ai có thể tìm thấy bạn', 'Who can find you')),
                SettingsCard(
                  children: [
                    SettingsTile.toggle(
                      icon: Icons.person_search_outlined,
                      title: tr(
                        'Cho phép người khác tìm thấy tôi',
                        'Let others find me',
                      ),
                      subtitle: tr(
                        'Hiện trong tìm kiếm và gợi ý kết bạn',
                        'Appear in search and friend suggestions',
                      ),
                      value: discoverable,
                      onChanged: (v) => _setPublic('discoverable', v),
                    ),
                    SettingsTile.toggle(
                      icon: Icons.person_add_alt_1_outlined,
                      title: tr(
                        'Cho phép nhận lời mời kết bạn',
                        'Allow friend requests',
                      ),
                      subtitle: tr(
                        'Tắt thì không ai gửi được lời mời mới cho bạn',
                        'When off, nobody can send you new requests',
                      ),
                      value: allowRequests,
                      onChanged: (v) => _setPublic('allowFriendRequests', v),
                    ),
                  ],
                ),
                SectionLabel(tr('Kiểm soát nội dung', 'Content controls')),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Icons.block,
                      title: tr('Đã chặn và tắt tiếng', 'Blocked and muted'),
                      subtitle:
                      '${prefs.blocked.length} ${tr('đã chặn', 'blocked')} · ${prefs.mutedUsers.length} ${tr('tắt tiếng', 'muted')}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BlockedScreen()),
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.auto_awesome,
                      title: tr('Đề xuất và sở thích', 'Recommendations'),
                      subtitle: prefs.personalizeFeed
                          ? tr('Đang bật', 'On')
                          : tr('Đang tắt', 'Off'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategorySettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                SectionLabel(tr('Dữ liệu và bảo mật', 'Data and security')),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Icons.download_outlined,
                      title: tr(
                        'Tải xuống dữ liệu của bạn',
                        'Download your data',
                      ),
                      subtitle: tr(
                        'Sao chép hồ sơ, bài viết, cài đặt (JSON)',
                        'Copy profile, posts, settings (JSON)',
                      ),
                      trailing: _exporting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : null,
                      onTap: _exporting ? null : _export,
                    ),
                    SettingsTile(
                      icon: Icons.password,
                      title: tr('Đổi mật khẩu', 'Change password'),
                      subtitle: tr(
                        'Gửi email đặt lại mật khẩu',
                        'Send a password reset email',
                      ),
                      onTap: () => confirmPasswordReset(context),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                  child: Text(
              tr(
              'Lưu ý: bài viết mặc định là công khai. Khi đăng bài, chọn "Chỉ bạn bè" để giới hạn người xem.',
              'Note: posts are public by default. Choose "Friends only" when posting to limit who can see it.',
                    ),
                    style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}