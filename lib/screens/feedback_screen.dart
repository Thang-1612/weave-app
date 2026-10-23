import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/feedback_service.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  final Post post;
  const FeedbackScreen({super.key, required this.post});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _public = true;
  bool _sending = false;

  /// Đang trả lời: góp ý gốc của chuỗi và tên người được trả lời.
  FeedbackItem? _replyRoot;
  String _replyToName = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return tr('vừa xong', 'just now');
    if (d.inHours < 1) {
      return tr('${d.inMinutes} phút trước', '${d.inMinutes} min ago');
    }
    if (d.inDays < 1) return tr('${d.inHours} giờ trước', '${d.inHours} h ago');
    return tr('${d.inDays} ngày trước', '${d.inDays} d ago');
  }

  void _startReply(FeedbackItem root, FeedbackItem target) {
    setState(() {
      _replyRoot = root;
      _replyToName = target.authorName;
    });
    _focus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyRoot = null;
      _replyToName = '';
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final messenger = ScaffoldMessenger.of(context);
    final root = _replyRoot;
    final isPublic = root?.isPublic ?? _public;
    setState(() => _sending = true);
    try {
      await FeedbackService.send(
        widget.post,
        text,
        isPublic: isPublic,
        replyRoot: root,
        replyToName: _replyToName,
      );
      _ctrl.clear();
      if (root != null) _cancelReply();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            root != null
                ? tr('Đã gửi trả lời', 'Reply sent')
                : (isPublic
                      ? tr('Đã đăng góp ý công khai', 'Public feedback posted')
                      : tr('Đã lưu góp ý riêng tư', 'Private feedback saved')),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(FeedbackItem f) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(tr('Xóa góp ý này?', 'Delete this feedback?')),
          content: Text(
            tr(
              'Góp ý sẽ bị xóa và không thể khôi phục.',
              'This feedback will be deleted and cannot be restored.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('Hủy', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr('Xóa', 'Delete')),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await FeedbackService.delete(widget.post, f.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// [root] là góp ý gốc của chuỗi (chính nó nếu f là góp ý gốc).
  Widget _tile(FeedbackItem f, FeedbackItem root, String? me) {
    final scheme = Theme.of(context).colorScheme;
    final canDelete = f.authorId == me;
    final byPostAuthor = f.authorId == widget.post.authorId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.soft,
                child: Text(
                  f.authorName.isEmpty ? '?' : f.authorName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  f.authorName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                f.isPublic
                    ? '🌐 ${tr('Công khai', 'Public')}'
                    : (byPostAuthor
                          ? '🔒 ${tr('Chỉ tác giả thấy', 'Author only')}'
                          : '🔒 ${tr('Riêng tư', 'Private')}'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (canDelete)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: tr('Xóa', 'Delete'),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: scheme.error,
                  ),
                  onPressed: () => _confirmDelete(f),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (f.isReply && f.replyToName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '↩ ${f.replyToName}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(f.text, style: const TextStyle(height: 1.35)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _ago(f.createdAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (me != null) ...[
                const SizedBox(width: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _startReply(root, f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      tr('Trả lời', 'Reply'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Xếp góp ý gốc (mới nhất trước), mỗi góp ý kèm các trả lời (cũ đến mới)
  /// thụt vào một cấp. Trả lời mà góp ý gốc đã bị xóa thì không hiện.
  List<Widget> _buildThreads(List<FeedbackItem> items, String? me) {
    final roots = items.where((f) => !f.isReply).toList();
    final replies = <String, List<FeedbackItem>>{};
    for (final f in items.where((f) => f.isReply)) {
      replies.putIfAbsent(f.parentId, () => []).add(f);
    }
    for (final l in replies.values) {
      l.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return [
      for (final r in roots) ...[
        _tile(r, r, me),
        for (final c in replies[r.id] ?? const <FeedbackItem>[])
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: _tile(c, r, me),
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = widget.post.authorId == me;
    final root = _replyRoot;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Góp ý cho bài viết', 'Feedback'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<FeedbackItem>>(
                  stream: FeedbackService.watch(widget.post),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('${snap.error}'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snap.data!;
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          tr('Chưa có góp ý nào', 'No feedback yet'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: _buildThreads(items, me),
                    );
                  },
                ),
              ),
              if (me != null)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: const Border(
                        top: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (root != null)
                          // Đang trả lời: chế độ theo góp ý gốc, không chọn lại
                          Row(
                            children: [
                              const Icon(
                                Icons.reply,
                                size: 16,
                                color: AppColors.brand,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${tr('Đang trả lời', 'Replying to')} $_replyToName'
                                  ' · ${root.isPublic ? tr('công khai', 'public') : tr('riêng tư', 'private')}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: tr('Hủy trả lời', 'Cancel reply'),
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: _cancelReply,
                              ),
                            ],
                          )
                        else ...[
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: true,
                                icon: const Icon(Icons.public, size: 16),
                                label: Text(tr('Công khai', 'Public')),
                              ),
                              ButtonSegment(
                                value: false,
                                icon: const Icon(Icons.lock_outline, size: 16),
                                label: Text(tr('Riêng tư', 'Private')),
                              ),
                            ],
                            selected: {_public},
                            onSelectionChanged: (s) =>
                                setState(() => _public = s.first),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _public
                                  ? tr(
                                      'Mọi người đều thấy góp ý này',
                                      'Everyone can see this',
                                    )
                                  : isOwner
                                  ? tr(
                                      'Chỉ mình bạn thấy',
                                      'Only you can see this',
                                    )
                                  : tr(
                                      'Chỉ tác giả bài và bạn thấy',
                                      'Only the author and you can see this',
                                    ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                focusNode: _focus,
                                maxLength: 500,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: root != null
                                      ? tr(
                                          'Viết câu trả lời...',
                                          'Write your reply...',
                                        )
                                      : tr(
                                          'Viết góp ý của bạn...',
                                          'Write your feedback...',
                                        ),
                                  counterText: '',
                                  // Theme đã có viền cho mọi ô nhập, nên ô này
                                  // phải tắt rõ từng trạng thái.
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: tr('Gửi', 'Send'),
                              icon: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send,
                                      color: AppColors.brand,
                                    ),
                              onPressed: _sending ? null : _send,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
