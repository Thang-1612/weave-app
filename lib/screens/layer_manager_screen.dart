import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/weave_layer.dart';
import '../services/group_service.dart';
import '../services/l10n.dart';
import '../services/layer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audience_picker.dart';
import '../widgets/layer_audience_picker.dart';
import '../widgets/layer_tab_bar.dart';
import 'close_friend_screen.dart';

/// Màn hình của tác giả: thêm, đổi tên, đổi quyền xem, bật/tắt bình luận,
/// sắp xếp và xóa các lớp của một bài, không phải đăng lại bài.
class LayerManagerScreen extends StatefulWidget {
  final Post post;

  const LayerManagerScreen({super.key, required this.post});

  @override
  State<LayerManagerScreen> createState() => _LayerManagerScreenState();
}

class _LayerManagerScreenState extends State<LayerManagerScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
  widget.post.ref.collection('layers').orderBy('order').snapshots();

  @override
  void initState() {
    super.initState();
    // Nạp tên nhóm để hiện đúng tên thay vì "Nhóm riêng"
    GroupService.listMine().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  Future<void> _run(Future<void> Function() fn) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await fn();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _add() async {
    // Hình dạng và màu nền của bottom sheet lấy từ bottomSheetTheme.
    final r = await showModalBottomSheet<_NewLayer>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const _AddLayerSheet(),
    );
    if (r == null || !mounted) return;
    await _run(() => LayerService.addLayer(
      widget.post.ref,
      authorId: widget.post.authorId,
      name: r.name.isEmpty ? layerAudienceLabel(r.audience.type) : r.name,
      audience: r.audience,
      blocks: r.text.isEmpty
          ? <Map<String, dynamic>>[]
          : [
        {'type': 'text', 'text': r.text},
      ],
    ));
    if (mounted) setState(() {}); // cập nhật tên nhóm vừa tạo
  }

  Future<void> _changeAudience(WeaveLayer l) async {
    final picked = await showLayerAudiencePicker(context, current: l.audience);
    if (picked == null || picked == l.audience || !mounted) return;
    await _run(() => LayerService.setAudience(widget.post.ref, l.id, picked));
    if (mounted) setState(() {});
  }

  Future<void> _rename(WeaveLayer l) async {
    final name = await showLayerNameDialog(
      context,
      title: tr('Đổi tên lớp', 'Rename layer'),
      initial: l.name,
    );
    if (name == null || name.trim().isEmpty || name.trim() == l.name) return;
    await _run(() => LayerService.rename(widget.post.ref, l.id, name.trim()));
  }

  Future<void> _delete(WeaveLayer l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Xóa lớp "${l.name}"?', 'Delete layer "${l.name}"?')),
        content: Text(tr(
          'Nội dung của lớp sẽ bị xóa vĩnh viễn, không khôi phục được.',
          'The content of this layer will be permanently deleted.',
        )),
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
    if (ok != true || !mounted) return;
    await _run(() => LayerService.deleteLayer(widget.post.ref, l.id));
  }

  String _preview(WeaveLayer l) {
    for (final b in l.blocks) {
      if (b['type'] == 'text') {
        final t = (b['text'] as String? ?? '').trim();
        if (t.isNotEmpty) return t;
      }
    }
    if (l.blocks.isEmpty) {
      return tr('Chưa có nội dung', 'No content yet');
    }
    final images = l.blocks.where((b) => b['type'] == 'image').length;
    if (images > 0) return tr('$images ảnh', '$images photos');
    return tr('${l.blocks.length} khối nội dung',
        '${l.blocks.length} content blocks');
  }

  // Card lấy màu, viền, bo góc từ cardTheme.
  Widget _card({required Widget child}) => Card(
    margin: const EdgeInsets.symmetric(vertical: 5),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );

  Widget _buildHeader(bool empty) {
    final v = widget.post.visibility;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.soft,
                child: Icon(audienceIcon(v), color: AppColors.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tr('Lớp gốc', 'Base layer')} · ${audienceLabel(v)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      tr(
                        'Là nội dung bài đăng. Đổi đối tượng ở menu ⋯ của bài.',
                        'This is the post itself. Change its audience from the post ⋯ menu.',
                      ),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Text(
            empty
                ? tr(
              'Chưa có lớp nào. Bấm "Thêm lớp" để chia sẻ thêm nội dung cho bạn thân hoặc một nhóm riêng.',
              'No layers yet. Tap "Add layer" to share more with close friends or a private group.',
            )
                : tr('Kéo ⠿ để sắp xếp thứ tự các lớp',
                'Drag ⠿ to reorder layers'),
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildLayer(List<WeaveLayer> layers, int i) {
    final l = layers[i];
    return KeyedSubtree(
      key: ValueKey(l.id),
      child: _card(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 2, right: 8),
                    child: Icon(Icons.drag_indicator,
                        color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.name.isEmpty
                            ? layerAudienceLabel(l.audience.type)
                            : l.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _preview(l),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (v) {
                    if (v == 'rename') _rename(l);
                    if (v == 'delete') _delete(l);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'rename',
                      child: Text(tr('Đổi tên', 'Rename')),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        tr('Xóa lớp', 'Delete layer'),
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: ActionChip(
                    avatar: Icon(layerAudienceIcon(l.audience.type), size: 16),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            layerAudienceText(l.audience),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                    onPressed: () => _changeAudience(l),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  tr('Bình luận', 'Comments'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                Switch(
                  value: l.commentsEnabled,
                  onChanged: (v) => _run(
                        () => LayerService.setCommentsEnabled(
                      widget.post.ref,
                      l.id,
                      v,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Quản lý lớp', 'Manage layers')),
        actions: [
          IconButton(
            tooltip: tr('Danh sách bạn thân', 'Close friends'),
            icon: const Icon(Icons.favorite_border),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CloseFriendsScreen()),
            ),
          ),
        ],
      ),
      // Màu và bo góc của FAB lấy từ floatingActionButtonTheme.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(tr('Thêm lớp', 'Add layer')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final layers = snap.data!.docs.map(WeaveLayer.fromDoc).toList();
              return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                header: _buildHeader(layers.isEmpty),
                itemCount: layers.length,
                onReorderItem: (oldIndex, newIndex) {
                  final ids = [for (final l in layers) l.id];
                  ids.insert(newIndex, ids.removeAt(oldIndex));
                  _run(() => LayerService.reorder(widget.post.ref, ids));
                },
                itemBuilder: (_, i) => _buildLayer(layers, i),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NewLayer {
  final String name;
  final LayerAudience audience;
  final String text;

  const _NewLayer(this.name, this.audience, this.text);
}

class _AddLayerSheet extends StatefulWidget {
  const _AddLayerSheet();

  @override
  State<_AddLayerSheet> createState() => _AddLayerSheetState();
}

class _AddLayerSheetState extends State<_AddLayerSheet> {
  final _name = TextEditingController();
  final _text = TextEditingController();
  LayerAudience _audience = const LayerAudience(LayerAudience.kClose);

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickAudience() async {
    final picked = await showLayerAudiencePicker(context, current: _audience);
    if (picked != null && mounted) setState(() => _audience = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Thêm lớp mới', 'Add a new layer'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                maxLength: 40,
                decoration: InputDecoration(
                  hintText: tr('Tên lớp (ví dụ: Lớp 12A)',
                      'Layer name (e.g. Class 12A)'),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: Icon(layerAudienceIcon(_audience.type), size: 16),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(layerAudienceText(_audience)),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                  onPressed: _pickAudience,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: tr('Nội dung chữ (không bắt buộc)',
                      'Text content (optional)'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _NewLayer(_name.text.trim(), _audience, _text.text.trim()),
                  ),
                  child: Text(tr('Thêm lớp', 'Add layer')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}