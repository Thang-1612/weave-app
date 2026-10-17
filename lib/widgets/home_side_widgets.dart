import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// Ô "Bạn muốn lưu giữ khoảnh khắc nào?" ở đầu bảng tin (tablet, desktop).
/// Dùng nút viền vì hành động nổi bật nhất đã nằm ở FAB / nút sidebar.
class HomeCreatePrompt extends StatelessWidget {
  const HomeCreatePrompt({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WeaveSpacing.lg),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.soft,
              child: Icon(Icons.edit_outlined, color: AppColors.brand),
            ),
            const SizedBox(width: WeaveSpacing.md),
            Expanded(
              child: Text(
                tr(
                  'Bạn muốn lưu giữ khoảnh khắc nào?',
                  'Which moment do you want to keep?',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: WeaveSpacing.sm),
            OutlinedButton(
              onPressed: onCreate,
              child: Text(tr('Tạo bài', 'Create post')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phần đầu cố định phía trên bảng tin: lời chào (nếu đủ cao) + ô tạo bài.
class HomeFeedHeader extends StatelessWidget {
  const HomeFeedHeader({
    super.key,
    required this.name,
    required this.onCreate,
    this.showGreeting = true,
  });

  final String? name;
  final VoidCallback onCreate;
  final bool showGreeting;

  @override
  Widget build(BuildContext context) {
    final n = name;
    final hasName = n != null && n.trim().isNotEmpty;
    final greeting = hasName
        ? tr('Chào $n 👋', 'Hi $n 👋')
        : tr('Chào bạn 👋', 'Hello 👋');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WeaveSpacing.lg,
        WeaveSpacing.lg,
        WeaveSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showGreeting) ...[
            Text(
              greeting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: WeaveSpacing.md),
          ],
          HomeCreatePrompt(onCreate: onCreate),
        ],
      ),
    );
  }
}

class HomeShortcut {
  const HomeShortcut({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

/// Cột phụ bên phải (chỉ hiện ở desktop đủ rộng, do shell quyết định).
/// Chỉ chứa lối tắt tới các màn hình có thật, không có dữ liệu giả.
class HomeShortcutsPanel extends StatelessWidget {
  const HomeShortcutsPanel({
    super.key,
    required this.title,
    required this.shortcuts,
  });

  final String title;
  final List<HomeShortcut> shortcuts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(WeaveSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: WeaveSpacing.sm),
                for (final s in shortcuts) _ShortcutRow(shortcut: s),
              ],
            ),
          ),
        ),
        const SizedBox(height: WeaveSpacing.lg),
        Card(
          color: AppColors.soft,
          child: Padding(
            padding: const EdgeInsets.all(WeaveSpacing.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_outline,
                  color: AppColors.brand,
                  size: 28,
                ),
                const SizedBox(width: WeaveSpacing.md),
                Expanded(
                  child: Text(
                    tr(
                      'Kết nối với người quan trọng, theo cách của bạn.',
                      'Stay close to the people who matter, your way.',
                    ),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.shortcut});

  final HomeShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(WeaveRadius.control),
      onTap: shortcut.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WeaveSpacing.sm),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(WeaveSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(WeaveRadius.control),
              ),
              child: Icon(shortcut.icon, color: AppColors.brand),
            ),
            const SizedBox(width: WeaveSpacing.md),
            Expanded(
              child: Text(
                shortcut.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}