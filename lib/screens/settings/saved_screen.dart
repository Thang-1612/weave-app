import '../../theme/app_theme.dart';

import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../services/l10n.dart';
import '../../services/post_service.dart';
import '../../services/user_prefs.dart';
import '../../widgets/post_card.dart';
import '../../widgets/settings_widgets.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String _key = '';
  Future<List<Post>>? _future;

  /// Lấy từng bài theo mã (bài đã lưu có thể là công khai hoặc không công khai).
  Future<List<Post>> _load(List<String> ids) async {
    final results = await Future.wait(ids.map(PostService.getPost));
    // Giữ đúng thứ tự: lưu gần nhất lên đầu; bỏ qua bài đã bị xóa
    return [for (final p in results) ?p];
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bookmark_border,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                'Chưa có bài viết nào được lưu.\nBấm biểu tượng đánh dấu dưới mỗi bài để lưu lại.',
                'No saved posts yet.\nTap the bookmark icon under a post to save it.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Đã lưu', 'Saved'),
      body: ListenableBuilder(
        listenable: UserPrefs.instance,
        builder: (context, _) {
          final ids = UserPrefs.instance.savedIds;
          final key = ids.join(',');
          if (key != _key) {
            _key = key;
            _future = ids.isEmpty ? null : _load(ids);
          }
          if (ids.isEmpty) return _empty();

          return FutureBuilder<List<Post>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text(
                    '${tr('Không tải được', 'Could not load')}\n${snap.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final posts = snap.data!;
              if (posts.isEmpty) return _empty();
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: posts.length,
                    itemBuilder: (_, i) => PostCard(post: posts[i]),
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
