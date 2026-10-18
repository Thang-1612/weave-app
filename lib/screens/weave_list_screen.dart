import 'package:flutter/material.dart';

import '../models/weave_activity.dart';
import '../services/l10n.dart';
import '../services/weave_service.dart';
import '../theme/app_theme.dart';
import '../widgets/weave_activity_widgets.dart';
import 'weave_create_screen.dart';
import 'weave_detail_screen.dart';

/// Từ chiều rộng này trở lên, thẻ hoạt động xếp thành 2 cột.
const double _kWeaveListTwoColumnBreakpoint = 760;

/// Danh sách hoạt động. Truyền [groupId] để chỉ xem một nhóm; bỏ trống = tất cả.
class WeaveListScreen extends StatelessWidget {
  final String? groupId;
  final String? groupName;
  const WeaveListScreen({super.key, this.groupId, this.groupName});

  void _open(BuildContext context, WeaveActivity a) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WeaveDetailScreen(activityId: a.id)),
    );
  }

  /// [contentWidth]: bề ngang vùng danh sách, để chia cột khi màn rộng.
  Widget _section(
      BuildContext context,
      String title,
      List<WeaveActivity> items,
      double contentWidth,
      ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final twoColumns = contentWidth >= _kWeaveListTwoColumnBreakpoint;
    const gap = WeaveSpacing.md;
    final cardWidth = twoColumns ? (contentWidth - gap) / 2 : contentWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Wrap(
          spacing: gap,
          runSpacing: 0,
          children: [
            for (final a in items)
              SizedBox(
                width: cardWidth,
                child: WeaveActivityCard(
                  activity: a,
                  onTap: () => _open(context, a),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(groupName ?? tr('Hoạt động nhóm', 'Group activities')),
      ),
      // Màu nút lấy từ theme (Brand Indigo): chỉ một hành động chính mỗi màn hình
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(tr('Tạo hoạt động', 'New activity')),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => WeaveCreateScreen(groupId: groupId)),
        ),
      ),
      body: StreamBuilder<List<WeaveActivity>>(
        stream: groupId == null
            ? WeaveService.watchMine()
            : WeaveService.watchGroup(groupId!),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText('${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    'Chưa có hoạt động nào.\nTạo một hoạt động để cùng bạn bè chọn nơi đi, chốt lịch và ghi lại kỷ niệm.',
                    'No activities yet.\nCreate one to plan with friends, pick a place and keep the memories.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            );
          }
          List<WeaveActivity> by(WeaveStatus s) =>
              items.where((a) => a.status == s).toList();
          return LayoutBuilder(
            builder: (context, constraints) {
              // Hẹp: một cột tối đa 600. Rộng: tối đa 1040, thẻ chia 2 cột.
              final maxW = constraints.maxWidth >= _kWeaveListTwoColumnBreakpoint + 24
                  ? 1040.0
                  : 600.0;
              const padH = 12.0;
              final contentWidth =
                  (constraints.maxWidth < maxW ? constraints.maxWidth : maxW) -
                      padH * 2;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(padH, 4, padH, 90),
                    children: [
                      _section(context, tr('Đang diễn ra', 'Happening now'),
                          by(WeaveStatus.active), contentWidth),
                      _section(context, tr('Đang lên kế hoạch', 'Planning'),
                          by(WeaveStatus.planning), contentWidth),
                      _section(context, tr('Đã kết thúc', 'Ended'),
                          by(WeaveStatus.ended), contentWidth),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}