import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/interactions.dart';
import '../models/post.dart';
import '../models/space.dart';
import '../screens/comments_screen.dart';
import '../screens/create_post_screen.dart';
import '../screens/layer_manager_screen.dart';
import '../screens/user_profile_page.dart';
import '../services/account_service.dart';
import '../services/activity_service.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../services/trash_service.dart';
import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import 'audience_picker.dart';
import 'fork_widgets.dart';
import 'poll_card.dart';
import 'post_blocks.dart';
import 'reaction_picker.dart';
import 'response_bar.dart';
import 'space_picker.dart';
import 'post_extras.dart';
import 'weave_layers_view.dart';
import '../services/capsule_service.dart';

class PostCard extends StatelessWidget {
  final Post post;

  /// Bấm vào tên/avatar tác giả thì mở trang cá nhân của họ.
  final bool openProfileOnTap;

  /// Bấm nút Bình luận thì mở màn hình bình luận.
  final bool openCommentsOnTap;

  /// Hiện nhãn "Đã ghim" khi bài đang được ghim (dùng trên trang hồ sơ).
  final bool showPinnedTag;

  const PostCard({
    super.key,
    required this.post,
    this.openProfileOnTap = true,
    this.openCommentsOnTap = true,
    this.showPinnedTag = false,
  });

