import 'package:flutter/material.dart';
import '../models/story_models.dart';
import '../services/l10n.dart';
import '../services/story_service.dart';
import '../theme/app_theme.dart';
import '../widgets/story_widgets.dart';

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

        return Scaffold(
          appBar: AppBar(
            title: Text(story.title, overflow: TextOverflow.ellipsis),
            actions: [
              if (isOwner)
                IconButton(
                  tooltip: tr('Mời bạn cùng sửa', 'Invite to edit'),
                  icon: const Icon(Icons.group_add_outlined),
                  onPressed: () => _invite(story),
                ),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'delete' ? _deleteStory() : _leave(),
                itemBuilder: (_) => [
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
                      StoryMissingCard(questions: story.missing),
                      if (story.droppedCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            tr(
                              '${story.droppedCount} đoạn AI viết bị loại vì không dẫn được nguồn.',
                              '${story.droppedCount} AI-written parts were removed because they had no valid source.',
                            ),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
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
      },
    );
  }
}