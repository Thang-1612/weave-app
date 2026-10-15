import 'package:flutter/material.dart';
import '../models/story_models.dart';
import '../services/l10n.dart';
import '../services/story_service.dart';
import '../theme/app_theme.dart';
import '../widgets/story_widgets.dart';
import 'story_create_screen.dart';
import 'story_detail_screen.dart';

class StoryListScreen extends StatelessWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = StoryService.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Weave Storymaker')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StoryCreateScreen()),
        ),
        icon: const Icon(Icons.auto_awesome),
        label: Text(tr('Tạo câu chuyện', 'New story')),
      ),
      body: StreamBuilder<List<Story>>(
        stream: StoryService.myStories(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Chưa có câu chuyện nào. Chọn ảnh và ghi chú để AI kể lại trải nghiệm của bạn.',
                      'No stories yet. Pick photos and notes and let the AI retell your experience.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = list[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.soft,
                  child: Icon(storyKindIcon(s.kind), color: AppColors.brand),
                ),
                title: Text(s.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${storyKindLabel(s.kind)} · ${fmtDate(s.updatedAt)}'
                      '${s.ownerId == me ? '' : ' · ${tr('Bạn bè mời', 'Shared with you')}'}',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StoryDetailScreen(storyId: s.id),
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