import 'package:flutter/material.dart';

import '../../models/space.dart';
import '../../services/l10n.dart';
import '../../services/user_prefs.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_widgets.dart';

class CategorySettingsScreen extends StatelessWidget {
  const CategorySettingsScreen({super.key});

  Future<void> _reset(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Xóa dữ liệu sở thích?', 'Clear interest data?')),
        content: Text(
          tr(
            'Ứng dụng sẽ quên các chủ đề bạn từng xem và tương tác. Bảng tin sẽ không còn ưu tiên theo sở thích cho đến khi bạn tương tác lại.',
            'The app will forget the topics you viewed and interacted with. Your feed will stop prioritizing by interest until you interact again.',
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
            child: Text(tr('Xóa', 'Clear')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await UserPrefs.instance.resetInterests();
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('Đã xóa dữ liệu sở thích', 'Interest data cleared')),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// Một nhóm chủ đề lớn: bấm để mở ra các chủ đề nhỏ, có công tắc cả nhóm.
  Widget _group(BuildContext context, SpaceGroup g, UserPrefs prefs) {
    final total = g.children.length;
    final visible = g.children.where((s) => !prefs.isRestricted(s.id)).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Bỏ đường kẻ mặc định của ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('cat_group_${g.id}'),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            '${g.emoji} ${tr(g.name, g.nameEn ?? g.name)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            tr('$visible/$total đang hiện', '$visible/$total visible'),
            style: TextStyle(
              fontSize: 12.5,
              color: visible == total
                  ? AppColors.textSecondary
                  : AppColors.brand,
            ),
          ),
          children: [
            SwitchListTile(
              dense: true,
              title: Text(
                tr('Tất cả trong nhóm', 'Whole group'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              value: visible == total,
              onChanged: (v) {
                for (final s in g.children) {
                  prefs.setRestricted(s.id, !v);
                }
              },
            ),
            for (final s in g.children)
              SwitchListTile(
                dense: true,
                title: Text('${s.emoji} ${spaceName(s.id, s.name)}'),
                value: !prefs.isRestricted(s.id),
                onChanged: (v) => prefs.setRestricted(s.id, !v),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Hạn chế chủ đề', 'Restrict topics'),
      body: ListenableBuilder(
        listenable: UserPrefs.instance,
        builder: (context, _) {
          final prefs = UserPrefs.instance;
          return settingsList([
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                tr(
                  'Chủ đề bị tắt sẽ không hiện trong mục Tất cả, trong menu chủ đề và trong đề xuất. Bài bạn đăng vào chủ đề đó vẫn được lưu bình thường.',
                  'Turned-off topics do not appear in All posts, the topic menu or recommendations. Your posts in those topics are still saved normally.',
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            SectionLabel(tr('Chủ đề được hiện', 'Visible topics')),
            for (final g in spaceGroups) _group(context, g, prefs),
            SectionLabel(tr('Đề xuất', 'Recommendations')),
            SettingsCard(
              children: [
                SettingsTile.toggle(
                  icon: Icons.auto_awesome,
                  title: tr('Đề xuất theo sở thích', 'Personalized feed'),
                  subtitle: tr(
                    'Ưu tiên chủ đề bạn hay xem ở mục Tất cả',
                    'Prioritize topics you often view in All posts',
                  ),
                  value: prefs.personalizeFeed,
                  onChanged: (v) => prefs.setPersonalize(v),
                ),
                SettingsTile(
                  icon: Icons.delete_outline,
                  title: tr('Xóa dữ liệu sở thích', 'Clear interest data'),
                  color: AppColors.danger,
                  onTap: () => _reset(context),
                ),
              ],
            ),
          ]);
        },
      ),
    );
  }
}
