import 'package:flutter/material.dart';

import '../models/space.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// Menu chủ đề dạng thu gọn/mở rộng cho menu ba gạch.
/// Đặt bên trong một ListView (Drawer) để cuộn được.
class SpaceMenu extends StatelessWidget {
  /// Chủ đề nhỏ đang chọn.
  final String? selectedSpaceId;

  /// Chủ đề lớn đang chọn (khi bấm `Tất cả <nhóm>`).
  final String? selectedGroupId;

  /// Các chủ đề yêu thích: hiện ngôi sao và xếp lên đầu trong nhóm.
  final Set<String> favoriteIds;

  /// Trả về true nếu chủ đề bị hạn chế (sẽ bị ẩn).
  final bool Function(String spaceId)? isHidden;

  final void Function(Space space) onSpaceSelected;

  /// Nếu để null thì không hiện dòng `Tất cả <nhóm>`.
  final void Function(SpaceGroup group)? onGroupSelected;

  const SpaceMenu({
    super.key,
    required this.onSpaceSelected,
    this.onGroupSelected,
    this.selectedSpaceId,
    this.selectedGroupId,
    this.favoriteIds = const {},
    this.isHidden,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeGroupId =
        selectedGroupId ??
        (selectedSpaceId == null ? null : groupOfSpace(selectedSpaceId!)?.id);

    final tiles = <Widget>[];
    for (final g in spaceGroups) {
      final visible = g.children
          .where((s) => !(isHidden?.call(s.id) ?? false))
          .toList();
      if (visible.isEmpty) continue;
      final children = [
        ...visible.where((s) => favoriteIds.contains(s.id)),
        ...visible.where((s) => !favoriteIds.contains(s.id)),
      ];
      final groupActive = activeGroupId == g.id;
      final groupName = tr(g.name, g.nameEn ?? g.name);

      tiles.add(
        ExpansionTile(
          key: ValueKey('group_${g.id}'),
          initiallyExpanded: groupActive,
          leading: Text(g.emoji, style: const TextStyle(fontSize: 22)),
          title: Text(
            groupName,
            style: TextStyle(
              fontWeight: groupActive ? FontWeight.w600 : FontWeight.normal,
              color: groupActive ? cs.primary : null,
            ),
          ),
          childrenPadding: const EdgeInsets.only(left: 24),
          children: [
            if (onGroupSelected != null)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.apps,
                  size: 20,
                  color: selectedGroupId == g.id ? cs.primary : null,
                ),
                title: Text(
                  tr('Tất cả ${g.name}', 'All ${g.nameEn ?? g.name}'),
                  style: TextStyle(
                    color: selectedGroupId == g.id ? cs.primary : null,
                  ),
                ),
                onTap: () => onGroupSelected!(g),
              ),
            for (final s in children)
              ListTile(
                dense: true,
                leading: Text(s.emoji, style: const TextStyle(fontSize: 18)),
                title: Text(
                  tr(s.name, s.nameEn ?? s.name),
                  style: TextStyle(
                    color: selectedSpaceId == s.id ? cs.primary : null,
                    fontWeight: selectedSpaceId == s.id
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                trailing: favoriteIds.contains(s.id)
                    ? const Icon(Icons.star, size: 18, color: AppColors.brand)
                    : null,
                onTap: () => onSpaceSelected(s),
              ),
          ],
        ),
      );
    }

    return Theme(
      // bỏ đường kẻ mặc định của ExpansionTile
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Column(children: tiles),
    );
  }
}
