import 'package:flutter/material.dart';

import '../models/story_models.dart';
import '../services/l10n.dart';
import '../services/story_service.dart';
import '../theme/app_theme.dart';
import '../widgets/story_status_chip.dart';
import '../widgets/story_widgets.dart';
import '../widgets/weave_error_view.dart';
import '../widgets/weave_state_views.dart';
import 'story_create_screen.dart';
import 'story_detail_screen.dart';

/// Từ chiều rộng này trở lên, thẻ câu chuyện xếp thành 2 cột.
const double _kStoryListTwoColumnBreakpoint = 760;

class StoryListScreen extends StatefulWidget {
  const StoryListScreen({super.key});

  @override
  State<StoryListScreen> createState() => _StoryListScreenState();
}

class _StoryListScreenState extends State<StoryListScreen> {
  // Tạo stream một lần (không tạo lại mỗi lần build). Nút Thử lại gán stream mới.
  Stream<List<Story>> _stream = StoryService.myStories();

  Widget _card(BuildContext context, Story s, String me) {
    return Card(
      margin: const EdgeInsets.only(bottom: WeaveSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(WeaveRadius.card),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StoryDetailScreen(storyId: s.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(WeaveSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.soft,
                child: Icon(storyKindIcon(s.kind), color: AppColors.brand),
              ),
              const SizedBox(width: WeaveSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${storyKindLabel(s.kind)} · ${fmtDate(s.updatedAt)}'
                          '${s.ownerId == me ? '' : ' · ${tr('Bạn bè mời', 'Shared with you')}'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: WeaveSpacing.sm),
                    StoryStatusChip(s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = StoryService.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Weave Storymaker')),
      // Màu nút lấy từ theme: một hành động chính nổi bật mỗi màn hình
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StoryCreateScreen()),
        ),
        icon: const Icon(Icons.auto_awesome),
        label: Text(tr('Tạo câu chuyện', 'New story')),
      ),
      body: StreamBuilder<List<Story>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('StoryListScreen stream error: ${snap.error}');
            return WeaveErrorView(
              message: tr(
                'Không tải được danh sách câu chuyện.',
                'Could not load your stories.',
              ),
              onRetry: () => setState(() => _stream = StoryService.myStories()),
            );
          }
          if (!snap.hasData) {
            return const WeaveLoadingView();
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return WeaveEmptyView(
              icon: Icons.auto_stories_outlined,
              title: tr('Chưa có câu chuyện nào.', 'No stories yet.'),
              description: tr(
                'Chọn ảnh và ghi chú để AI kể lại trải nghiệm của bạn.',
                'Pick photos and notes and let the AI retell your experience.',
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= _kStoryListTwoColumnBreakpoint + 32;
              final maxW = wide ? 1040.0 : 600.0;
              const padH = 16.0;
              final contentWidth =
                  (constraints.maxWidth < maxW ? constraints.maxWidth : maxW) -
                      padH * 2;
              const gap = WeaveSpacing.md;
              final cardWidth = wide ? (contentWidth - gap) / 2 : contentWidth;

              // ListView full chiều rộng để lăn chuột ở hai lề vẫn hoạt động;
              // nội dung được căn giữa bằng padding.
              return ListView(
                padding: weaveCenteredPadding(
                  constraints.maxWidth,
                  maxWidth: maxW,
                  h: padH,
                  top: 12,
                  bottom: 88,
                ),
                children: [
                  Wrap(
                    spacing: gap,
                    children: [
                      for (final s in list)
                        SizedBox(
                          width: cardWidth,
                          child: _card(context, s, me),
                        ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}