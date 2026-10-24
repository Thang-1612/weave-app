import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/interactions.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
import '../services/account_service.dart';
import '../services/ai_assistant.dart';
import '../services/interaction_service.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../services/text_utils.dart';
import '../services/thread_service.dart';
import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';
import '../widgets/reaction_picker.dart';
import '../widgets/weave_error_view.dart';
import '../widgets/weave_state_views.dart';

/// Màu của đáp án được chọn (cùng màu Teal với nhãn đáp án ở thẻ bài viết).
const _answerGreen = AppColors.teal;

/// Gợi ý khi gõ @: một người bạn hoặc trợ lý AI.
class _Suggestion {
  final String uid;
  final String name;
  final bool isAi;

  const _Suggestion(this.uid, this.name, this.isAi);
}

// Đang gõ dở một thẻ @ ngay trước con trỏ
final _mentionTrigger = RegExp(r'(^|\s)@([^\s@]*)$');

class CommentsScreen extends StatefulWidget {
  final Post post;

  const CommentsScreen({super.key, required this.post});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  late final Stream<Post?> _postStream = PostService.watchPost(widget.post);
  // Không để final: nút Thử lại gán stream mới để tải lại thật.
  late Stream<List<Comment>> _commentsStream = _watchComments();

  Stream<List<Comment>> _watchComments() => CommentService.watchComments(
    widget.post.id,
    collection: widget.post.collection,
  );

  final _text = TextEditingController();
  final _focus = FocusNode();
  final List<Mention> _mentions = [];
  final Set<String> _expanded = {}; // bình luận gốc đang mở hết phản hồi

  late Post _post = widget.post;
  Comment? _replyTo;
  List<UserProfile> _friends = [];
  List<_Suggestion> _suggestions = [];
  bool _sending = false;
  bool _aiThinking = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
    _loadFriends();
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final list = await ThreadService.loadFriends();
      if (mounted) setState(() => _friends = list);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Gõ @ để tag bạn bè hoặc gọi AI
  // ---------------------------------------------------------------------

  void _onTextChanged() {
    final value = _text.value;
    final len = value.text.length;
    final cursor = value.selection.isValid
        ? value.selection.baseOffset.clamp(0, len).toInt()
        : len;
    final match = _mentionTrigger.firstMatch(value.text.substring(0, cursor));

    final next = <_Suggestion>[];
    if (match != null) {
      final q = normalizeVi(match.group(2) ?? '');
      if ('ai'.startsWith(q)) next.add(const _Suggestion('ai', 'AI', true));
      for (final f in _friends) {
        final tokens = normalizeVi(f.name).split(RegExp(r'\s+'));
        if (q.isEmpty || tokens.any((t) => t.startsWith(q))) {
          next.add(_Suggestion(f.uid, f.name, false));
        }
        if (next.length >= 6) break;
      }
    }
    if (mounted) setState(() => _suggestions = next);
  }

  void _pick(_Suggestion s) {
    final value = _text.value;
    final len = value.text.length;
    final cursor = value.selection.isValid
        ? value.selection.baseOffset.clamp(0, len).toInt()
        : len;
    final before = value.text.substring(0, cursor);
    final after = value.text.substring(cursor);
    final match = _mentionTrigger.firstMatch(before);
    if (match == null) return;

    final atIndex = match.end - (match.group(2) ?? '').length - 1;
    final inserted = '@${s.name} ';
    _text.value = TextEditingValue(
      text: before.substring(0, atIndex) + inserted + after,
      selection: TextSelection.collapsed(offset: atIndex + inserted.length),
    );
    if (!_mentions.any((m) => m.uid == s.uid)) {
      _mentions.add(Mention(s.uid, s.name));
    }
    _focus.requestFocus();
  }

  // ---------------------------------------------------------------------
  // Trả lời
  // ---------------------------------------------------------------------

  void _startReply(Comment c) {
    final mention = c.isAi
        ? const Mention('ai', 'AI')
        : Mention(c.authorId, c.authorName);
    final tag = '@${mention.name} ';

    var text = _text.text;
    if (!text.contains(tag)) text = '$tag$text';
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (!_mentions.any((m) => m.uid == mention.uid)) _mentions.add(mention);

    setState(() => _replyTo = c);
    _focus.requestFocus();
  }

