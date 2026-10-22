import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/interactions.dart';
import '../../models/post.dart';
import '../../services/activity_service.dart';
import '../../services/interaction_service.dart';
import '../../services/l10n.dart';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import '../comments_screen.dart';

/// Bộ nhớ tạm cho bài viết đã tải, dùng chung giữa các tab.
class _PostCache {
  static final Map<String, Future<Post?>> _posts = {};

  static Future<Post?> post(String id) =>
      _posts.putIfAbsent(id, () => PostService.getPost(id));

  static void clear() => _posts.clear();
}

String _snippet(Post p) {
  final t = p.text.trim().replaceAll('\n', ' ');
  if (t.isEmpty) return tr('[Ảnh hoặc liên kết]', '[Image or link]');
  return t.length > 80 ? '${t.substring(0, 80)}…' : t;
}

DateTime _date(Object? v) => v is Timestamp ? v.toDate() : DateTime.now();

class _ReactionItem {
  final String postId;
  final String? commentId;
  final String emoji;
  final DateTime createdAt;

  const _ReactionItem(this.postId, this.commentId, this.emoji, this.createdAt);
}

class _CommentItem {
  final String postId;
  final Comment comment;

  const _CommentItem(this.postId, this.comment);
}

class _ShareItem {
  final String postId;
  final DateTime createdAt;

  const _ShareItem(this.postId, this.createdAt);
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<List<_ReactionItem>> _loadReactions() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await FirebaseFirestore.instance
        .collectionGroup('reactions')
        .where('userId', isEqualTo: uid)
        .limit(200)
        .get();

    final items = <_ReactionItem>[];
    for (final d in snap.docs) {
      final segs = d.reference.path.split('/');
      final emoji = d.data()['emoji'] as String? ?? '👍';
      final at = _date(d.data()['createdAt']);
      if (segs.length == 4 &&
          (segs[0] == 'posts' || segs[0] == 'friend_posts')) {
        items.add(_ReactionItem(segs[1], null, emoji, at));
      } else if (segs.length == 6 &&
          (segs[0] == 'posts' || segs[0] == 'friend_posts') &&
          segs[2] == 'comments') {
        items.add(_ReactionItem(segs[1], segs[3], emoji, at));
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<List<_CommentItem>> _loadComments() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await FirebaseFirestore.instance
        .collectionGroup('comments')
        .where('authorId', isEqualTo: uid)
        .limit(200)
        .get();

    final items = <_CommentItem>[];
    for (final d in snap.docs) {
      final segs = d.reference.path.split('/');
      if (segs.length != 4 ||
          (segs[0] != 'posts' && segs[0] != 'friend_posts')) {
        continue;
      }
      items.add(_CommentItem(segs[1], Comment.fromDoc(d)));
    }
    items.sort((a, b) => b.comment.createdAt.compareTo(a.comment.createdAt));
    return items;
  }

  Future<List<_ShareItem>> _loadShares() async {
    final docs = await ActivityService.loadShares();
    return [
      for (final d in docs)
        _ShareItem(
          d.data()['postId'] as String? ?? d.id,
          _date(d.data()['createdAt']),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Lịch sử hoạt động', 'Activity history')),
          bottom: TabBar(
            indicatorColor: AppColors.brand,
            labelColor: AppColors.brand,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: tr('Cảm xúc', 'Reactions')),
              Tab(text: tr('Bình luận', 'Comments')),
              Tab(text: tr('Chia sẻ', 'Shares')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ActivityTab<_ReactionItem>(
              load: _loadReactions,
              emptyIcon: Icons.favorite_border,
              emptyText: tr(
                'Bạn chưa thả cảm xúc nào',
                'You have not reacted to anything yet',
              ),
              itemBuilder: (ctx, it, reload) => _reactionTile(ctx, it, reload),
            ),
            _ActivityTab<_CommentItem>(
              load: _loadComments,
              emptyIcon: Icons.chat_bubble_outline,
              emptyText: tr(
                'Bạn chưa bình luận nào',
                'You have not commented yet',
              ),
              itemBuilder: (ctx, it, reload) => _commentTile(ctx, it, reload),
            ),
            _ActivityTab<_ShareItem>(
              load: _loadShares,
              emptyIcon: Icons.share_outlined,
              emptyText: tr(
                'Bạn chưa chia sẻ bài viết nào',
                'You have not shared any posts yet',
              ),
              itemBuilder: (ctx, it, reload) => _shareTile(ctx, it, reload),
            ),
          ],
        ),
      ),
    );
  }

