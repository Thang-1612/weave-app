import 'package:flutter/material.dart';
import '../models/story_models.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../services/story_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audience_picker.dart';
import '../widgets/story_widgets.dart';
import 'comments_screen.dart';

class StoryDetailScreen extends StatefulWidget {
  final String storyId;

  const StoryDetailScreen({super.key, required this.storyId});

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  late final _story = StoryService.story(widget.storyId);
  late final _blocks = StoryService.blocks(widget.storyId);
  late final _sources = StoryService.sources(widget.storyId);

  // Dữ liệu mới nhất, để đăng bài hoặc hỏi đăng khi thoát
  List<StoryBlock> _latestBlocks = const [];
  Map<String, StorySource> _latestSources = const {};
  bool _publishing = false;

  Future<bool> _publish(Story story, String visibility) async {
    if (_publishing) return false;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _publishing = true);
    try {
      final r = await StoryService.publishAsPost(
        story: story,
        blocks: _latestBlocks,
        sources: _latestSources,
        visibility: visibility,
      );
      messenger.showSnackBar(SnackBar(
        content: Text(r.skippedImages > 0
            ? tr('Đã đăng. ${r.skippedImages} ảnh không đưa vào bài vì giới hạn dung lượng.',
            'Posted. ${r.skippedImages} photos were left out because of the size limit.')
            : tr('Đã đăng lên bảng tin', 'Posted to your feed')),
      ));
      return true;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _choosePublish(Story story) async {
    final v = await showAudiencePicker(
      context,
      current: 'friends',
      title: tr('Ai xem được bài đăng?', 'Who can see the post?'),
    );
    if (v == null || !mounted) return;
    await _publish(story, v);
  }

  Future<void> _openPost(Story story) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final post = await PostService.getPost(story.publishedPostId!);
    if (post == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(tr('Bài đã đăng không còn tồn tại. Dùng "Đăng lại bài" ở menu.',
            'The posted item no longer exists. Use "Post again" in the menu.')),
      ));
      return;
    }
    nav.push(MaterialPageRoute(builder: (_) => CommentsScreen(post: post)));
  }

  /// Chủ truyện bấm thoát khi chưa đăng: hỏi có muốn đăng không.
  Future<void> _onBack(Story story) async {
    final nav = Navigator.of(context);
    if (_latestBlocks.isEmpty || _publishing) {
      nav.pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(tr('Đăng câu chuyện này lên bảng tin?',
            'Post this story to your feed?')),
        content: Text(tr(
          'Câu chuyện đã được lưu. Chọn ai được xem bài đăng:',
          'Your story is saved. Choose who can see the post:',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('later'),
            child: Text(tr('Để sau', 'Later')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('friends'),
            child: Text(tr('Bạn bè', 'Friends')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: () => Navigator.of(ctx).pop('public'),
            child: Text(tr('Công khai', 'Public')),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return; // đóng hộp thoại: ở lại
    if (choice == 'later') {
      nav.pop();
      return;
    }
    final ok = await _publish(story, choice);
    if (ok && mounted) nav.pop();
  }

  Future<void> _edit(StoryBlock b) async {
    final text = await showStoryTextDialog(
      context,
      title: tr('Sửa đoạn này', 'Edit this part'),
      initial: b.text,
    );
    if (text == null || text.trim().isEmpty) return;
    await StoryService.updateBlockText(widget.storyId, b.id, text);
  }

  Future<void> _delete(StoryBlock b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Xóa đoạn này?', 'Delete this part?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Xóa', 'Delete')),
          ),
        ],
      ),
    );
    if (ok == true) await StoryService.deleteBlock(widget.storyId, b.id);
  }

  Future<bool> _confirm(String title, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteStory() async {
    if (!await _confirm(
      tr('Xóa cả câu chuyện? Mọi người cùng sửa cũng sẽ mất nó.',
          'Delete the whole story? Collaborators will lose it too.'),
      tr('Xóa', 'Delete'),
    )) {
      return;
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await StoryService.deleteStory(widget.storyId);
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _leave() async {
    if (!await _confirm(
      tr('Rời khỏi câu chuyện này?', 'Leave this story?'),
      tr('Rời khỏi', 'Leave'),
    )) {
      return;
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await StoryService.leaveStory(widget.storyId);
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _answerMissing(String q, int lastOrder) async {
    final text = await showStoryTextDialog(
      context,
      title: q,
      hint: tr('Viết câu trả lời thành một đoạn của câu chuyện',
          'Write the answer as a part of the story'),
    );
    if (text == null || text.trim().isEmpty) return;
    await StoryService.answerMissing(widget.storyId, q, text, lastOrder);
  }

  Future<void> _addBlock(int lastOrder) async {
    final text = await showStoryTextDialog(
      context,
      title: tr('Thêm đoạn của bạn', 'Add your own part'),
    );
    if (text == null || text.trim().isEmpty) return;
    await StoryService.addUserBlock(widget.storyId, text, lastOrder);
  }

  Future<void> _invite(Story story) async {
    final messenger = ScaffoldMessenger.of(context);
    final friendUid = await showStoryFriendPicker(
      context,
      exclude: story.collaboratorIds,
    );
    if (friendUid == null) return;
    try {
      await StoryService.addCollaborator(widget.storyId, friendUid);
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Đã mời bạn', 'Friend invited'))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = StoryService.uid;
    return StreamBuilder<Story?>(
      stream: _story,
      builder: (context, storySnap) {
        if (storySnap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('${storySnap.error}')),
          );
        }
        if (!storySnap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final story = storySnap.data;
        if (story == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(tr('Câu chuyện không còn tồn tại',
                'This story no longer exists'))),
          );
        }
        final canEdit = story.collaboratorIds.contains(me);
        final isOwner = story.ownerId == me;

        final scaffold = Scaffold(
          appBar: AppBar(
            title: Text(story.title, overflow: TextOverflow.ellipsis),
            actions: [
              if (isOwner)
                IconButton(
                  tooltip: story.publishedPostId == null
                      ? tr('Đăng lên bảng tin', 'Post to feed')
                      : tr('Đã đăng · xem bài', 'Posted · view post'),
                  icon: Icon(story.publishedPostId == null
                      ? Icons.publish
                      : Icons.check_circle_outline),
                  onPressed: _publishing
                      ? null
                      : () => story.publishedPostId == null
                      ? _choosePublish(story)
                      : _openPost(story),
                ),
              if (isOwner)
                IconButton(
                  tooltip: tr('Mời bạn cùng sửa', 'Invite to edit'),
                  icon: const Icon(Icons.group_add_outlined),
                  onPressed: () => _invite(story),
                ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') {
                    _deleteStory();
                  } else if (v == 'republish') {
                    _choosePublish(story);
                  } else {
                    _leave();
                  }
                },
                itemBuilder: (_) => [
                  if (isOwner && story.publishedPostId != null)
                    PopupMenuItem(
                      value: 'republish',
                      child: Text(tr('Đăng lại bài', 'Post again')),
                    ),
                  if (isOwner)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(tr('Xóa câu chuyện', 'Delete story')),
                    )
                  else
                    PopupMenuItem(
                      value: 'leave',
                      child: Text(tr('Rời khỏi câu chuyện', 'Leave story')),
                    ),
                ],
              ),
            ],
          ),
          body: StreamBuilder<Map<String, StorySource>>(
            stream: _sources,
            builder: (context, srcSnap) {
              final sources = srcSnap.data ?? const <String, StorySource>{};
              return StreamBuilder<List<StoryBlock>>(
                stream: _blocks,
                builder: (context, blkSnap) {
                  final blocks = blkSnap.data ?? const <StoryBlock>[];
                  _latestBlocks = blocks;
                  _latestSources = sources;
                  final lastOrder = blocks.isEmpty ? 0 : blocks.last.order;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(
                            avatar: Icon(storyKindIcon(story.kind), size: 16),
                            label: Text(storyKindLabel(story.kind)),
                          ),
                          Chip(
                            avatar: const Icon(Icons.music_note, size: 16),
                            label: Text(tr(
                              'Gợi ý nhạc: ${storyMusicHint(story.mood)}',
                              'Music idea: ${storyMusicHint(story.mood)}',
                            )),
                          ),
                          Chip(
                            avatar: const Icon(Icons.group_outlined, size: 16),
                            label: Text('${story.collaboratorIds.length}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StoryMissingCard(
                        questions: story.missing,
                        canEdit: canEdit,
                        onAnswer: (q) => _answerMissing(q, lastOrder),
                        onDismiss: (q) =>
                            StoryService.dismissMissing(widget.storyId, q),
                      ),
                      if (story.droppedCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            tr(
                              '${story.droppedCount} đoạn AI viết bị loại vì không dẫn được nguồn.',
                              '${story.droppedCount} AI-written parts were removed because they had no valid source.',
                            ),
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      for (final b in blocks)
                        StoryBlockCard(
                          key: ValueKey(b.id),
                          block: b,
                          sources: sources,
                          canEdit: canEdit,
                          currentUid: me,
                          onEdit: () => _edit(b),
                          onDelete: () => _delete(b),
                        ),
                      if (canEdit)
                        OutlinedButton.icon(
                          onPressed: () => _addBlock(lastOrder),
                          icon: const Icon(Icons.add),
                          label: Text(tr('Thêm đoạn của bạn', 'Add your own part')),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
        return PopScope(
          // Chỉ chủ truyện chưa đăng mới bị hỏi khi thoát
          canPop: !(isOwner && story.publishedPostId == null),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBack(story);
          },
          child: scaffold,
        );
      },
    );
  }
}