  void _cancelReply() => setState(() => _replyTo = null);

  /// Tên hiển thị của tác giả: bình luận của AI luôn theo ngôn ngữ đang dùng.
  String _displayName(Comment c) =>
      c.isAi ? tr('Trợ lý AI', 'AI assistant') : c.authorName;

  // ---------------------------------------------------------------------
  // Câu hỏi: chọn đáp án
  // ---------------------------------------------------------------------

  /// Tác giả câu hỏi chọn được bình luận gốc của người khác làm đáp án.
  bool _canAccept(Comment c) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    return _post.isQuestion &&
        me != null &&
        _post.authorId == me &&
        !c.isReply &&
        c.authorId != me;
  }

  Future<void> _toggleAnswer(Comment c) async {
    final messenger = ScaffoldMessenger.of(context);
    final wasAccepted = _post.acceptedCommentId == c.id;
    try {
      if (wasAccepted) {
        await PostService.clearAnswer(_post);
        messenger.showSnackBar(
          SnackBar(content: Text(tr('Đã bỏ chọn đáp án', 'Answer unmarked'))),
        );
      } else {
        await PostService.acceptAnswer(
          _post,
          commentId: c.id,
          authorId: c.isAi ? '' : c.authorId,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(tr('Đã chọn làm đáp án', 'Marked as the answer')),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ---------------------------------------------------------------------
  // Gửi bình luận và gọi AI
  // ---------------------------------------------------------------------

  Future<void> _send() async {
    final raw = _text.text.trim();
    if (raw.isEmpty || _sending) return;
    final messenger = ScaffoldMessenger.of(context);
    final post = _post;
    final replyTo = _replyTo;

    // Chỉ giữ các thẻ tên còn xuất hiện trong nội dung
    final mentions = <Mention>[
      for (final m in _mentions)
        if (raw.contains('@${m.name}')) m,
    ];
    // Gõ tay "@AI" cũng gọi được AI
    final typedAi = RegExp(r'(^|\s)@ai\b', caseSensitive: false).hasMatch(raw);
    if (typedAi && !mentions.any((m) => m.uid == 'ai')) {
      mentions.add(const Mention('ai', 'AI'));
    }
    final callsAi = mentions.any((m) => m.uid == 'ai');

    setState(() => _sending = true);
    try {
      final id = await ThreadService.addComment(
        post: post,
        text: raw,
        mentions: mentions,
        replyTo: replyTo,
      );
      _text.clear();
      _mentions.clear();

      final topId = replyTo == null
          ? ''
          : (replyTo.parentId.isNotEmpty ? replyTo.parentId : replyTo.id);
      if (mounted) {
        setState(() {
          _replyTo = null;
          _suggestions = [];
          if (topId.isNotEmpty) _expanded.add(topId);
        });
      }

      if (callsAi) _askAi(post, raw, id, replyTo);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${tr('Không gửi được', 'Could not send')}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _askAi(
      Post post,
      String rawText,
      String commentId,
      Comment? replyTo,
      ) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Câu trả lời của AI nằm trong chuỗi của bình luận vừa gửi
    final topId = replyTo == null
        ? commentId
        : (replyTo.parentId.isNotEmpty ? replyTo.parentId : replyTo.id);
    final question = rawText
        .replaceAll(RegExp(r'@ai\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (mounted) {
      setState(() {
        _aiThinking = true;
        _expanded.add(topId);
      });
    }

    try {
      final answer = await AiAssistant.reply(
        post: post,
        parentText: replyTo?.text,
        question: question,
      );
      if (answer == null || answer.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'AI hiện chưa trả lời được, bạn thử lại sau nhé',
                'The AI cannot answer right now, please try again later',
              ),
            ),
          ),
        );
        return;
      }
      await ThreadService.addAiComment(
        post: post,
        text: answer,
        topId: topId,
        askerUid: user.uid,
        askerName: displayNameOf(user),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${tr('AI gặp lỗi', 'AI error')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _aiThinking = false);
    }
  }

  // ---------------------------------------------------------------------
  // Xóa và báo cáo
  // ---------------------------------------------------------------------

  Future<void> _delete(Comment c) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Xóa bình luận?', 'Delete comment?')),
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
      await CommentService.deleteComment(_post, c);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${tr('Không xóa được', 'Could not delete')}: $e'),
        ),
      );
    }
  }

  Future<void> _report(Comment c) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_ReportResult>(
      context: context,
      builder: (_) => const _ReportDialog(),
    );
    if (result == null) return;
    try {
      final ok = await ThreadService.reportComment(
        post: _post,
        comment: c,
        reason: result.reason,
        note: result.note,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? tr(
              'Đã gửi báo cáo. Cảm ơn bạn đã giúp cộng đồng an toàn hơn',
              'Report sent. Thank you for helping keep the community safe',
            )
                : tr(
              'Không gửi được báo cáo (có thể bạn đã báo cáo bình luận này rồi)',
              'Could not send the report (you may have already reported this comment)',
            ),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${tr('Không gửi được', 'Could not send')}: $e'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------

  List<Widget> _buildThreads(List<Comment> comments) {
    final tops = comments.where((c) => !c.isReply).toList();
    // Đáp án được chọn luôn nằm đầu danh sách
    final acceptedId = _post.acceptedCommentId;
    if (acceptedId != null) {
      final idx = tops.indexWhere((c) => c.id == acceptedId);
      if (idx > 0) tops.insert(0, tops.removeAt(idx));
    }
    final repliesBy = <String, List<Comment>>{};
    for (final c in comments.where((c) => c.isReply)) {
      repliesBy.putIfAbsent(c.parentId, () => []).add(c);
    }
    final topIds = tops.map((c) => c.id).toSet();

    Widget tile(Comment c, {required bool isReply}) {
      return _CommentTile(
        key: ValueKey('c_${c.id}'),
        post: _post,
        comment: c,
        displayName: _displayName(c),
        isReply: isReply,
        isAccepted: !isReply && c.id == acceptedId,
        canAccept: _canAccept(c),
        onReply: () => _startReply(c),
        onDelete: () => _delete(c),
        onReport: () => _report(c),
        onToggleAnswer: () => _toggleAnswer(c),
      );
    }

    final widgets = <Widget>[];
    for (final top in tops) {
      widgets.add(tile(top, isReply: false));

      final replies = repliesBy[top.id] ?? const <Comment>[];
      final showAll = _expanded.contains(top.id) || replies.length <= 2;
      final visible = showAll ? replies : replies.take(2).toList();
      for (final r in visible) {
        widgets.add(tile(r, isReply: true));
      }
      if (!showAll) {
        final more = replies.length - 2;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded.add(top.id)),
                child: Text(
                  tr(
                    'Xem thêm $more phản hồi',
                    more == 1 ? 'View 1 more reply' : 'View $more more replies',
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // Phản hồi của một bình luận gốc đã bị xóa
    for (final entry in repliesBy.entries) {
      if (topIds.contains(entry.key)) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Text(
            tr('Bình luận gốc đã bị xóa', 'The original comment was deleted'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
      for (final r in entry.value) {
        widgets.add(tile(r, isReply: true));
      }
    }
    return widgets;
  }

  Widget _buildSuggestions() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      // Material trong suốt để ListTile vẽ được hiệu ứng chạm trên nền Container
      child: Material(
        color: Colors.transparent,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            for (final s in _suggestions)
              ListTile(
                dense: true,
                leading: s.isAi
                    ? Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.gradient,
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                )
                    : CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.soft,
                  child: Text(
                    initialOf(s.name),
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  s.isAi ? 'AI' : s.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: s.isAi
                    ? Text(
                  tr(
                    'Gọi trợ lý AI trả lời bình luận này',
                    'Ask the AI assistant to reply to this comment',
                  ),
                )
                    : null,
                onTap: () => _pick(s),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final reply = _replyTo;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_suggestions.isNotEmpty) _buildSuggestions(),
                if (reply != null)
                  Container(
                    width: double.infinity,
                    color: AppColors.background,
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr(
                              'Đang trả lời ${_displayName(reply)}',
                              'Replying to ${_displayName(reply)}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _cancelReply,
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          focusNode: _focus,
                          maxLength: 500,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: _post.isQuestion
                                ? tr(
                              'Viết câu trả lời... (gõ @ để tag bạn bè hoặc gọi AI)',
                              'Write an answer... (type @ to tag a friend or call the AI)',
                            )
                                : tr(
                              'Viết bình luận... (gõ @ để tag bạn bè hoặc gọi AI)',
                              'Write a comment... (type @ to tag a friend or call the AI)',
                            ),
                            counterText: '',
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            // Theme có viền cho mọi ô nhập nên phải đặt rõ cả
                            // enabledBorder và focusedBorder cho ô dạng viên thuốc này.
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _sending
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                          : IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppColors.brand,
                        ),
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Bình luận', 'Comments'))),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: StreamBuilder<List<Comment>>(
                  stream: _commentsStream,
                  builder: (context, commentsSnap) {
                    return StreamBuilder<Post?>(
                      stream: _postStream,
                      builder: (context, postSnap) {
                        final deleted =
                            postSnap.hasData && postSnap.data == null;
                        if (postSnap.data != null) _post = postSnap.data!;
                        // Ẩn bình luận của người bị chặn hoặc tắt tiếng
                        final comments = (commentsSnap.data ?? const <Comment>[])
                            .where(
                              (c) =>
                          !UserPrefs.instance.isHiddenAuthor(c.authorId),
                        )
                            .toList();

                        if (deleted) {
                          return WeaveEmptyView(
                            icon: Icons.delete_outline,
                            title: tr(
                              'Bài viết này đã bị xóa',
                              'This post has been deleted',
                            ),
                          );
                        }

                        if (commentsSnap.hasError) {
                          debugPrint(
                            'CommentsScreen stream error: ${commentsSnap.error}',
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.only(bottom: 12),
                          children: [
                            PostCard(post: _post, openCommentsOnTap: false),
                            if (commentsSnap.hasError)
                              WeaveErrorView(
                                message: tr(
                                  'Không tải được bình luận.',
                                  'Could not load comments.',
                                ),
                                onRetry: () => setState(
                                      () => _commentsStream = _watchComments(),
                                ),
                              )
                            else if (!commentsSnap.hasData)
                              const WeaveLoadingView()
                            else if (comments.isEmpty)
                                WeaveEmptyView(
                                  icon: Icons.chat_bubble_outline,
                                  title: _post.isQuestion
                                      ? tr(
                                    'Chưa có câu trả lời nào.',
                                    'No answers yet.',
                                  )
                                      : tr(
                                    'Chưa có bình luận nào.',
                                    'No comments yet.',
                                  ),
                                  description: tr(
                                    'Hãy là người đầu tiên!',
                                    'Be the first!',
                                  ),
                                )
                              else
                                ..._buildThreads(comments),
                            if (_aiThinking)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  52,
                                  12,
                                  14,
                                  0,
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      tr(
                                        'Trợ lý AI đang soạn câu trả lời...',
                                        'The AI assistant is writing a reply...',
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }
}

/// Một bình luận: avatar, nội dung (tô màu thẻ @), cảm xúc, trả lời, menu.
/// Với câu hỏi: tác giả chọn đáp án, đáp án được viền xanh và gắn nhãn.
class _CommentTile extends StatelessWidget {
  final Post post;
  final Comment comment;
  final String displayName;
  final bool isReply;
  final bool isAccepted;
  final bool canAccept;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onReport;
  final VoidCallback onToggleAnswer;

  const _CommentTile({
    super.key,
    required this.post,
    required this.comment,
    required this.displayName,
    required this.isReply,
    required this.isAccepted,
    required this.canAccept,
    required this.onReply,
    required this.onDelete,
    required this.onReport,
    required this.onToggleAnswer,
  });

  Widget _avatar(double radius) {
    if (comment.isAi) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.gradient,
        ),
        child: Icon(
          Icons.smart_toy_rounded,
          color: Colors.white,
          size: radius * 1.1,
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.soft,
      child: Text(
        initialOf(comment.authorName),
        style: TextStyle(
          color: AppColors.brand,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  Widget _summaryChip() {
    final entries = comment.reactionSummary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(3).map((e) => e.key).join('');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '${top.isEmpty ? '👍' : top} ${comment.reactions}',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _answerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _answerGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '✅ ${tr('Đáp án', 'Answer')}',
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: _answerGreen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final mine = comment.authorId == me;
    final asked = comment.requestedBy.isNotEmpty && comment.requestedBy == me;
    final canDelete = (mine || asked) && !isAccepted;
    final canReport = !mine && !asked;
    final radius = isReply ? 14.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(isReply ? 52 : 14, 6, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(radius),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isAccepted ? _answerGreen : AppColors.border,
                      width: isAccepted ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (comment.isAi) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.soft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'AI',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                          ],
                          if (isAccepted) ...[
                            const SizedBox(width: 6),
                            _answerBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      _MentionText(
                        text: comment.text,
                        mentions: comment.mentions,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Row(
                    children: [
                      // Wrap để các nút tự xuống dòng trên màn hình hẹp
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              formatTimeAgo(comment.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            CommentReactionButton(post: post, comment: comment),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: onReply,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: _ReplyLabel(),
                              ),
                            ),
                            if (canAccept)
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: onToggleAnswer,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    isAccepted
                                        ? tr('Bỏ chọn đáp án', 'Unmark answer')
                                        : tr(
                                      'Chọn làm đáp án',
                                      'Mark as answer',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _answerGreen,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (comment.reactions > 0) _summaryChip(),
                      if (canDelete || canReport)
                        SizedBox(
                          width: 34,
                          height: 28,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: const Icon(Icons.more_horiz),
                            onSelected: (v) {
                              if (v == 'delete') onDelete();
                              if (v == 'report') onReport();
                            },
                            itemBuilder: (_) => [
                              if (canReport)
                                PopupMenuItem(
                                  value: 'report',
                                  child: Text(
                                    tr('Báo cáo bình luận', 'Report comment'),
                                  ),
                                ),
                              if (canDelete)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    tr('Xóa bình luận', 'Delete comment'),
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn "Trả lời" (tách riêng để dùng const cho InkWell bên trên).
class _ReplyLabel extends StatelessWidget {
  const _ReplyLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      tr('Trả lời', 'Reply'),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Nút Thích của bình luận: dùng chung cách thả cảm xúc với bài viết.
class CommentReactionButton extends StatefulWidget {
  final Post post;
  final Comment comment;

  const CommentReactionButton({
    super.key,
    required this.post,
    required this.comment,
  });

  @override
  State<CommentReactionButton> createState() => _CommentReactionButtonState();
}

class _CommentReactionButtonState extends State<CommentReactionButton> {
  late final Stream<String?> _mine = ThreadService.watchMyCommentReaction(
    widget.post.id,
    widget.comment.id,
    collection: widget.post.collection,
  );

  @override
  Widget build(BuildContext context) {
    return ReactionTrigger(
      mine: _mine,
      borderRadius: BorderRadius.circular(8),
      onApply: (emoji) =>
          ThreadService.setCommentReaction(widget.post, widget.comment, emoji),
      builder: (context, mine) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            mine != null ? '$mine ${reactionLabel(mine)}' : tr('Thích', 'Like'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: mine != null ? AppColors.brand : AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

/// Văn bản bình luận có tô màu các thẻ @tên.
class _MentionText extends StatelessWidget {
  final String text;
  final List<Mention> mentions;

  const _MentionText({required this.text, required this.mentions});

  static const _style = TextStyle(height: 1.3, color: AppColors.textPrimary);

  @override
  Widget build(BuildContext context) {
    if (mentions.isEmpty) return Text(text, style: _style);

    final names = mentions.map((m) => '@${m.name}').toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final re = RegExp(names.map(RegExp.escape).join('|'));

    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(0),
          style: const TextStyle(
            color: AppColors.brand,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return Text.rich(TextSpan(style: _style, children: spans));
  }
}

class _ReportResult {
  final String reason;
  final String note;

  const _ReportResult(this.reason, this.note);
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WeaveRadius.card),
      ),
      title: Text(tr('Báo cáo bình luận', 'Report comment')),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in ThreadService.reportReasons)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _reason == r
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _reason == r
                        ? AppColors.brand
                        : AppColors.textSecondary,
                  ),
                  title: Text(reportReasonLabel(r)),
                  onTap: () => setState(() => _reason = r),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: tr(
                    'Mô tả thêm (không bắt buộc)',
                    'Add details (optional)',
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(WeaveRadius.control),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(WeaveRadius.control),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(WeaveRadius.control),
                    borderSide: const BorderSide(color: AppColors.brand),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Hủy', 'Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: _reason == null
              ? null
              : () => Navigator.of(
            context,
          ).pop(_ReportResult(_reason!, _note.text.trim())),
          child: Text(tr('Gửi báo cáo', 'Send report')),
        ),
      ],
    );
  }
}