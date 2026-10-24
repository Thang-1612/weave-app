import 'package:flutter/material.dart';

import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// Màn lỗi thân thiện dùng chung: thông điệp ngắn + nút Thử lại.
/// Chi tiết kỹ thuật nên được ghi log bằng debugPrint, không hiện cho người dùng.
class WeaveErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const WeaveErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WeaveSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: WeaveSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: WeaveSpacing.md),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(tr('Thử lại', 'Retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}