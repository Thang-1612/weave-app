import 'package:flutter/material.dart';

import '../models/weave_layer.dart';
import '../services/group_service.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import 'layer_tab_bar.dart';

String layerAudienceHint(String type) {
  switch (type) {
    case LayerAudience.kFriends:
      return tr(
        'Những người đang là bạn bè của bạn',
        'People who are currently your friends',
      );
    case LayerAudience.kClose:
      return tr(
        'Chỉ những người trong danh sách bạn thân của bạn',
        'Only people on your close friends list',
      );
    case LayerAudience.kGroup:
      return tr(
        'Chỉ thành viên của một nhóm riêng bạn chọn',
        'Only members of a private group you choose',
      );
    case LayerAudience.kMe:
      return tr('Chỉ bạn xem được', 'Only you can see it');
    default:
      return tr('Mọi người dùng trong ứng dụng', 'Everyone in the app');
  }
}

/// Nhãn hiển thị của đối tượng: nhóm thì hiện tên nhóm nếu đã biết.
String layerAudienceText(LayerAudience a) {
  if (a.isGroup) {
    final n = GroupService.nameOf(a.groupId);
    if (n != null && n.isNotEmpty) return n;
  }
  return layerAudienceLabel(a.type);
}

/// Bảng chọn đối tượng cho một lớp. Chọn "Nhóm riêng" sẽ mở tiếp bảng chọn
/// (hoặc tạo) nhóm. Trả về null nếu người dùng đóng bảng.
Future<LayerAudience?> showLayerAudiencePicker(
  BuildContext context, {
  required LayerAudience current,
  String? title,
}) async {
  final type = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title ?? tr('Ai xem được lớp này?', 'Who can see this layer?'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final v in LayerAudience.kAll)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.soft,
                  child: Icon(layerAudienceIcon(v), color: AppColors.brand),
                ),
                title: Text(
                  v == LayerAudience.kGroup && current.isGroup
                      ? layerAudienceText(current)
                      : layerAudienceLabel(v),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(layerAudienceHint(v)),
                trailing: current.type == v
                    ? const Icon(Icons.check_circle, color: AppColors.brand)
                    : null,
                onTap: () => Navigator.of(ctx).pop(v),
              ),
          ],
        ),
      ),
    ),
  );
  if (type == null || !context.mounted) return null;
  if (type != LayerAudience.kGroup) return LayerAudience(type);

  final group = await showModalBottomSheet<GroupInfo>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _GroupPickerSheet(currentGroupId: current.groupId),
  );
  if (group == null) return null;
  return LayerAudience(LayerAudience.kGroup, groupId: group.id);
}

class _GroupPickerSheet extends StatefulWidget {
  final String? currentGroupId;

  const _GroupPickerSheet({this.currentGroupId});

  @override
  State<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends State<_GroupPickerSheet> {
  late final Future<List<GroupInfo>> _future = GroupService.listMine();

  Future<void> _create() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await showLayerNameDialog(
      context,
      title: tr('Tạo nhóm riêng', 'Create a private group'),
      hint: tr('Tên nhóm (ví dụ: Lớp 12A)', 'Group name (e.g. Class 12A)'),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      final g = await GroupService.create(name);
      if (mounted) Navigator.of(context).pop(g);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('Chọn nhóm riêng', 'Choose a private group'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<List<GroupInfo>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('${snap.error}'),
                    );
                  }
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final groups = snap.data!;
                  if (groups.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        tr('Bạn chưa có nhóm nào.', 'You have no groups yet.'),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final g in groups)
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.soft,
                            child: Icon(
                              Icons.groups_outlined,
                              color: AppColors.brand,
                            ),
                          ),
                          title: Text(
                            g.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            tr(
                              '${g.memberIds.length} thành viên',
                              '${g.memberIds.length} members',
                            ),
                          ),
                          trailing: widget.currentGroupId == g.id
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.brand,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(g),
                        ),
                    ],
                  );
                },
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.soft,
                child: Icon(Icons.add, color: AppColors.brand),
              ),
              title: Text(
                tr('Tạo nhóm mới', 'Create a new group'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: _create,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp nhập một dòng chữ ngắn (tên lớp, tên nhóm). Trả về null nếu hủy.
Future<String?> showLayerNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  int maxLength = 40,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: title,
      initial: initial,
      hint: hint,
      maxLength: maxLength,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String? hint;
  final int maxLength;

  const _NameDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.maxLength,
  });

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          onSubmitted: (v) => Navigator.of(context).pop(v),
          decoration: InputDecoration(hintText: widget.hint),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Hủy', 'Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(tr('Lưu', 'Save')),
        ),
      ],
    );
  }
}
