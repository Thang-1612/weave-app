import 'package:flutter/material.dart';
import '../models/story_models.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// Ba trạng thái của một câu chuyện, suy ra từ dữ liệu có sẵn:
/// - đã xuất bản: có publishedPostId
/// - đang cộng tác: chưa xuất bản và có từ 2 người cùng sửa
/// - bản nháp: còn lại
enum StoryStatus { draft, collaborating, published }

StoryStatus storyStatusOf(Story s) {
  if (s.publishedPostId != null) return StoryStatus.published;
  if (s.collaboratorIds.length > 1) return StoryStatus.collaborating;
  return StoryStatus.draft;
}

/// Chip ngắn hiển thị trạng thái; mỗi trạng thái một màu và một icon riêng
/// nên phân biệt được ngay cả khi không đọc chữ.
class StoryStatusChip extends StatelessWidget {
  final Story story;
  const StoryStatusChip(this.story, {super.key});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    final Color fg;
    final Color bg;
    final Color border;

    switch (storyStatusOf(story)) {
      case StoryStatus.published:
        icon = Icons.check_circle_outline;
        label = tr('Đã xuất bản', 'Published');
        fg = AppColors.teal;
        bg = AppColors.teal.withValues(alpha: 0.10);
        border = Colors.transparent;
        break;
      case StoryStatus.collaborating:
        icon = Icons.group_outlined;
        label = tr('Đang cộng tác', 'Collaborating');
        fg = AppColors.brand;
        bg = AppColors.soft;
        border = Colors.transparent;
        break;
      case StoryStatus.draft:
        icon = Icons.edit_note;
        label = tr('Bản nháp', 'Draft');
        fg = AppColors.textSecondary;
        bg = AppColors.surface;
        border = AppColors.border;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(WeaveRadius.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}