  void _openProfile(BuildContext context) {
    if (!openProfileOnTap || post.authorId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          userId: post.authorId,
          title: post.authorName,
        ),
      ),
    );
  }

  void _openComments(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CommentsScreen(post: post)),
    );
  }

  Future<bool> _confirm(
      BuildContext context, {
        required String title,
        String? content,
        required String action,
      }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: content == null ? null : Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _changeSpace(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showSpacePicker(
      context,
      current: post.spaceId,
      title: tr('Đổi chủ đề của bài viết', 'Change the topic of this post'),
    );
    if (picked == null || picked == post.spaceId) return;
    try {
      await PostService.updateSpace(post, picked);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _changeAudience(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showAudiencePicker(
      context,
      current: post.visibility,
      title: tr('Ai có thể xem bài viết này?', 'Who can see this post?'),
    );
    if (picked == null || picked == post.visibility) return;
    try {
      await PostService.changeVisibility(post, picked);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Đã đổi đối tượng: ${audienceLabel(picked)}',
              'Audience changed: ${audienceLabel(picked)}',
            ),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// Tác giả bổ sung một gợi ý vào câu hỏi.
  Future<void> _addHint(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _HintDialog(),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await PostService.addHint(post, text);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _onMenu(BuildContext context, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final prefs = UserPrefs.instance;
    final name = post.authorName;

    try {
      switch (value) {
        case 'fork':
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreatePostScreen(forkOf: post),
            ),
          );
          break;
        case 'space':
          await _changeSpace(context);
          break;
        case 'audience':
          await _changeAudience(context);
          break;
        case 'layers':
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LayerManagerScreen(post: post),
            ),
          );
          break;
        case 'pin':
          if (post.isPinned) {
            await PostService.unpin(post);
            messenger.showSnackBar(
              SnackBar(content: Text(tr('Đã bỏ ghim', 'Unpinned'))),
            );
          } else {
            await PostService.pin(post);
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  tr('Đã ghim lên đầu hồ sơ', 'Pinned to the top of your profile'),
                ),
              ),
            );
          }
          break;
        case 'delete':
          if (post.ref.parent.id == 'capsules') {
            // Hộp thời gian không đi qua thùng rác: xóa vĩnh viễn
            if (await _confirm(
              context,
              title: tr('Xóa hộp thời gian?', 'Delete this time capsule?'),
              content: tr(
                'Hộp thời gian sẽ bị xóa vĩnh viễn, không khôi phục được.',
                'The time capsule will be permanently deleted and cannot be restored.',
              ),
              action: tr('Xóa vĩnh viễn', 'Delete forever'),
            )) {
              await CapsuleService.delete(post.id);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                      tr('Đã xóa hộp thời gian', 'Time capsule deleted')),
                ),
              );
            }
            break;
          }
          if (await _confirm(
            context,
            title: tr('Chuyển bài viết vào thùng rác?', 'Move post to trash?'),
            content: tr(
              'Bài viết được giữ trong thùng rác 30 ngày, bạn có thể khôi phục trước khi nó bị xóa vĩnh viễn.',
              'The post stays in the trash for 30 days. You can restore it before it is permanently deleted.',
            ),
            action: tr('Chuyển vào thùng rác', 'Move to trash'),
          )) {
            await TrashService.moveToTrash(post);
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  tr('Đã chuyển vào thùng rác', 'Moved to trash'),
                ),
              ),
            );
          }
          break;
        case 'save':
          final wasSaved = prefs.isSaved(post.id);
          await prefs.toggleSaved(post);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                wasSaved
                    ? tr('Đã bỏ lưu bài viết', 'Post removed from saved')
                    : tr('Đã lưu bài viết', 'Post saved'),
              ),
            ),
          );
          break;
        case 'favorite':
          await prefs.setFavoriteUser(
            post.authorId,
            !prefs.isFavoriteUser(post.authorId),
          );
          break;
        case 'hide':
          await prefs.hidePost(post.id);
          messenger.showSnackBar(
            SnackBar(
              content: Text(tr('Đã ẩn bài viết', 'Post hidden')),
              action: SnackBarAction(
                label: tr('Hoàn tác', 'Undo'),
                onPressed: () => prefs.unhidePost(post.id),
              ),
            ),
          );
          break;
        case 'mute':
          await prefs.setMuted(post.authorId, true);
          messenger.showSnackBar(
            SnackBar(
              content: Text(tr('Đã tắt tiếng $name', 'Muted $name')),
              action: SnackBarAction(
                label: tr('Hoàn tác', 'Undo'),
                onPressed: () => prefs.setMuted(post.authorId, false),
              ),
            ),
          );
          break;
        case 'block':
          if (await _confirm(
            context,
            title: tr('Chặn $name?', 'Block $name?'),
            content: tr(
              'Bạn sẽ không thấy bài viết và bình luận của họ, và hai bạn không còn là bạn bè. Họ sẽ không được thông báo.',
              'You will not see their posts and comments, and you will stop being friends. They will not be notified.',
            ),
            action: tr('Chặn', 'Block'),
          )) {
            await prefs.block(post.authorId, name);
          }
          break;
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  List<PopupMenuEntry<String>> _menuItems(bool isMine) {
    final prefs = UserPrefs.instance;

    // Chỉ bài công khai (và không phải câu hỏi) mới rẽ nhánh được
    final forkItem = <PopupMenuEntry<String>>[
      if (post.collection == 'posts' && !post.isQuestion)
        PopupMenuItem<String>(
          value: 'fork',
          child: Text(tr('Rẽ nhánh bài này', 'Fork this post')),
        ),
    ];

    if (isMine) {
      return [
        ...forkItem,
        // Hộp thời gian không ghim được
        if (post.collection != 'capsules')
          PopupMenuItem<String>(
            value: 'pin',
            child: Text(
              post.isPinned
                  ? tr('Bỏ ghim khỏi hồ sơ', 'Unpin from profile')
                  : tr('Ghim lên đầu hồ sơ', 'Pin to profile'),
            ),
          ),
        // Câu hỏi không có chủ đề nên không có mục đổi chủ đề
        if (!post.isQuestion)
          PopupMenuItem<String>(
            value: 'space',
            child: Text(tr('Đổi chủ đề', 'Change topic')),
          ),
        PopupMenuItem<String>(
          value: 'audience',
          child: Text(tr('Đổi đối tượng xem', 'Change audience')),
        ),
        // Weave Layers: hộp thời gian và câu hỏi không có lớp
        if (post.collection != 'capsules' && !post.isQuestion)
          PopupMenuItem<String>(
            value: 'layers',
            child: Text(tr('Quản lý lớp', 'Manage layers')),
          ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(
            tr('Xóa bài viết', 'Delete post'),
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ];
    }
    final name = post.authorName;
    return [
      ...forkItem,
      PopupMenuItem<String>(
        value: 'save',
        child: Text(
          prefs.isSaved(post.id)
              ? tr('Bỏ lưu bài viết', 'Unsave post')
              : tr('Lưu bài viết', 'Save post'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'favorite',
        child: Text(
          prefs.isFavoriteUser(post.authorId)
              ? tr('Bỏ yêu thích $name', 'Remove $name from favorites')
              : tr('Thêm $name vào yêu thích', 'Add $name to favorites'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'hide',
        child: Text(tr('Ẩn bài viết này', 'Hide this post')),
      ),
      PopupMenuItem<String>(
        value: 'mute',
        child: Text(tr('Tắt tiếng $name', 'Mute $name')),
      ),
      PopupMenuItem<String>(
        value: 'block',
        child: Text(
          tr('Chặn $name', 'Block $name'),
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
    ];
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final link = 'https://social-app-353f0.web.app/post/${post.id}';
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WeaveRadius.card),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                tr('Chia sẻ bài viết', 'Share post'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link, color: AppColors.brand),
              title: Text(tr('Sao chép liên kết', 'Copy link')),
              onTap: () async {
                Navigator.of(ctx).pop();
                await Clipboard.setData(ClipboardData(text: link));
                ActivityService.logShare(post.id);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(tr('Đã sao chép liên kết', 'Link copied')),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (post.reactions <= 0 && post.comments <= 0) {
      return const SizedBox.shrink();
    }
    final entries = post.reactionSummary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(3).map((e) => e.key).join(' ');

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          if (post.reactions > 0)
            Text(
              '${top.isEmpty ? '👍' : top} ${post.reactions}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          const Spacer(),
          if (post.comments > 0)
            Text(
              '${post.comments} ${tr('bình luận', 'comments')}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  /// Khung gợi ý của câu hỏi: tác giả bổ sung, mọi người đọc.
  Widget _buildHints(BuildContext context, bool isMine) {
    if (!post.isQuestion) return const SizedBox.shrink();
    if (post.hints.isEmpty && !isMine) return const SizedBox.shrink();

    final canAdd = isMine && post.hints.length < PostService.maxHints;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        // Màu vàng nhạt giữ nguyên: là màu ngữ nghĩa "gợi ý", không thuộc bảng màu thương hiệu
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(WeaveRadius.control),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.hints.isNotEmpty) ...[
            Text(
              '💡 ${tr('Gợi ý bổ sung từ tác giả', 'Hints from the author')}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final h in post.hints)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: h.text),
                            TextSpan(
                              text: '  ${formatTimeAgo(h.createdAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (canAdd)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addHint(context),
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: Text(tr('Bổ sung gợi ý', 'Add a hint')),
                style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              ),
            ),
        ],
      ),
    );
  }

  /// Hàng thao tác dưới bài: cảm xúc, bình luận, lưu, chia sẻ.
  /// Mọi nút cùng chiều cao với ReactionButton, icon 20; khi hẹp thì nút bình luận chỉ còn icon.
  Widget _buildActionRow(BuildContext context, bool isQuestion) {
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 340;
        final commentText =
        isQuestion ? tr('Trả lời', 'Answer') : tr('Bình luận', 'Comment');
        return Row(
          children: [
            ReactionButton(post: post),
            _PostAction(
              icon: isQuestion
                  ? Icons.question_answer_outlined
                  : Icons.chat_bubble_outline,
              label: compact ? null : commentText,
              tooltip: commentText,
              onPressed:
              openCommentsOnTap ? () => _openComments(context) : null,
            ),
            const Spacer(),
            ListenableBuilder(
              listenable: UserPrefs.instance,
              builder: (context, _) {
                final saved = UserPrefs.instance.isSaved(post.id);
                return _PostAction(
                  icon: saved ? Icons.bookmark : Icons.bookmark_border,
                  active: saved,
                  tooltip: saved
                      ? tr('Bỏ lưu', 'Unsave')
                      : tr('Lưu bài viết', 'Save post'),
                  onPressed: () => UserPrefs.instance.toggleSaved(post),
                );
              },
            ),
            // Bài không công khai: liên kết chỉ mở được với người có quyền xem
            _PostAction(
              icon: Icons.share_outlined,
              tooltip: tr('Chia sẻ', 'Share'),
              onPressed: () => _share(context),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMine = post.authorId == FirebaseAuth.instance.currentUser?.uid;
    final isFork = post.forkedFrom != null;
    final isQuestion = post.isQuestion;
    if (post.isExpired && !isMine) return const SizedBox.shrink();

    // Nhãn đối tượng xem: chỉ hiện với bài không công khai
    final audienceTag = post.friendsOnly
        ? ' · ${post.visibility == 'me' ? '🔒' : '👥'} ${audienceLabel(post.visibility)}'
        : '';
    // Nhãn ghim: chỉ hiện ở nơi được yêu cầu (trang hồ sơ)
    final pinTag = (showPinnedTag && post.isPinned)
        ? '📌 ${tr('Đã ghim', 'Pinned')} · '
        : '';

    // Câu hỏi không có chủ đề: hiện nhãn "Câu hỏi" thay cho chủ đề
    final String topicLabel;
    if (isQuestion) {
      topicLabel = '❓ ${tr('Câu hỏi', 'Question')}';
    } else {
      final space = findSpace(post.spaceId) ?? defaultSpaces.first;
      topicLabel =
      '${space.emoji} ${tr(space.name, space.nameEn ?? space.name)}';
    }

    return Card(
      color: isFork ? AppColors.soft : AppColors.surface,
      elevation: 0,
      margin: isFork
          ? const EdgeInsets.fromLTRB(40, 2, WeaveSpacing.lg, 6)
          : const EdgeInsets.symmetric(
        horizontal: WeaveSpacing.lg,
        vertical: WeaveSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          isFork ? WeaveRadius.control : WeaveRadius.card,
        ),
        side: BorderSide(
          color: isFork
              ? AppColors.brand.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isFork ? WeaveSpacing.md : WeaveSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng tiêu đề: avatar, tên, chủ đề và nút ba chấm
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(WeaveRadius.control),
                    onTap: () => _openProfile(context),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: isFork ? 15 : 20,
                          backgroundColor: AppColors.soft,
                          child: Text(
                            initialOf(post.authorName),
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: WeaveSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.authorName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              // Chủ đề nhấn màu thương hiệu, phần còn lại là metadata
                              Text.rich(
                                TextSpan(
                                  children: [
                                    if (pinTag.isNotEmpty) TextSpan(text: pinTag),
                                    TextSpan(
                                      text: topicLabel,
                                      style: const TextStyle(
                                        color: AppColors.brand,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                      ' · ${formatTimeAgo(post.createdAt)}$audienceTag',
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz,
                    color: AppColors.textSecondary,
                  ),
                  onSelected: (v) => _onMenu(context, v),
                  itemBuilder: (_) => _menuItems(isMine),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Nội dung bài, tóm tắt cảm xúc và hàng nút nằm NGOÀI hàng tiêu đề
            if (!isQuestion) ForkOrigin(post: post),
            // Bài có nhiều lớp (Weave): hiện thanh tab các lớp; bài thường
            // giữ nguyên cách hiển thị cũ
            post.isWeave
                ? WeaveLayersView(key: ValueKey('weave_${post.id}'), post: post)
                : PostBlocks(post: post),
            // Câu hỏi: gợi ý bổ sung của tác giả và trạng thái đáp án
            _buildHints(context, isMine),
            if (isQuestion && post.hasAcceptedAnswer)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '✅ ${tr('Đã có đáp án được chọn', 'An answer has been picked')}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // Bình chọn đính kèm bài (key theo id bài để giữ trạng thái khi
            // danh sách cuộn hoặc cập nhật)
            if (post.hasPoll)
              PollCard(key: ValueKey('poll_${post.id}'), post: post),
            _buildSummary(),
            // Câu hỏi không có phản hồi theo chủ đề, nhánh, cập nhật, góp ý
            // hay ghi chú theo khối
            if (!isQuestion) ...[
              ResponseBar(post: post),
              ForkCount(post: post),
              PostExtras(post: post),
            ],
            const Divider(height: 16),
            _buildActionRow(context, isQuestion),
          ],
        ),
      ),
    );
  }
}

/// Nút thao tác dùng chung cho hàng dưới bài viết: cùng chiều cao với ReactionButton, icon 20,
/// ba trạng thái (thường, đã chọn, vô hiệu).
class _PostAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  const _PostAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? AppColors.textSecondary.withValues(alpha: 0.5)
        : (active ? AppColors.brand : AppColors.textSecondary);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(WeaveRadius.control),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: WeaveSizes.buttonHeightCompact,
            minWidth: WeaveSizes.buttonHeightCompact,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: WeaveSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hộp nhập gợi ý bổ sung (tự quản lý bộ điều khiển ô nhập).
class _HintDialog extends StatefulWidget {
  const _HintDialog();

  @override
  State<_HintDialog> createState() => _HintDialogState();
}

class _HintDialogState extends State<_HintDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WeaveRadius.card),
      ),
      title: Text(tr('Bổ sung gợi ý', 'Add a hint')),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          maxLength: PostService.maxHintLength,
          decoration: InputDecoration(
            hintText: tr(
              'Thêm thông tin giúp mọi người trả lời đúng hơn',
              'Add details to help people answer better',
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Hủy', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(tr('Thêm', 'Add')),
        ),
      ],
    );
  }
}