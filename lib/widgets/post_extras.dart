import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../screens/block_notes_screen.dart';
import '../screens/versions_screen.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../services/proposal_service.dart';
import '../services/social_extras_service.dart';
import '../theme/app_theme.dart';
import 'proposal_status.dart';
import 'text_prompt.dart';
import '../screens/feedback_screen.dart';

/// Các tính năng thêm dưới mỗi bài công khai: bài sống (dòng thời gian cập
/// nhật), lời cảm ơn, ghi chú theo khối, đề xuất sửa bài gốc (hoặc gộp nhánh
/// vào bài gốc của chính mình), lịch sử phiên bản, người đóng góp và nhãn tự
/// hết hạn. Chỉ hiện khi có ích.
class PostExtras extends StatelessWidget {
  final Post post;
  const PostExtras({super.key, required this.post});

  Future<void> _addUpdate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await showTextPrompt(
      context,
      title: tr('Thêm cập nhật cho bài', 'Add an update to this post'),
      hint: tr('Hôm nay mình đã làm được gì?', 'What progress did you make?'),
      action: tr('Đăng cập nhật', 'Post update'),
      maxLen: 600,
    );
    if (text == null) return;
    try {
      await LivePostService.addUpdate(post, text);
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Đã thêm cập nhật', 'Update added'))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _thank(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final note = await showTextPrompt(
      context,
      title: tr('Gửi lời cảm ơn', 'Send a thank-you'),
      hint: tr(
        'Bài này đã giúp bạn điều gì? (chỉ tác giả thấy)',
        'How did this post help you? (only the author sees it)',
      ),
      action: tr('Gửi', 'Send'),
      maxLen: 200,
      allowEmpty: true,
    );
    if (note == null) return;
    try {
      await ThanksService.send(post, note);
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Đã gửi lời cảm ơn', 'Thank-you sent'))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// Bài gốc của người khác: gửi đề xuất. Bài gốc của chính mình: gộp thẳng.
  Future<void> _proposeOrMerge(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final originalId = post.forkedFrom;
    if (originalId == null) return;

    final original = await PostService.getPost(originalId);
    if (original == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('Bài gốc không còn tồn tại',
              'The original post is gone')),
        ),
      );
      return;
    }
    if (!context.mounted) return;

    final me = FirebaseAuth.instance.currentUser?.uid;
    if (original.authorId == me) {
      // Bài gốc là của chính mình: không cần đề xuất, gộp thẳng
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(tr('Gộp vào bài gốc?', 'Merge into the original?')),
          content: Text(tr(
            'Bài gốc là của bạn nên không cần đề xuất. Nội dung bài gốc sẽ được thay bằng bản này. Bản cũ được lưu trong Lịch sử phiên bản, bạn vẫn khôi phục được.',
            'The original is your own post, so no proposal is needed. Its content will be replaced with this version. The old one is kept in Version history, so you can restore it.',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('Hủy', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr('Gộp', 'Merge')),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await ProposalService.mergeIntoOriginal(post);
        messenger.showSnackBar(
          SnackBar(
            content: Text(tr('Đã gộp vào bài gốc', 'Merged into the original')),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }

    final note = await showTextPrompt(
      context,
      title: tr('Gửi đề xuất cho bài gốc', 'Send a proposal to the original'),
      hint: tr('Bạn đã thay đổi điều gì và vì sao?',
          'What did you change and why?'),
      action: tr('Gửi đề xuất', 'Send proposal'),
      maxLen: 300,
      allowEmpty: true,
    );
    if (note == null) return;
    try {
      await ProposalService.send(post, note);
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr(
            'Đã gửi đề xuất cho ${post.forkedFromAuthor ?? 'tác giả bài gốc'}',
            'Proposal sent to ${post.forkedFromAuthor ?? 'the original author'}',
          )),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _note(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  String _expiryText() {
    final e = post.expiresAt!;
    if (post.isExpired) {
      return tr('Đã hết hạn, chỉ mình bạn còn thấy bài này',
          'Expired, only you can still see this post');
    }
    final left = e.difference(DateTime.now());
    final when = left.inHours < 24
        ? tr('${left.inHours + 1} giờ nữa', 'in ${left.inHours + 1} h')
        : tr('${left.inDays} ngày nữa', 'in ${left.inDays} d');
    return tr('Tự ẩn khỏi mọi người $when', 'Hides from everyone $when');
  }

  @override
  Widget build(BuildContext context) {
    if (post.collection != 'posts') return const SizedBox.shrink();
    final me = FirebaseAuth.instance.currentUser?.uid;
    final isMine = post.authorId == me;

    // Nhánh của chính tác giả bài gốc (đoán theo tên, lúc bấm sẽ kiểm tra lại)
    final likelySelfFork = post.forkedFromAuthor != null &&
        post.forkedFromAuthor == post.authorName;

    final buttons = <Widget>[
      if (isMine)
        _chip(Icons.update, tr('Thêm cập nhật', 'Add update'),
                () => _addUpdate(context)),
      if (isMine && post.forkedFrom != null)
        _chip(
          Icons.call_merge,
          likelySelfFork
              ? tr('Gộp vào bài gốc', 'Merge into original')
              : tr('Gửi đề xuất cho bài gốc', 'Propose to original'),
              () => _proposeOrMerge(context),
        ),
      if (isMine && (post.contributors.isNotEmpty || post.updateCount > 0))
        _chip(
          Icons.history,
          tr('Lịch sử phiên bản', 'Version history'),
              () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => VersionsScreen(post: post)),
          ),
        ),
      if (me != null)
        _chip(
          Icons.rate_review_outlined,
          tr('Góp ý', 'Feedback'),
              () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FeedbackScreen(post: post)),
          ),
        ),
      if (!isMine && me != null)
        _chip(Icons.favorite_border, tr('Cảm ơn', 'Thank'),
                () => _thank(context)),
      if (post.blocks.isNotEmpty)
        _chip(
          Icons.forum_outlined,
          tr('Ghi chú theo khối', 'Block notes'),
              () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BlockNotesScreen(post: post)),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.contributors.isNotEmpty)
          _note(
            Icons.handshake_outlined,
            '${tr('Có đóng góp từ', 'Contributions from')}: ${post.contributors.join(', ')}',
          ),
        if (isMine && post.forkedFrom != null) ProposalStatus(post: post),
        if (isMine && post.expiresAt != null)
          _note(Icons.hourglass_bottom, _expiryText()),
        // Tác giả thấy cả mục tự sinh; người khác chỉ thấy cập nhật tác giả tự viết
        if ((isMine ? post.updateCount : post.publicUpdateCount) > 0)
          LiveTimeline(post: post),
        if (buttons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(spacing: 2, children: buttons),
          ),
      ],
    );
  }
}

