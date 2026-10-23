import 'package:flutter/material.dart';

import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// Ba mức đối tượng xem bài viết.
const kAudiences = ['public', 'friends', 'me'];

IconData audienceIcon(String v) {
  switch (v) {
    case 'friends':
      return Icons.group;
    case 'me':
      return Icons.lock_outline;
    default:
      return Icons.public;
  }
}

String audienceLabel(String v) {
  switch (v) {
    case 'friends':
      return tr('Bạn bè', 'Friends');
    case 'me':
      return tr('Chỉ mình tôi', 'Only me');
    default:
      return tr('Công khai', 'Public');
  }
}

String audienceHint(String v) {
  switch (v) {
    case 'friends':
      return tr(
        'Chỉ những người đang là bạn bè của bạn xem được',
        'Only people who are currently your friends can see it',
      );
    case 'me':
      return tr(
        'Chỉ bạn xem được, không ai khác',
        'Only you can see it, nobody else',
      );
    default:
      return tr(
        'Mọi người dùng trong ứng dụng đều xem được',
        'Everyone in the app can see it',
      );
  }
}

/// Bảng chọn đối tượng. Trả về 'public', 'friends', 'me' hoặc null nếu đóng bảng.
Future<String?> showAudiencePicker(
  BuildContext context, {
  required String current,
  String? title,
}) {
  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title ?? tr('Ai có thể xem bài viết?', 'Who can see this post?'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final v in kAudiences)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.soft,
                  child: Icon(audienceIcon(v), color: AppColors.brand),
                ),
                title: Text(
                  audienceLabel(v),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(audienceHint(v)),
                trailing: current == v
                    ? const Icon(Icons.check_circle, color: AppColors.brand)
                    : null,
                onTap: () => Navigator.of(ctx).pop(v),
              ),
          ],
        ),
      ),
    ),
  );
}
