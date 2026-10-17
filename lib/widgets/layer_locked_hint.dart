import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../services/l10n.dart';

/// Dòng gợi ý "còn nội dung riêng tư" khi người xem chưa đủ quyền xem
/// một số lớp. Cố ý không nói rõ lớp dành cho ai hay tên lớp là gì.
/// Không muốn lộ sự tồn tại của lớp thì đừng dùng widget này.
class LayerLockedHint extends StatelessWidget {
  final int count;

  const LayerLockedHint({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tr(
                'Còn $count lớp nội dung riêng tư',
                count == 1
                    ? '1 more private layer'
                    : '$count more private layers',
              ),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}