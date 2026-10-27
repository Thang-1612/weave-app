import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'audience_meta.dart';

/// Icon / nhãn theo loại đối tượng của lớp. Giữ tên cũ cho nơi đang gọi;
/// nội dung nằm ở audience_meta.dart.
IconData layerAudienceIcon(String type) => audienceIcon(type);

String layerAudienceLabel(String type) => audienceLabel(type);

class LayerTabItem {
  final String id;
  final String label;
  final IconData icon;

  const LayerTabItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Thanh chuyển giữa các lớp của một bài (cuộn ngang).
class LayerTabBar extends StatelessWidget {
  final List<LayerTabItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const LayerTabBar({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final it = items[i];
          final selected = it.id == selectedId;
          return ChoiceChip(
            showCheckmark: false,
            avatar: Icon(
              it.icon,
              size: 16,
              color: selected ? AppColors.brand : AppColors.textSecondary,
            ),
            label: Text(it.label),
            selected: selected,
            selectedColor: AppColors.soft,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected ? AppColors.brand : AppColors.border,
            ),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.brand : AppColors.textSecondary,
            ),
            onSelected: (_) => onSelected(it.id),
          );
        },
      ),
    );
  }
}