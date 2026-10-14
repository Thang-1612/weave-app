import 'package:flutter/material.dart';

import '../models/weave_activity.dart';
import '../services/l10n.dart';
import '../services/weave_service.dart';
import '../theme/app_theme.dart';
import '../widgets/weave_activity_widgets.dart';
import 'weave_create_screen.dart';
import 'weave_detail_screen.dart';

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

  Widget _section(BuildContext context, String title, List<WeaveActivity> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.brand)),
        ),
        for (final a in items)
          WeaveActivityCard(activity: a, onTap: () => _open(context, a)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        title: Text(groupName ?? tr('Hoạt động nhóm', 'Group activities')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
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
                  style: const TextStyle(color: Colors.grey, height: 1.4),
                ),
              ),
            );
          }
          List<WeaveActivity> by(WeaveStatus s) =>
              items.where((a) => a.status == s).toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                children: [
                  _section(context, tr('Đang diễn ra', 'Happening now'),
                      by(WeaveStatus.active)),
                  _section(context, tr('Đang lên kế hoạch', 'Planning'),
                      by(WeaveStatus.planning)),
                  _section(context, tr('Đã kết thúc', 'Ended'),
                      by(WeaveStatus.ended)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}