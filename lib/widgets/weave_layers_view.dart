import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/weave_layer.dart';
import '../services/l10n.dart';
import '../services/friend_service.dart';
import '../services/layer_access.dart';
import '../services/layer_service.dart';
import 'audience_picker.dart';
import 'layer_locked_hint.dart';
import 'layer_tab_bar.dart';
import 'post_blocks.dart';

/// Hiển thị nội dung của một bài Weave: lớp gốc + các lớp thêm mà người xem
/// được phép thấy, chuyển qua lại bằng thanh tab.
///
/// Lớp gốc (post.blocks) luôn hiện ngay; các lớp thêm được tải sau khi mở.
class WeaveLayersView extends StatefulWidget {
  final Post post;

  /// Kiểm tra người xem có phải bạn bè của tác giả không (cho lớp 'friends').
  ///
  /// Mặc định dùng FriendService.isFriend. Chỉ truyền vào khi muốn thay thế
  /// (ví dụ khi thử nghiệm).
  final Future<bool> Function(String authorId)? isFriend;

  const WeaveLayersView({super.key, required this.post, this.isFriend});

  @override
  State<WeaveLayersView> createState() => _WeaveLayersViewState();
}

class _WeaveLayersViewState extends State<WeaveLayersView> {
  static const _baseId = '_base';

  List<WeaveLayer> _layers = const [];
  int _locked = 0;
  String _selected = _baseId;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WeaveLayersView old) {
    super.didUpdateWidget(old);
    if (_signature(old.post) != _signature(widget.post)) _load();
  }

  /// Thay đổi khi lớp được thêm, xóa, đổi tên, đổi quyền hoặc đổi thứ tự.
  String _signature(Post p) => [
    for (final m in p.layerMetas)
      '${m.id}|${m.name}|${m.audienceType}|${m.groupId}|${m.order}',
  ].join(';');

  Future<void> _load() async {
    final token = ++_loadToken;
    final post = widget.post;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final access = await LayerAccess.load(
        viewerId: uid,
        authorId: post.authorId,
        isFriend: widget.isFriend ?? FriendService.isFriend,
      );
      final layers =
      await LayerService.fetchVisible(post.ref, post.layerMetas, access);
      final locked = LayerService.lockedMetas(post.layerMetas, access).length;
      if (!mounted || token != _loadToken) return;
      setState(() {
        _layers = layers;
        _locked = locked;
        if (_selected != _baseId && !layers.any((l) => l.id == _selected)) {
          _selected = _baseId;
        }
      });
    } catch (_) {
      // Lỗi mạng hoặc quyền: vẫn hiện lớp gốc, không làm hỏng thẻ bài
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    final items = <LayerTabItem>[
      LayerTabItem(
        id: _baseId,
        label: audienceLabel(post.visibility),
        icon: audienceIcon(post.visibility),
      ),
      for (final l in _layers)
        LayerTabItem(
          id: l.id,
          label: l.name.isNotEmpty
              ? l.name
              : layerAudienceLabel(l.audience.type),
          icon: layerAudienceIcon(l.audience.type),
        ),
    ];

    WeaveLayer? current;
    for (final l in _layers) {
      if (l.id == _selected) current = l;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_layers.isNotEmpty) ...[
          LayerTabBar(
            items: items,
            selectedId: _selected,
            onSelected: (id) => setState(() => _selected = id),
          ),
          const SizedBox(height: 10),
        ],
        if (current == null)
          PostBlocks(post: post)
        else if (current.blocks.isEmpty)
          Text(
            tr('Lớp này chưa có nội dung', 'This layer has no content yet'),
            style: const TextStyle(color: AppColors.textSecondary),
          )
        else
          PostBlocks.layer(
            key: ValueKey('layer_${current.id}'),
            blocks: current.blocks,
          ),
        LayerLockedHint(count: _locked),
      ],
    );
  }
}