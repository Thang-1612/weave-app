import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/l10n.dart';
import '../services/social_extras_service.dart';
import '../services/version_service.dart';
import '../theme/app_theme.dart';
import '../widgets/weave_error_view.dart';
import '../widgets/weave_state_views.dart';

/// Lịch sử phiên bản của một bài: xem và khôi phục (chỉ tác giả).
class VersionsScreen extends StatefulWidget {
  final Post post;
  const VersionsScreen({super.key, required this.post});

  @override
  State<VersionsScreen> createState() => _VersionsScreenState();
}

class _VersionsScreenState extends State<VersionsScreen> {
  // Không để final: nút Thử lại gán future mới để tải lại thật.
  late Future<List<PostVersion>> _future = VersionService.load(widget.post);
  bool _busy = false;

  String _preview(PostVersion v) {
    final lines = <String>[];
    for (final b in v.blocks) {
      if (b['type'] == 'text') {
        final t = (b['text'] as String? ?? '').trim();
        if (t.isNotEmpty) lines.add(t);
      }
    }
    if (lines.isEmpty) return tr('(không có chữ)', '(no text)');
    final joined = lines.join('\n');
    return joined.length > 220 ? '${joined.substring(0, 220)}…' : joined;
  }

  Future<void> _restore(PostVersion v) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Khôi phục phiên bản này?', 'Restore this version?')),
        content: Text(
          tr(
            'Nội dung hiện tại sẽ được lưu lại thành một phiên bản, nên bạn vẫn quay lại được.',
            'The current content is saved as a version first, so you can switch back.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Khôi phục', 'Restore')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await VersionService.restore(widget.post, v);
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Đã khôi phục', 'Restored'))),
      );
      nav.pop();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Lịch sử phiên bản', 'Version history'))),
      body: FutureBuilder<List<PostVersion>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('VersionsScreen load error: ${snap.error}');
            return WeaveErrorView(
              message: tr(
                'Không tải được lịch sử phiên bản.',
                'Could not load version history.',
              ),
              onRetry: () => setState(
                    () => _future = VersionService.load(widget.post),
              ),
            );
          }
          if (!snap.hasData) {
            return const WeaveLoadingView();
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return WeaveEmptyView(
              icon: Icons.history,
              title: tr(
                'Chưa có phiên bản nào được lưu.',
                'No saved versions yet.',
              ),
              description: tr(
                'Bản cũ được lưu mỗi khi bạn nhận một đề xuất sửa bài.',
                'An old version is saved whenever you accept an edit proposal.',
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length + 1,
                itemBuilder: (context, i) {
                  if (i == items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        tr(
                          'Chỉ giữ ${VersionService.keep} phiên bản gần nhất.',
                          'Only the latest ${VersionService.keep} versions are kept.',
                        ),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  final v = items[i];
                  final images = v.blocks
                      .where((b) => b['type'] == 'image')
                      .length;
                  final links = v.blocks
                      .where((b) => b['type'] == 'link')
                      .length;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          extrasAgo(v.savedAt),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                        if (v.reason.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            v.reason,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(_preview(v), style: const TextStyle(height: 1.35)),
                        if (images > 0 || links > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${tr('Ảnh', 'Images')}: $images · ${tr('Liên kết', 'Links')}: $links',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _busy ? null : () => _restore(v),
                            icon: const Icon(Icons.history, size: 18),
                            label: Text(tr('Khôi phục', 'Restore')),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}