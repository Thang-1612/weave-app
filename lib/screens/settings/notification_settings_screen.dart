import 'package:flutter/material.dart';
import '../../services/l10n.dart';
import '../../services/user_prefs.dart';
import '../../widgets/settings_widgets.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Thông báo', 'Notifications'),
      body: ListenableBuilder(
        listenable: UserPrefs.instance,
        builder: (context, _) {
          final prefs = UserPrefs.instance;
          final all = prefs.notifAll();

          return settingsList([
            SettingsCard(
              children: [
                SettingsTile.toggle(
                  icon: Icons.notifications_active_outlined,
                  title: tr('Bật thông báo', 'Enable notifications'),
                  subtitle: tr(
                    'Tắt để ẩn mọi thông báo trong ứng dụng',
                    'Turn off to hide all in-app notifications',
                  ),
                  value: all,
                  onChanged: (v) => prefs.setNotif('all', v),
                ),
              ],
            ),
            SectionLabel(tr('Loại thông báo', 'Notification types')),
            SettingsCard(
              children: [
                for (final g in notifGroups)
                  SettingsTile.toggle(
                    icon: g.icon,
                    title: tr(g.vi, g.en),
                    subtitle: tr(g.descVi, g.descEn),
                    value: all && prefs.notifGroupOn(g.key),
                    onChanged: all ? (v) => prefs.setNotif(g.key, v) : (_) {},
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Text(
                tr(
                  'Thông báo bị tắt sẽ không hiện trong danh sách và không tính vào số chưa đọc.',
                  'Turned-off notifications are hidden from the list and not counted as unread.',
                ),
                style: const TextStyle(color: Colors.grey, height: 1.4),
              ),
            ),
          ]);
        },
      ),
    );
  }
}