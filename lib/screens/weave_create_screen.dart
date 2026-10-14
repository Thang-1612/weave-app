import 'package:flutter/material.dart';

import '../services/group_service.dart';
import '../services/l10n.dart';
import '../services/weave_service.dart';
import '../theme/app_theme.dart';
import '../widgets/weave_activity_widgets.dart';
import 'weave_detail_screen.dart';

class WeaveCreateScreen extends StatefulWidget {
  /// Nếu có, nhóm được chọn sẵn và không cho đổi.
  final String? groupId;
  const WeaveCreateScreen({super.key, this.groupId});

  @override
  State<WeaveCreateScreen> createState() => _WeaveCreateScreenState();
}

class _WeaveCreateScreenState extends State<WeaveCreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  late final Future<List<GroupInfo>> _groups = _loadGroups();

  GroupInfo? _group;
  DateTimeRange? _range;
  final Set<String> _invitees = {};
  bool _busy = false;

  Future<List<GroupInfo>> _loadGroups() async {
    final list = await GroupService.listMine();
    if (widget.groupId != null) {
      for (final g in list) {
        if (g.id == widget.groupId) {
          _selectGroup(g, notify: false);
        }
      }
    }
    return list;
  }

  void _selectGroup(GroupInfo g, {bool notify = true}) {
    void apply() {
      _group = g;
      _invitees
        ..clear()
        ..addAll(g.memberIds.where((u) => u != WeaveService.me));
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (_title.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(
          content: Text(tr('Hãy nhập tên hoạt động', 'Enter an activity name'))));
      return;
    }
    if (_group == null) {
      messenger.showSnackBar(SnackBar(
          content: Text(tr('Hãy chọn nhóm', 'Pick a group'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final a = await WeaveService.create(
        groupId: _group!.id,
        title: _title.text,
        description: _desc.text,
        startAt: _range?.start,
        endAt: _range?.end,
        inviteeIds: _invitees.toList(),
      );
      nav.pushReplacement(MaterialPageRoute(
          builder: (_) => WeaveDetailScreen(activityId: a.id)));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: Text(t,
        style: const TextStyle(
            fontWeight: FontWeight.w700, color: AppColors.brand)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        title: Text(tr('Tạo hoạt động', 'New activity')),
      ),
      body: FutureBuilder<List<GroupInfo>>(
        future: _groups,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: SelectableText('${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data!;
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Bạn chưa tham gia nhóm nào. Hãy tạo nhóm trước.',
                      'You are not in any group yet. Create a group first.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _title,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: tr('Tên hoạt động', 'Activity name'),
                      hintText: tr('Ví dụ: Đà Lạt cuối tuần', 'e.g. Weekend in Da Lat'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _desc,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: InputDecoration(
                      labelText: tr('Mô tả (không bắt buộc)', 'Description (optional)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (widget.groupId == null) ...[
                    _label(tr('Nhóm', 'Group')),
                    DropdownButtonFormField<GroupInfo>(
                      value: _group,
                      isExpanded: true,
                      decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                      hint: Text(tr('Chọn nhóm', 'Pick a group')),
                      items: [
                        for (final g in groups)
                          DropdownMenuItem(value: g, child: Text(g.name)),
                      ],
                      onChanged: (g) {
                        if (g != null) _selectGroup(g);
                      },
                    ),
                  ],
                  _label(tr('Thời gian dự kiến', 'Planned dates')),
                  OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.event),
                    label: Text(_range == null
                        ? tr('Chọn khoảng ngày (có thể bỏ qua)',
                        'Pick date range (optional)')
                        : weaveRange(_range!.start, _range!.end)),
                  ),
                  if (_group != null) ...[
                    _label(tr('Mời thành viên', 'Invite members')),
                    if (_group!.memberIds.length <= 1)
                      Text(
                        tr('Nhóm này chưa có thành viên nào khác.',
                            'No other members in this group.'),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    for (final uid in _group!.memberIds
                        .where((u) => u != WeaveService.me))
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _invitees.contains(uid),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _invitees.add(uid);
                          } else {
                            _invitees.remove(uid);
                          }
                        }),
                        secondary: WeaveUserAvatar(uid: uid),
                        title: WeaveUserName(uid: uid),
                      ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : Text(tr('Tạo hoạt động', 'Create activity')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}