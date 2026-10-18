import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/account_service.dart';
import '../services/l10n.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

/// Khung chung cho các màn hình cài đặt: AppBar phẳng theo theme + nội dung.
class SettingsScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;

  const SettingsScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Không còn flexibleSpace gradient: AppBar lấy nền Surface và viền dưới từ theme.
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: body,
    );
  }
}

/// Danh sách căn giữa, rộng tối đa 600.
Widget settingsList(List<Widget> children) {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: children,
      ),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Thẻ trắng bo tròn gom nhiều dòng cài đặt.
///
/// Dùng Material (không phải Container tô màu) để ListTile bên trong vẽ được
/// hiệu ứng chạm và rê chuột; Container có màu sẽ che mất lớp ink này.
class SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WeaveRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 60),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
  });

  /// Dòng có công tắc bật/tắt.
  factory SettingsTile.toggle({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SettingsTile(
      key: key,
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? AppColors.brand, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right, color: AppColors.textSecondary)
              : null),
      onTap: onTap,
    );
  }
}

/// Một người (avatar + tên + giới thiệu), tự tải hồ sơ theo mã người dùng.
class PersonTile extends StatefulWidget {
  final String uid;
  final Widget? trailing;
  final VoidCallback? onTap;

  const PersonTile({super.key, required this.uid, this.trailing, this.onTap});

  @override
  State<PersonTile> createState() => _PersonTileState();
}

class _PersonTileState extends State<PersonTile> {
  late final Stream<UserProfile?> _stream =
  UserService.watchProfile(widget.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _stream,
      builder: (context, snap) {
        final name = snap.data?.name ?? '';
        final shown = name.isEmpty ? tr('Người dùng', 'User') : name;
        final bio = snap.data?.bio ?? '';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.soft,
            child: Text(
              initialOf(shown),
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(shown, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: bio.isEmpty
              ? null
              : Text(bio, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: widget.trailing,
          onTap: widget.onTap,
        );
      },
    );
  }
}