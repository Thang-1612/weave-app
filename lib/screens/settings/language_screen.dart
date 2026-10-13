import 'package:flutter/material.dart';
import '../../services/l10n.dart';
import '../../services/user_prefs.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_widgets.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Ngôn ngữ hiển thị', 'Display language'),
      body: ListenableBuilder(
        listenable: UserPrefs.instance,
        builder: (context, _) {
          final prefs = UserPrefs.instance;
          Widget option(String code, String label, String sub) {
            final selected = prefs.language == code;
            return SettingsTile(
              icon: Icons.language,
              title: label,
              subtitle: sub,
              trailing: selected
                  ? const Icon(Icons.check_circle, color: AppColors.brand)
                  : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
              onTap: () => prefs.setLanguage(code),
            );
          }

          return settingsList([
            SettingsCard(
              children: [
                option('vi', 'Tiếng Việt', 'Vietnamese'),
                option('en', 'English', 'Tiếng Anh'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Text(
                tr(
                  'Ngôn ngữ áp dụng cho phần cài đặt, menu và thanh tiêu đề chính. Các màn hình còn lại sẽ được dịch dần ở các bản cập nhật sau.',
                  'The language applies to settings, the menu and main titles. Other screens will be translated in future updates.',
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