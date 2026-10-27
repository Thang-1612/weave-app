import 'package:flutter/material.dart';
import '../models/weave_layer.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// NGUỒN DUY NHẤT cho nhãn, biểu tượng và mô tả của mọi loại đối tượng xem:
/// 'public' | 'friends' | 'close' | 'group' | 'me' (xem [LayerAudience]).
///
/// Bài viết dùng 3 loại đầu/cuối (public, friends, me); lớp (Layers) dùng đủ 5.
/// Thêm một loại mới chỉ cần sửa ở đây.

IconData audienceIcon(String type) {
  switch (type) {
    case LayerAudience.kFriends:
      return Icons.group;
    case LayerAudience.kClose:
      return Icons.favorite_border;
    case LayerAudience.kGroup:
      return Icons.groups_outlined;
    case LayerAudience.kMe:
      return Icons.lock_outline;
    default:
      return Icons.public;
  }
}

String audienceLabel(String type) {
  switch (type) {
    case LayerAudience.kFriends:
      return tr('Bạn bè', 'Friends');
    case LayerAudience.kClose:
      return tr('Bạn thân', 'Close friends');
    case LayerAudience.kGroup:
      return tr('Nhóm riêng', 'Private group');
    case LayerAudience.kMe:
      return tr('Chỉ mình tôi', 'Only me');
    default:
      return tr('Công khai', 'Public');
  }
}

String audienceHint(String type) {
  switch (type) {
    case LayerAudience.kFriends:
      return tr(
        'Chỉ những người đang là bạn bè của bạn xem được',
        'Only people who are currently your friends can see it',
      );
    case LayerAudience.kClose:
      return tr(
        'Chỉ những người trong danh sách bạn thân của bạn',
        'Only people on your close friends list',
      );
    case LayerAudience.kGroup:
      return tr(
        'Chỉ thành viên của một nhóm riêng bạn chọn',
        'Only members of a private group you choose',
      );
    case LayerAudience.kMe:
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

/// Bảng chọn loại đối tượng dùng chung. [types] là các loại được phép chọn.
/// [labelOf] cho phép đổi nhãn một dòng (ví dụ hiện tên nhóm đang chọn).
/// Trả về loại được chọn, hoặc null nếu đóng bảng.
Future<String?> showAudienceTypeSheet(
    BuildContext context, {
      required List<String> types,
      required String current,
      required String title,
      String Function(String type)? labelOf,
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
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final v in types)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.soft,
                  child: Icon(audienceIcon(v), color: AppColors.brand),
                ),
                title: Text(
                  labelOf?.call(v) ?? audienceLabel(v),
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