  void _openPost(BuildContext context, Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CommentsScreen(post: post)),
    );
  }

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _reactionTile(
      BuildContext context, _ReactionItem it, VoidCallback reload) {
    return FutureBuilder<Post?>(
      future: _PostCache.post(it.postId),
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final post = snap.data;
        final what = it.commentId == null
            ? tr('bài viết', 'post')
            : tr('bình luận trong bài viết', 'a comment on the post');

        final title = loading
            ? '…'
            : (post == null
            ? tr('Bài viết không còn tồn tại', 'Post no longer exists')
            : '${tr('Bạn đã thả', 'You reacted')} ${it.emoji} ${tr('vào', 'to')} $what ${tr('của', 'by')} ${post.authorName}');

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.soft,
            child: Text(it.emoji, style: const TextStyle(fontSize: 20)),
          ),
          title: Text(title),
          subtitle: Text(
            '${post == null ? '' : '${_snippet(post)}\n'}${formatTimeAgo(it.createdAt)}',
          ),
          isThreeLine: post != null,
          onTap: post == null ? null : () => _openPost(context, post),
          trailing: (post != null && it.commentId == null)
              ? IconButton(
            tooltip: tr('Bỏ cảm xúc', 'Remove reaction'),
            icon: const Icon(Icons.close),
            onPressed: () async {
              try {
                // Chọn lại đúng cảm xúc đang có thì sẽ bỏ cảm xúc đó
                await ReactionService.setReaction(post, it.emoji);
              } catch (e) {
                if (context.mounted) _snack(context, '$e');
              }
              reload();
            },
          )
              : null,
        );
      },
    );
  }

  Widget _commentTile(
      BuildContext context, _CommentItem it, VoidCallback reload) {
    return FutureBuilder<Post?>(
      future: _PostCache.post(it.postId),
      builder: (context, snap) {
        final post = snap.data;
        final done = snap.connectionState == ConnectionState.done;
        final where = !done
            ? '…'
            : (post == null
            ? tr('Bài viết không còn tồn tại', 'Post no longer exists')
            : '${tr('Trong bài của', 'On a post by')} ${post.authorName}: ${_snippet(post)}');

        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.soft,
            child: Icon(Icons.chat_bubble_outline,
                color: AppColors.brand, size: 20),
          ),
          title: Text(
            '${tr('Bạn đã bình luận', 'You commented')}: "${it.comment.text}"',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('$where\n${formatTimeAgo(it.comment.createdAt)}'),
          isThreeLine: true,
          onTap: post == null ? null : () => _openPost(context, post),
          trailing: post == null
              ? null
              : IconButton(
            tooltip: tr('Xóa bình luận', 'Delete comment'),
            icon: const Icon(Icons.delete_outline,
                color: AppColors.danger),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title:
                  Text(tr('Xóa bình luận?', 'Delete comment?')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(tr('Hủy', 'Cancel')),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(tr('Xóa', 'Delete')),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              try {
                await CommentService.deleteComment(post, it.comment);
              } catch (e) {
                if (context.mounted) _snack(context, '$e');
              }
              reload();
            },
          ),
        );
      },
    );
  }

  Widget _shareTile(BuildContext context, _ShareItem it, VoidCallback reload) {
    return FutureBuilder<Post?>(
      future: _PostCache.post(it.postId),
      builder: (context, snap) {
        final post = snap.data;
        final done = snap.connectionState == ConnectionState.done;
        final title = !done
            ? '…'
            : (post == null
            ? tr('Bài viết không còn tồn tại', 'Post no longer exists')
            : '${tr('Bạn đã chia sẻ bài viết của', 'You shared a post by')} ${post.authorName}');

        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.soft,
            child:
            Icon(Icons.share_outlined, color: AppColors.brand, size: 20),
          ),
          title: Text(title),
          subtitle: Text(
            '${post == null ? '' : '${_snippet(post)}\n'}${formatTimeAgo(it.createdAt)}',
          ),
          isThreeLine: post != null,
          onTap: post == null ? null : () => _openPost(context, post),
          trailing: IconButton(
            tooltip: tr('Xóa khỏi lịch sử', 'Remove from history'),
            icon: const Icon(Icons.close),
            onPressed: () async {
              try {
                await ActivityService.removeShare(it.postId);
              } catch (e) {
                if (context.mounted) _snack(context, '$e');
              }
              reload();
            },
          ),
        );
      },
    );
  }
}

/// Một tab tải danh sách, giữ nguyên trạng thái khi chuyển tab, kéo xuống để làm mới.
class _ActivityTab<T> extends StatefulWidget {
  final Future<List<T>> Function() load;
  final Widget Function(BuildContext context, T item, VoidCallback reload)
  itemBuilder;
  final String emptyText;
  final IconData emptyIcon;

  const _ActivityTab({
    required this.load,
    required this.itemBuilder,
    required this.emptyText,
    required this.emptyIcon,
  });

  @override
  State<_ActivityTab<T>> createState() => _ActivityTabState<T>();
}

class _ActivityTabState<T> extends State<_ActivityTab<T>>
    with AutomaticKeepAliveClientMixin {
  late Future<List<T>> _future = widget.load();

  @override
  bool get wantKeepAlive => true;

  Future<void> _reload() async {
    _PostCache.clear();
    final f = widget.load();
    if (mounted) setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  Widget _error(Object error) {
    final text = '$error';
    final needsIndex =
        text.contains('failed-precondition') || text.contains('index');
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            needsIndex
                ? tr(
              'Cần bật chỉ mục trong Firestore (làm một lần)',
              'A Firestore index is required (one-time setup)',
            )
                : tr('Không tải được', 'Could not load'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (needsIndex)
            Text(
              tr(
                'Mở đường dẫn trong thông báo lỗi bên dưới (nếu có) rồi bấm tạo chỉ mục, hoặc làm theo hướng dẫn "Chỉ mục cho Lịch sử hoạt động". Sau 1 đến 3 phút, kéo xuống để làm mới.',
                'Open the link in the error below (if any) and create the index, or follow the "Indexes for Activity history" instructions. After 1 to 3 minutes, pull down to refresh.',
              ),
              style: const TextStyle(height: 1.4),
            ),
          const SizedBox(height: 8),
          SelectableText(
            text,
            style:
            const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<T>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(children: [_error(snap.error!)]);
          }
          if (snap.connectionState != ConnectionState.done) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          final items = snap.data ?? <T>[];
          if (items.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 100),
                Icon(widget.emptyIcon,
                    size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(
                  widget.emptyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        '${items.length} ${tr('mục', 'items')}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return widget.itemBuilder(context, items[i - 1], _reload);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}