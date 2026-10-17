import 'package:flutter/material.dart';
import '../../models/space.dart';
import '../../services/l10n.dart';
import '../../services/trash_service.dart';
import '../../theme/app_theme.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late final Stream<List<TrashItem>> _stream = TrashService.watch();

  @override
  void initState() {
    super.initState();
    // Dọn các bài đã quá 30 ngày
    TrashService.purgeExpired();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _restore(TrashItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await TrashService.restore(item);
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Đã khôi phục bài viết', 'Post restored'))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${tr('Không khôi phục được', 'Could not restore')}: $e'),
        ),
      );
    }
  }

  Future<void> _deleteForever(TrashItem item) async {
    final ok = await _confirm(
      title: tr('Xóa vĩnh viễn?', 'Delete permanently?'),
      message: tr(
        'Bài viết sẽ bị xóa hẳn và không thể khôi phục.',
        'This post will be deleted for good and cannot be restored.',
      ),
      action: tr('Xóa vĩnh viễn', 'Delete'),
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await TrashService.deleteForever(item);
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Đã xóa vĩnh viễn', 'Deleted permanently'))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${tr('Không xóa được', 'Could not delete')}: $e'),
        ),
      );
    }
  }

  Future<void> _emptyAll(int count) async {
    final ok = await _confirm(
      title: tr('Dọn sạch thùng rác?', 'Empty trash?'),
      message: tr(
        'Toàn bộ $count bài viết sẽ bị xóa vĩnh viễn và không thể khôi phục.',
        'All $count posts will be deleted for good and cannot be restored.',
      ),
      action: tr('Dọn sạch', 'Empty'),
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await TrashService.emptyTrash();
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Đã dọn sạch thùng rác', 'Trash emptied'))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${tr('Không dọn được', 'Could not empty')}: $e'),
        ),
      );
    }
  }

  String _ago(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days <= 0) return tr('hôm nay', 'today');
    return tr('$days ngày trước', '$days days ago');
  }

  Widget _card(TrashItem item) {
    final space = findSpace(item.spaceId);
    final spaceLabel = space == null
        ? ''
        : '${space.emoji} ${tr(space.name, space.nameEn ?? space.name)}';
    final preview = item.previewText;

    final extras = <String>[
      if (item.imageCount > 0)
        tr('${item.imageCount} ảnh', '${item.imageCount} photo(s)'),
      if (item.linkCount > 0)
        tr('${item.linkCount} liên kết', '${item.linkCount} link(s)'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spaceLabel.isNotEmpty)
            Text(
              spaceLabel,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 6),
          Text(
            preview.isEmpty
                ? tr('(Bài viết không có chữ)', '(Post has no text)')
                : preview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              color: preview.isEmpty ? AppColors.textSecondary : null,
            ),
          ),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              extras.join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            tr(
              'Đã xóa ${_ago(item.deletedAt)} · còn ${item.daysLeft} ngày',
              'Deleted ${_ago(item.deletedAt)} · ${item.daysLeft} day(s) left',
            ),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _restore(item),
                icon: const Icon(Icons.restore, size: 18),
                label: Text(tr('Khôi phục', 'Restore')),
                style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              ),
              TextButton.icon(
                onPressed: () => _deleteForever(item),
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: Text(tr('Xóa vĩnh viễn', 'Delete')),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(AsyncSnapshot<List<TrashItem>> snap, List<TrashItem> items) {
    if (snap.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${tr('Không tải được thùng rác.', 'Could not load trash.')}\n${snap.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!snap.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline, size: 56, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                tr(
                  'Thùng rác trống.\nBài viết đã xóa sẽ được giữ ở đây 30 ngày.',
                  'Trash is empty.\nDeleted posts are kept here for 30 days.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 20, color: AppColors.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr(
                        'Bài viết trong thùng rác sẽ tự xóa vĩnh viễn sau 30 ngày. Bạn có thể khôi phục hoặc xóa vĩnh viễn bất cứ lúc nào.',
                        'Posts in the trash are permanently deleted after 30 days. You can restore or delete them at any time.',
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            for (final item in items) _card(item),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TrashItem>>(
      stream: _stream,
      builder: (context, snap) {
        final items = snap.data ?? const <TrashItem>[];
        return Scaffold(
          appBar: AppBar(
            flexibleSpace: const GradientAppBarBackground(),
            title: Text(tr('Thùng rác', 'Trash')),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: tr('Dọn sạch thùng rác', 'Empty trash'),
                  onPressed: () => _emptyAll(items.length),
                ),
            ],
          ),
          body: _body(snap, items),
        );
      },
    );
  }
}