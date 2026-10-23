import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../models/weave_activity.dart';
import '../services/l10n.dart';
import '../services/weave_service.dart';
import '../theme/app_theme.dart';

String weaveDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String weaveRange(DateTime? a, DateTime? b) {
  if (a == null && b == null) return tr('Chưa đặt thời gian', 'No dates yet');
  if (a != null && b != null) return '${weaveDate(a)} → ${weaveDate(b)}';
  return weaveDate((a ?? b)!);
}

String weaveStatusLabel(WeaveStatus s) {
  switch (s) {
    case WeaveStatus.planning:
      return tr('Đang lên kế hoạch', 'Planning');
    case WeaveStatus.active:
      return tr('Đang diễn ra', 'Happening');
    case WeaveStatus.ended:
      return tr('Đã kết thúc', 'Ended');
  }
}

String weaveRsvpLabel(RsvpStatus s) {
  switch (s) {
    case RsvpStatus.pending:
      return tr('Chưa trả lời', 'No reply');
    case RsvpStatus.going:
      return tr('Tham gia', 'Going');
    case RsvpStatus.maybe:
      return tr('Có thể', 'Maybe');
    case RsvpStatus.no:
      return tr('Không đi', 'Not going');
  }
}

/// Chip trạng thái hoạt động, cùng bảng màu và hình dạng với chip bình chọn:
/// đang lên kế hoạch = Soft Indigo, đang diễn ra = Teal, đã kết thúc = trung tính.
/// Trạng thái luôn có nhãn chữ, không chỉ phân biệt bằng màu.
class WeaveStatusChip extends StatelessWidget {
  final WeaveStatus status;
  const WeaveStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    switch (status) {
      case WeaveStatus.planning:
        bg = AppColors.soft;
        fg = AppColors.brand;
        break;
      case WeaveStatus.active:
        bg = AppColors.teal.withValues(alpha: 0.10);
        fg = AppColors.teal;
        break;
      case WeaveStatus.ended:
        bg = AppColors.background;
        fg = AppColors.textSecondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(WeaveRadius.pill),
      ),
      child: Text(
        weaveStatusLabel(status),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Chữ cái đầu của tên người dùng (đọc từ users/{uid}, có cache).
class WeaveUserAvatar extends StatelessWidget {
  final String uid;
  final double radius;
  const WeaveUserAvatar({super.key, required this.uid, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: WeaveService.profileOf(uid),
      initialData: WeaveService.cachedProfile(uid),
      builder: (context, snap) {
        final name = snap.data?.name ?? '';
        final initial = name.isEmpty
            ? '?'
            : name.characters.first.toUpperCase();
        return CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.brand,
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.9,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

class WeaveUserName extends StatelessWidget {
  final String uid;
  final TextStyle? style;
  const WeaveUserName({super.key, required this.uid, this.style});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: WeaveService.profileOf(uid),
      initialData: WeaveService.cachedProfile(uid),
      builder: (context, snap) {
        final name = snap.data?.name ?? '';
        return Text(
          name.isEmpty ? '…' : name,
          style: style,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class WeaveAvatarStack extends StatelessWidget {
  final List<String> uids;
  final int max;
  const WeaveAvatarStack({super.key, required this.uids, this.max = 5});

  @override
  Widget build(BuildContext context) {
    final shown = uids.take(max).toList();
    final extra = uids.length - shown.length;
    const size = 28.0;
    const step = 18.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: size,
          width: size + (shown.length - 1).clamp(0, 99) * step,
          child: Stack(
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * step,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: WeaveUserAvatar(uid: shown[i], radius: 12),
                  ),
                ),
            ],
          ),
        ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              '+$extra',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// Chọn RSVP của chính mình (pending = chưa chọn gì).
/// Cùng kiểu với các nút chọn khác của Weave: nền trắng, viền mảnh,
/// đang chọn = Soft Indigo + chữ Brand Indigo.
class WeaveRsvpSelector extends StatelessWidget {
  final RsvpStatus current;
  final ValueChanged<RsvpStatus> onChanged;
  final bool enabled;
  const WeaveRsvpSelector({
    super.key,
    required this.current,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<RsvpStatus>(
      emptySelectionAllowed: true,
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        selectedBackgroundColor: AppColors.soft,
        selectedForegroundColor: AppColors.brand,
        side: const BorderSide(color: AppColors.border),
      ),
      segments: [
        for (final s in const [
          RsvpStatus.going,
          RsvpStatus.maybe,
          RsvpStatus.no,
        ])
          ButtonSegment(value: s, label: Text(weaveRsvpLabel(s))),
      ],
      selected: current == RsvpStatus.pending ? <RsvpStatus>{} : {current},
      onSelectionChanged: enabled
          ? (set) {
              if (set.isNotEmpty) onChanged(set.first);
            }
          : null,
    );
  }
}

class WeaveActivityCard extends StatelessWidget {
  final WeaveActivity activity;
  final VoidCallback onTap;
  const WeaveActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final when = a.lockedDate != null
        ? weaveDate(a.lockedDate!)
        : weaveRange(a.startAt, a.endAt);
    // Nền, viền, bo góc và elevation lấy từ cardTheme trong app_theme.dart.
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(WeaveRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      a.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  WeaveStatusChip(status: a.status),
                ],
              ),
              if (a.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  a.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.event,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      when,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (a.lockedPlace != null) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.place,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        a.lockedPlace!.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              WeaveAvatarStack(uids: a.memberIds),
            ],
          ),
        ),
      ),
    );
  }
}
