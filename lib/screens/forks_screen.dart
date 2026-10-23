import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../services/social_extras_service.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';

class _Node {
  final Post post;
  final int depth;
  const _Node(this.post, this.depth);
}

/// Cây nhánh: bài đang xem ở gốc, các nhánh thụt vào theo từng đời
/// (tối đa 3 đời và 40 bài để tiết kiệm lượt đọc).
class ForksScreen extends StatefulWidget {
  final Post original;
  const ForksScreen({super.key, required this.original});

  @override
  State<ForksScreen> createState() => _ForksScreenState();
}

class _ForksScreenState extends State<ForksScreen> {
  static const _maxDepth = 3;
  static const _maxNodes = 40;

  late final Future<List<_Node>> _future = _loadTree();

  Future<List<_Node>> _loadTree() async {
    final out = <_Node>[];
    Future<void> walk(Post p, int depth) async {
      if (depth >= _maxDepth || out.length >= _maxNodes) return;
      final kids = await PostService.getForks(p.id);
      kids.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final k in kids) {
        if (out.length >= _maxNodes) return;
        out.add(_Node(k, depth + 1));
        await walk(k, depth + 1);
      }
    }

    await walk(widget.original, 0);
    return out;
  }

  String _snippet(Post p) {
    final t = p.text.trim();
    if (t.isNotEmpty) return t;
    return p.blocks.any((b) => b['type'] == 'image')
        ? tr('[Ảnh]', '[Image]')
        : tr('[Bài viết]', '[Post]');
  }

  void _open(Post p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(p.authorName)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(children: [PostCard(post: p)]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(Post p, int depth, {bool root = false}) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0 * depth, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!root)
            const Padding(
              padding: EdgeInsets.only(top: 12, right: 4),
              child: Icon(
                Icons.subdirectory_arrow_right,
                size: 18,
                color: AppColors.brand,
              ),
            ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(WeaveRadius.control),
              onTap: () => _open(p),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: root ? AppColors.soft : AppColors.surface,
                  borderRadius: BorderRadius.circular(WeaveRadius.control),
                  border: Border.all(
                    color: root ? AppColors.brand : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (root)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.account_tree,
                              size: 16,
                              color: AppColors.brand,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            '${p.authorName} · ${extrasAgo(p.createdAt)}'
                            '${root ? ' · ${tr('đang xem', 'viewing')}' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (p.updateCount > 0)
                          Text(
                            '🔄 ${p.updateCount}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _snippet(p),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Cây nhánh', 'Fork tree'))),
      body: FutureBuilder<List<_Node>>(
        future: _future,
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
          final nodes = snap.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _tile(widget.original, 0, root: true),
                  if (nodes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        tr('Chưa có nhánh nào.', 'No forks yet.'),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  for (final n in nodes) _tile(n.post, n.depth),
                  if (nodes.length >= _maxNodes)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        tr(
                          'Chỉ hiện 40 bài đầu tiên.',
                          'Showing the first 40 posts only.',
                        ),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
