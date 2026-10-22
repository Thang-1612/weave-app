import 'package:flutter/material.dart';
import '../models/story_models.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../services/story_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audience_picker.dart';
import '../widgets/story_status_chip.dart';
import '../widgets/story_widgets.dart';
import 'comments_screen.dart';

/// Từ chiều rộng này trở lên: 3 cột (các đoạn | chỉnh sửa | xem trước).
/// Dưới mức này: một cột, xem trước mở ở bottom sheet.
const double _kStoryDetailWideBreakpoint = 1100;
const double _kStoryOutlineWidth = 300;

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
  String? _selectedBlockId; // đoạn đang chỉnh sửa (bố cục rộng)
  bool _editorDirty = false; // đoạn đang chỉnh sửa có thay đổi chưa lưu

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WeaveRadius.card),
        ),
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

  /// Hộp xác nhận cho hành động nguy hiểm: nút xác nhận màu đỏ Danger.
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _delete(StoryBlock b) async {
    if (!await _confirm(
      tr('Xóa đoạn này?', 'Delete this part?'),
      tr('Xóa', 'Delete'),
    )) {
      return;
    }
    _editorDirty = false; // đoạn bị xóa thì không còn gì chưa lưu
    await StoryService.deleteBlock(widget.storyId, b.id);
  }

  /// Chọn đoạn khác ở bố cục rộng: hỏi trước nếu đoạn hiện tại chưa lưu.
  Future<void> _selectBlock(String id, String? currentId) async {
    if (id == currentId) return;
    if (_editorDirty) {
      final discard = await _confirm(
        tr('Đoạn này có thay đổi chưa lưu. Bỏ thay đổi?',
            'This part has unsaved changes. Discard them?'),
        tr('Bỏ thay đổi', 'Discard'),
      );
      if (!discard || !mounted) return;
    }
    _editorDirty = false;
    setState(() => _selectedBlockId = id);
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

  // ---------------------------------------------------------------------
  // Xem trước: bản đọc (không có nút sửa/xóa) của toàn bộ câu chuyện
  // ---------------------------------------------------------------------

  List<Widget> _previewChildren(
      Story story,
      List<StoryBlock> blocks,
      Map<String, StorySource> sources,
      String me,
      ) {
    return [
      Text(
        story.title,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: WeaveSpacing.sm),
      Text(
        '${storyKindLabel(story.kind)} · ${fmtDate(story.updatedAt)}',
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      const SizedBox(height: WeaveSpacing.lg),
      if (blocks.isEmpty)
        Text(
          tr('Chưa có đoạn nào.', 'No parts yet.'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      for (final b in blocks)
        StoryBlockCard(
          key: ValueKey('preview_${b.id}'),
          block: b,
          sources: sources,
          canEdit: false,
          currentUid: me,
          onEdit: () {},
          onDelete: () {},
        ),
    ];
  }

  /// Hẹp: xem trước mở ở bottom sheet kéo được.
  Future<void> _openPreviewSheet(Story story, String me) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WeaveRadius.card),
        ),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Text(
                    tr('Xem trước', 'Preview'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: tr('Đóng', 'Close'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: _previewChildren(
                  story,
                  _latestBlocks,
                  _latestSources,
                  me,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Các thành phần chung
  // ---------------------------------------------------------------------

  /// Hàng chip: trạng thái, loại, gợi ý nhạc, số người cùng sửa.
  Widget _metaChips(Story story) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StoryStatusChip(story),
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
    );
  }

  Widget _droppedNote(Story story) {
    if (story.droppedCount <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        tr(
          '${story.droppedCount} đoạn AI viết bị loại vì không dẫn được nguồn.',
          '${story.droppedCount} AI-written parts were removed because they had no valid source.',
        ),
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  /// Nút xuất bản / xem bài đăng cho chủ truyện. Chưa đăng: nút chính (tím đặc).
  /// Đã đăng: nút viền "Xem bài đăng".
  Widget _publishButton(Story story) {
    if (story.publishedPostId == null) {
      return FilledButton.icon(
        onPressed: _publishing ? null : () => _choosePublish(story),
        icon: _publishing
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.publish, size: 18),
        label: Text(tr('Xuất bản', 'Publish')),
      );
    }
    return OutlinedButton.icon(
      onPressed: _publishing ? null : () => _openPost(story),
      icon: const Icon(Icons.check_circle_outline, size: 18),
      label: Text(tr('Xem bài đăng', 'View post')),
    );
  }

  PreferredSizeWidget _appBar(Story story, bool isOwner, bool wide) {
    return AppBar(
      title: Text(story.title, overflow: TextOverflow.ellipsis),
      actions: [
        if (isOwner)
          IconButton(
            tooltip: tr('Mời bạn cùng sửa', 'Invite to edit'),
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => _invite(story),
          ),
        // Rộng: nút Xuất bản nằm trên AppBar. Hẹp: nằm ở thanh dưới.
        if (wide && isOwner)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(child: _publishButton(story)),
          ),
        PopupMenuButton<String>(
          tooltip: tr('Thêm tùy chọn', 'More options'),
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
                child: Text(
                  tr('Xóa câu chuyện', 'Delete story'),
                  style: const TextStyle(color: AppColors.danger),
                ),
              )
            else
              PopupMenuItem(
                value: 'leave',
                child: Text(
                  tr('Rời khỏi câu chuyện', 'Leave story'),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Hẹp: thanh dưới với thứ bậc rõ ràng, Xem trước (viền) và Xuất bản (nút chính).
  Widget _bottomBar(Story story, bool isOwner, String me) {
    return Material(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openPreviewSheet(story, me),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(tr('Xem trước', 'Preview')),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 12),
                  Expanded(child: _publishButton(story)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Bố cục hẹp: một cột như cũ
  // ---------------------------------------------------------------------
  Widget _narrowBody(
      Story story,
      List<StoryBlock> blocks,
      Map<String, StorySource> sources,
      bool canEdit,
      String me,
      int lastOrder,
      ) {
    // ListView full chiều rộng để lăn chuột ở hai lề vẫn hoạt động;
    // nội dung được căn giữa bằng padding.
    return LayoutBuilder(
      builder: (context, c) => ListView(
        padding: weaveCenteredPadding(c.maxWidth),
        children: [
          _metaChips(story),
          const SizedBox(height: 12),
          StoryMissingCard(
            questions: story.missing,
            canEdit: canEdit,
            onAnswer: (q) => _answerMissing(q, lastOrder),
            onDismiss: (q) => StoryService.dismissMissing(widget.storyId, q),
          ),
          _droppedNote(story),
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
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Bố cục rộng: các đoạn | chỉnh sửa | xem trước
  // ---------------------------------------------------------------------
  Widget _wideBody(
      Story story,
      List<StoryBlock> blocks,
      Map<String, StorySource> sources,
      bool canEdit,
      String me,
      int lastOrder,
      ) {
    StoryBlock? selected;
    for (final b in blocks) {
      if (b.id == _selectedBlockId) selected = b;
    }
    selected ??= blocks.isEmpty ? null : blocks.first;
    final selectedIndex = selected == null ? -1 : blocks.indexOf(selected);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cột 1: thông tin + danh sách các đoạn
        SizedBox(
          width: _kStoryOutlineWidth,
          // Material (không phải ColoredBox) để ListTile vẽ được màu mục chọn
          child: Material(
            color: AppColors.surface,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _metaChips(story),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: StoryMissingCard(
                    questions: story.missing,
                    canEdit: canEdit,
                    onAnswer: (q) => _answerMissing(q, lastOrder),
                    onDismiss: (q) =>
                        StoryService.dismissMissing(widget.storyId, q),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _droppedNote(story),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    tr('CÁC ĐOẠN (${blocks.length})',
                        'PARTS (${blocks.length})'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                for (var i = 0; i < blocks.length; i++)
                  ListTile(
                    dense: true,
                    // Màu mục đang chọn lấy từ listTileTheme
                    selected: blocks[i].id == selected?.id,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.soft,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                    title: Text(
                      blocks[i].text.trim().isEmpty
                          ? tr('(đoạn trống)', '(empty part)')
                          : blocks[i].text.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectBlock(blocks[i].id, selected?.id),
                  ),
                if (canEdit)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: OutlinedButton.icon(
                      onPressed: () => _addBlock(lastOrder),
                      icon: const Icon(Icons.add),
                      label: Text(tr('Thêm đoạn', 'Add a part')),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // Cột 2: chỉnh sửa đoạn đang chọn
        Expanded(
          flex: 3,
          child: selected == null
              ? Center(
            child: Text(
              tr('Chưa có đoạn nào để chỉnh sửa.',
                  'No parts to edit yet.'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          )
              : _BlockEditor(
            key: ValueKey(selected.id),
            block: selected,
            index: selectedIndex,
            canEdit: canEdit,
            onSave: (text) => StoryService.updateBlockText(
                widget.storyId, selected!.id, text),
            onDelete: () => _delete(selected!),
            // Chỉ là cờ, không cần setState
            onDirtyChanged: (v) => _editorDirty = v,
          ),
        ),
        const VerticalDivider(width: 1),
        // Cột 3: xem trước (chỉ đọc)
        Expanded(
          flex: 2,
          child: Material(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    tr('XEM TRƯỚC', 'PREVIEW'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _previewChildren(story, blocks, sources, me),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
        final wide =
            MediaQuery.sizeOf(context).width >= _kStoryDetailWideBreakpoint;

        final scaffold = Scaffold(
          appBar: _appBar(story, isOwner, wide),
          bottomNavigationBar: wide ? null : _bottomBar(story, isOwner, me),
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
                  return wide
                      ? _wideBody(story, blocks, sources, canEdit, me, lastOrder)
                      : _narrowBody(
                      story, blocks, sources, canEdit, me, lastOrder);
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

/// Vùng chỉnh sửa một đoạn (bố cục rộng). Lưu = nút chính, Xóa = nút viền đỏ.
class _BlockEditor extends StatefulWidget {
  final StoryBlock block;
  final int index;
  final bool canEdit;
  final Future<void> Function(String text) onSave;
  final VoidCallback onDelete;

  /// Báo cho màn cha biết đoạn đang sửa có thay đổi chưa lưu hay không.
  final ValueChanged<bool> onDirtyChanged;

  const _BlockEditor({
    super.key,
    required this.block,
    required this.index,
    required this.canEdit,
    required this.onSave,
    required this.onDelete,
    required this.onDirtyChanged,
  });

  @override
  State<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<_BlockEditor> {
  late final TextEditingController _ctrl =
  TextEditingController(text: widget.block.text);
  late String _saved = widget.block.text;
  bool _saving = false;

  bool get _dirty => _ctrl.text.trim() != _saved.trim();
  bool get _canSave => widget.canEdit && _dirty && _ctrl.text.trim().isNotEmpty && !_saving;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      setState(() {});
      widget.onDirtyChanged(_dirty);
    });
  }

  @override
  void didUpdateWidget(covariant _BlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Có người khác sửa đoạn này và mình chưa gõ gì: cập nhật nội dung theo
    if (widget.block.text != oldWidget.block.text && !_dirty) {
      _saved = widget.block.text;
      _ctrl.text = widget.block.text;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final text = _ctrl.text.trim();
    setState(() => _saving = true);
    try {
      await widget.onSave(text);
      _saved = text;
      widget.onDirtyChanged(false);
      messenger.showSnackBar(SnackBar(content: Text(tr('Đã lưu', 'Saved'))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(WeaveSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Đoạn ${widget.index + 1}', 'Part ${widget.index + 1}'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: WeaveSpacing.sm),
              TextField(
                controller: _ctrl,
                readOnly: !widget.canEdit,
                minLines: 8,
                maxLines: null,
              ),
              const SizedBox(height: WeaveSpacing.lg),
              if (widget.canEdit)
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: _saving ? null : widget.onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(tr('Xóa đoạn', 'Delete part')),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _canSave ? _save : null,
                      child: _saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : Text(tr('Lưu', 'Save')),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}