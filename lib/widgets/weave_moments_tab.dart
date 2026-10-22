import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/weave_activity.dart';
import '../models/weave_moment.dart';
import '../services/image_utils.dart';
import '../services/l10n.dart';
import '../services/weave_moments_service.dart';
import '../services/weave_service.dart';
import '../theme/app_theme.dart';
import 'weave_activity_widgets.dart';

/// Tab "Khoảnh khắc" trong màn hình chi tiết hoạt động.
class WeaveMomentsTab extends StatelessWidget {
  final WeaveActivity activity;
  const WeaveMomentsTab({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WeaveMoment>>(
      stream: WeaveMomentService.watch(activity.id),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: SelectableText('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final moments = snap.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!activity.isEnded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    // Màu nút lấy từ theme (Brand Indigo)
                    child: FilledButton.icon(
                      onPressed: () => _openAddSheet(context),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(tr('Thêm khoảnh khắc', 'Add a moment')),
                    ),
                  ),
                if (moments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      tr('Chưa có khoảnh khắc nào.\nChia sẻ ảnh hoặc vài dòng để cả nhóm cùng nhớ.',
                          'No moments yet.\nShare a photo or a few words so the group remembers.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                for (final m in moments)
                  _MomentCard(
                    key: ValueKey(m.id),
                    activity: activity,
                    moment: m,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(WeaveRadius.card)),
      ),
      builder: (_) => _AddMomentSheet(activityId: activity.id),
    );
  }
}

class _MomentCard extends StatefulWidget {
  final WeaveActivity activity;
  final WeaveMoment moment;
  const _MomentCard({super.key, required this.activity, required this.moment});

  @override
  State<_MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<_MomentCard> {
  // Giải mã base64 một lần, không giải mã lại mỗi lần build.
  late final Uint8List? _bytes = widget.moment.imageBytes;

  WeaveMoment get m => widget.moment;

  /// Tác giả không còn trong danh sách thành viên (đã rời hoạt động).
  bool get _former => !widget.activity.memberIds.contains(m.authorId);

  bool get _canDelete =>
      m.authorId == WeaveService.me ||
          widget.activity.hostId == WeaveService.me;

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Xóa khoảnh khắc?', 'Delete this moment?')),
        content: Text(tr('Khoảnh khắc sẽ bị xóa khỏi hoạt động.',
            'It will be removed from the activity.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('Hủy', 'Cancel'))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('Xóa', 'Delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await WeaveMomentService.delete(widget.activity.id, m.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: _former
                ? const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.soft,
                child: Icon(Icons.person_outline,
                    size: 18, color: AppColors.textSecondary))
                : WeaveUserAvatar(uid: m.authorId),
            title: _former
                ? Text(tr('Thành viên cũ', 'Former member'),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textSecondary))
                : WeaveUserName(
                uid: m.authorId,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(weaveDate(m.createdAt)),
            trailing: _canDelete
                ? IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: tr('Xóa', 'Delete'),
              onPressed: _delete,
            )
                : null,
          ),
          // Mọi ảnh cùng tỷ lệ 4:3 và co theo chiều rộng thẻ
          if (_bytes != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(_bytes,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  gaplessPlayback: true),
            ),
          if (m.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                m.caption,
                style: const TextStyle(height: 1.4, color: AppColors.textPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddMomentSheet extends StatefulWidget {
  final String activityId;
  const _AddMomentSheet({required this.activityId});

  @override
  State<_AddMomentSheet> createState() => _AddMomentSheetState();
}

class _AddMomentSheetState extends State<_AddMomentSheet> {
  final _caption = TextEditingController();
  Uint8List? _image;
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pick() async {
    try {
      final picked =
      await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      setState(() => _busy = true);
      final c = await compressImage(await picked.readAsBytes());
      if (mounted) setState(() => _image = c.bytes);
    } catch (e) {
      _toast('$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _post() async {
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await WeaveMomentService.add(widget.activityId,
          caption: _caption.text, imageBytes: _image);
      nav.pop();
    } catch (e) {
      _toast('$e');
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(WeaveRadius.control),
                      // Xem trước theo cùng tỷ lệ 4:3 như khi hiển thị trong tab
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.memory(_image!,
                            width: double.infinity, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton.filledTonal(
                        onPressed:
                        _busy ? null : () => setState(() => _image = null),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            // Viền và màu focus của ô nhập lấy từ theme
            TextField(
              controller: _caption,
              enabled: !_busy,
              maxLines: 4,
              minLines: 2,
              maxLength: WeaveMomentService.maxCaption,
              decoration: InputDecoration(
                hintText: tr('Bạn muốn nhớ điều gì về khoảnh khắc này?',
                    'What do you want to remember about this moment?'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(_image == null
                      ? tr('Thêm ảnh', 'Add photo')
                      : tr('Đổi ảnh', 'Change photo')),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _post,
                  child: _busy
                      ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : Text(tr('Đăng', 'Post')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}