import 'package:flutter/material.dart';

import '../models/space.dart';
import '../services/auto_category.dart';
import '../services/l10n.dart';
import '../services/my_box_service.dart';
import '../services/post_service.dart';
import '../services/social_extras_service.dart' show extrasAgo;
import '../theme/app_theme.dart';

/// Lựa chọn khi đăng một ghi chú thành bài.
class _PostChoice {
  final String spaceId;
  final String visibility; // public, friends, me
  const _PostChoice(this.spaceId, this.visibility);
}

class MyBoxScreen extends StatefulWidget {
  const MyBoxScreen({super.key});

  @override
  State<MyBoxScreen> createState() => _MyBoxScreenState();
}

class _MyBoxScreenState extends State<MyBoxScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await MyBoxService.add(text);
      _ctrl.clear();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _edit(BoxNote n) async {
    final messenger = ScaffoldMessenger.of(context);
    final c = TextEditingController(text: n.text);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Sửa ghi chú', 'Edit note')),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 2000,
          minLines: 3,
          maxLines: 8,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(c.text),
            child: Text(tr('Lưu', 'Save')),
          ),
        ],
      ),
    );
    c.dispose();
    if (text == null) return;
    try {
      await MyBoxService.updateText(n.id, text);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(BoxNote n) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Xóa ghi chú này?', 'Delete this note?')),
        content: Text(
          tr(
            'Ghi chú sẽ bị xóa và không thể khôi phục.',
            'The note will be deleted and cannot be restored.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Xóa', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MyBoxService.delete(n.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// Đăng ghi chú thành bài: AI gợi ý sẵn chủ đề, người dùng xác nhận.
  Future<void> _postAsPost(BoxNote n) async {
    final messenger = ScaffoldMessenger.of(context);
    final blocks = <Map<String, dynamic>>[
      {'type': 'text', 'text': n.text},
    ];

    // Gợi ý chủ đề (AI, dự phòng bằng từ khóa); lỗi thì bỏ qua
    String? guess;
    try {
      final d = await AutoCategory.decide(blocks: blocks);
      if (d.spaceId != null && findSpace(d.spaceId!) != null) {
        guess = d.spaceId;
      }
    } catch (_) {}
    if (!mounted) return;

    final choice = await showDialog<_PostChoice>(
      context: context,
      builder: (ctx) => _PostDialog(initialSpaceId: guess),
    );
    if (choice == null) return;

    try {
      await PostService.createPost(
        spaceId: choice.spaceId,
        blocks: blocks,
        spaceSource: guess == choice.spaceId ? 'ai' : 'user',
        visibility: choice.visibility,
      );
      await MyBoxService.markPosted(n.id);
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Đã đăng thành bài', 'Posted'))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _tile(BoxNote n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(WeaveRadius.card),
        border: Border.all(
          color: n.pinned ? AppColors.brand.withAlpha(120) : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(n.text, style: const TextStyle(height: 1.35)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      extrasAgo(n.createdAt),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (n.pinned)
                      Text(
                        '📌 ${tr('Đã ghim', 'Pinned')}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.brand,
                        ),
                      ),
                    if (n.posted)
                      Text(
                        '✅ ${tr('Đã đăng', 'Posted')}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.brand,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'post':
                  _postAsPost(n);
                case 'pin':
                  MyBoxService.setPinned(n.id, !n.pinned);
                case 'edit':
                  _edit(n);
                case 'delete':
                  _delete(n);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'post',
                child: Text(tr('Đăng thành bài', 'Post as a post')),
              ),
              PopupMenuItem(
                value: 'pin',
                child: Text(
                  n.pinned
                      ? tr('Bỏ ghim', 'Unpin')
                      : tr('Ghim lên đầu', 'Pin to top'),
                ),
              ),
              PopupMenuItem(value: 'edit', child: Text(tr('Sửa', 'Edit'))),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  tr('Xóa', 'Delete'),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Hộp thư của tôi', 'My box'))),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<BoxNote>>(
              stream: MyBoxService.watch(),
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
                          'Nơi lưu ý tưởng, liên kết, nháp bài cho riêng bạn.\nChỉ mình bạn thấy; khi ưng ý, bấm ⋮ để đăng thành bài.',
                          'A private place for ideas, links and drafts.\nOnly you can see it; when ready, tap ⋮ to post it.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [for (final n in items) _tile(n)],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          maxLength: 2000,
                          minLines: 1,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: tr(
                              'Ghi nhanh cho riêng bạn...',
                              'Jot something down for yourself...',
                            ),
                            counterText: '',
                            // Theme đã có viền cho mọi ô nhập: tắt rõ từng trạng thái.
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Lưu ghi chú', 'Save note'),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send, color: AppColors.brand),
                        onPressed: _sending ? null : _add,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hộp thoại chọn chủ đề (nhóm rồi chủ đề nhỏ) và đối tượng xem.
class _PostDialog extends StatefulWidget {
  final String? initialSpaceId;
  const _PostDialog({this.initialSpaceId});

  @override
  State<_PostDialog> createState() => _PostDialogState();
}

class _PostDialogState extends State<_PostDialog> {
  late SpaceGroup _group;
  late Space _space;
  String _visibility = 'public';

  @override
  void initState() {
    super.initState();
    final guessed = widget.initialSpaceId == null
        ? null
        : findSpace(widget.initialSpaceId!);
    final g = guessed == null ? null : groupOfSpace(guessed.id);
    _group = g ?? spaceGroups.first;
    _space = guessed ?? _group.children.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Đăng thành bài', 'Post as a post')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.initialSpaceId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  tr(
                    'Chủ đề được gợi ý tự động, bạn có thể đổi.',
                    'Topic suggested automatically, you can change it.',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            DropdownButtonFormField<SpaceGroup>(
              initialValue: _group,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr('Nhóm chủ đề', 'Topic group'),
              ),
              items: [
                for (final g in spaceGroups)
                  DropdownMenuItem(
                    value: g,
                    child: Text(
                      '${g.emoji} ${tr(g.name, g.nameEn ?? g.name)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (g) {
                if (g == null) return;
                setState(() {
                  _group = g;
                  _space = g.children.first;
                });
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Space>(
              key: ValueKey(_group.id),
              initialValue: _space,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Chủ đề', 'Topic')),
              items: [
                for (final s in _group.children)
                  DropdownMenuItem(
                    value: s,
                    child: Text(
                      '${s.emoji} ${spaceName(s.id, s.name)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (s) {
                if (s != null) setState(() => _space = s);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr('Ai xem được', 'Audience'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'public',
                  child: Text(tr('Công khai', 'Public')),
                ),
                DropdownMenuItem(
                  value: 'friends',
                  child: Text(tr('Bạn bè', 'Friends')),
                ),
                DropdownMenuItem(
                  value: 'me',
                  child: Text(tr('Chỉ mình tôi', 'Only me')),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _visibility = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Hủy', 'Cancel')),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_PostChoice(_space.id, _visibility)),
          child: Text(tr('Đăng', 'Post')),
        ),
      ],
    );
  }
}
