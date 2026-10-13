import 'package:flutter/material.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_widgets.dart';

const _appName = 'Social App';
const _appVersion = '1.0.0';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Giới thiệu', 'About'),
      body: settingsList([
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 46),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            _appName,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        Center(
          child: Text(
            '${tr('Phiên bản', 'Version')} $_appVersion',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(
            tr(
              'Mạng xã hội chia sẻ theo chủ đề: học tập, nấu ăn, du lịch, chế tạo. Bài đăng gồm nhiều khối (chữ, ảnh, liên kết, icon), có đề xuất theo sở thích, tự phân chủ đề và trợ lý AI trong bình luận.',
              'A topic-based social network: study, cooking, travel and making. Posts are built from blocks (text, images, links, icons), with interest-based recommendations, automatic topic detection and an AI assistant in comments.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
        ),
        SectionLabel(tr('Công nghệ', 'Built with')),
        SettingsCard(
          children: const [
            SettingsTile(icon: Icons.flutter_dash, title: 'Flutter'),
            SettingsTile(icon: Icons.cloud_outlined, title: 'Firebase: Authentication, Firestore'),
            SettingsTile(icon: Icons.auto_awesome, title: 'Gemini (Firebase AI Logic)'),
          ],
        ),
        SectionLabel(tr('Thông tin', 'Information')),
        SettingsCard(
          children: [
            SettingsTile(
              icon: Icons.article_outlined,
              title: tr('Giấy phép mã nguồn mở', 'Open source licenses'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: _appName,
                applicationVersion: _appVersion,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              '© ${DateTime.now().year} $_appName',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ]),
    );
  }
}