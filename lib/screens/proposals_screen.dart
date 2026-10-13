import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../services/proposal_service.dart';
import '../services/social_extras_service.dart';
import '../theme/app_theme.dart';

/// Hộp "Đề xuất sửa bài": các bài nhánh người khác gửi cho bài gốc của bạn.
class ProposalsScreen extends StatefulWidget {
  const ProposalsScreen({super.key});

  @override
  State<ProposalsScreen> createState() => _ProposalsScreenState();
}

class _ProposalsScreenState extends State<ProposalsScreen> {
  late Future<List<Proposal>> _future = ProposalService.loadMine();

  Future<void> _reload() async {
    setState(() => _future = ProposalService.loadMine());
    await _future;
  }

  Future<void> _open(Proposal p) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _CompareScreen(proposal: p)),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        title: Text(tr('Đề xuất sửa bài', 'Edit proposals')),
      ),
      body: FutureBuilder<List<Proposal>>(
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
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    'Chưa có đề xuất nào.\nKhi ai đó rẽ nhánh bài của bạn và gửi đề xuất, nó sẽ hiện ở đây.',
                    'No proposals yet.\nWhen someone forks your post and sends a proposal, it shows up here.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, height: 1.4),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final p = items[i];
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.call_merge,
                            color: AppColors.brand),
                        title: Text(
                          '${p.fromName} · ${extrasAgo(p.createdAt)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          p.note.isNotEmpty
                              ? p.note
                              : tr('Bấm để xem so sánh', 'Tap to compare'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(p),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompareScreen extends StatefulWidget {
  final Proposal proposal;
  const _CompareScreen({required this.proposal});

  @override
  State<_CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<_CompareScreen> {
  late final Future<List<Post?>> _future = Future.wait([
    PostService.getPost(widget.proposal.originalId),
    PostService.getPost(widget.proposal.forkId),
  ]);
  bool _busy = false;

  List<String> _lines(Post p) {
    final out = <String>[];
    for (final b in p.blocks) {
      if (b['type'] == 'text') {
        out.addAll(
          (b['text'] as String? ?? '')
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }
    }
    return out;
  }

  int _count(Post p, String type) =>
      p.blocks.where((b) => b['type'] == type).length;

  Future<void> _run(Future<void> Function() action, String doneMsg) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(doneMsg)));
      nav.pop(true);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _line(String text, {bool added = false, bool removed = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: added
            ? const Color(0xFFE7F7EC)
            : removed
            ? const Color(0xFFFDECEC)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${added ? '+ ' : removed ? '− ' : ''}$text',
        style: TextStyle(
          height: 1.35,
          decoration: removed ? TextDecoration.lineThrough : null,
          color: removed ? Colors.red.shade700 : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        title: Text(tr('So sánh đề xuất', 'Compare proposal')),
      ),
      body: FutureBuilder<List<Post?>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: SelectableText('${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final original = snap.data![0];
          final fork = snap.data![1];
          if (original == null || fork == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Bài nhánh hoặc bài gốc không còn tồn tại.',
                      'The fork or the original post no longer exists.'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final before = _lines(original);
          final after = _lines(fork);
          final beforeSet = before.toSet();
          final afterSet = after.toSet();
          final removed = before.where((l) => !afterSet.contains(l)).toList();
          final addedCount = after.where((l) => !beforeSet.contains(l)).length;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${p.fromName} ${tr('đề xuất sửa bài của bạn', 'proposes changes to your post')}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  if (p.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(p.note, style: const TextStyle(height: 1.35)),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(
                            '+$addedCount ${tr('dòng mới', 'new lines')}'),
                        backgroundColor: const Color(0xFFE7F7EC),
                      ),
                      Chip(
                        label: Text(
                            '−${removed.length} ${tr('dòng bị bỏ', 'removed')}'),
                        backgroundColor: const Color(0xFFFDECEC),
                      ),
                      Chip(
                        label: Text(
                            '${tr('Ảnh', 'Images')}: ${_count(original, 'image')} → ${_count(fork, 'image')}'),
                      ),
                      Chip(
                        label: Text(
                            '${tr('Liên kết', 'Links')}: ${_count(original, 'link')} → ${_count(fork, 'link')}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(tr('Bản đề xuất', 'Proposed version'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.brand)),
                  const SizedBox(height: 6),
                  if (after.isEmpty)
                    Text(tr('(không có chữ)', '(no text)'),
                        style: const TextStyle(color: Colors.grey)),
                  for (final l in after)
                    _line(l, added: !beforeSet.contains(l)),
                  if (removed.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(tr('Các dòng bị bỏ khỏi bản gốc', 'Lines removed from the original'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.red)),
                    const SizedBox(height: 6),
                    for (final l in removed) _line(l, removed: true),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    tr(
                      'Khi nhận, bài gốc sẽ lấy toàn bộ nội dung của bản đề xuất (kể cả ảnh và liên kết) và ghi tên người đóng góp.',
                      'Accepting replaces the original with the whole proposed version (images and links included) and credits the contributor.',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                () => ProposalService.decline(p),
                            tr('Đã từ chối đề xuất', 'Proposal declined'),
                          ),
                          child: Text(tr('Từ chối', 'Decline')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand),
                          onPressed: _busy
                              ? null
                              : () => _run(
                                () => ProposalService.accept(p),
                            tr('Đã nhận đề xuất', 'Proposal accepted'),
                          ),
                          child: Text(tr('Nhận đề xuất', 'Accept')),
                        ),
                      ),
                    ],
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