/// Dòng thời gian cập nhật của một bài sống. Chỉ tải nội dung khi mở.
class LiveTimeline extends StatefulWidget {
  final Post post;
  const LiveTimeline({super.key, required this.post});

  @override
  State<LiveTimeline> createState() => _LiveTimelineState();
}

class _LiveTimelineState extends State<LiveTimeline> {
  bool _open = false;
  bool _loading = false;
  List<LiveUpdate>? _items;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await LivePostService.loadUpdates(widget.post);
      if (mounted) setState(() => _items = r);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant LiveTimeline old) {
    super.didUpdateWidget(old);
    if (_open && old.post.updateCount != widget.post.updateCount) _load();
  }

  void _toggle(bool following) {
    setState(() => _open = !_open);
    if (_open) {
      if (_items == null) _load();
      if (following) LivePostService.markSeen(widget.post.id);
    }
  }

  Widget _entry(String when, String text, {bool dim = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            when,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.brand,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: TextStyle(
              height: 1.35,
              color: dim ? Colors.grey : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(bool isMine, bool following, bool unseen) {
    final p = widget.post;
    // Tác giả: số tổng (cả mục tự sinh). Người khác: chỉ cập nhật tự viết.
    final count = isMine ? p.updateCount : p.publicUpdateCount;
    final last = isMine ? p.lastUpdateAt : p.lastPublicUpdateAt;
    final summary = '$count ${tr('cập nhật', 'updates')}'
        '${last != null ? ' · ${tr('mới nhất', 'latest')} ${extrasAgo(last)}' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _toggle(following),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.update,
                              size: 18, color: AppColors.brand),
                          if (unseen)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          summary,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        _open ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!isMine)
              IconButton(
                tooltip: following
                    ? tr('Bỏ theo dõi', 'Unfollow')
                    : tr('Theo dõi cập nhật', 'Follow updates'),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  following
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  size: 20,
                  color: following ? AppColors.brand : Colors.grey.shade700,
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await LivePostService.setFollow(p.id, !following);
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
              ),
          ],
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(left: 8, bottom: 4),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.brand.withAlpha(89),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                // Mục do hệ thống tự sinh (gộp nhánh, nhận đề xuất, khôi phục)
                // chỉ tác giả thấy
                for (final u in (_items ?? const <LiveUpdate>[])
                    .where((u) => isMine || u.kind == 'manual'))
                  _entry(extrasAgo(u.createdAt), u.text),
                _entry(
                  extrasAgo(p.createdAt),
                  tr('Đăng bài', 'Posted'),
                  dim: true,
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final isMine = widget.post.authorId == me;
    if (isMine || me == null) return _body(isMine, false, false);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: LivePostService.watchFollow(widget.post.id),
      builder: (context, snap) {
        final data = snap.data;
        final following = data != null;
        // Chấm đỏ chỉ sáng khi tác giả đăng cập nhật tự viết
        final last = widget.post.lastPublicUpdateAt;
        final seen = data?['lastSeenAt'];
        final unseen = following &&
            last != null &&
            seen is Timestamp &&
            last.isAfter(seen.toDate());
        return _body(false, following, unseen);
      },
    );
  }
}