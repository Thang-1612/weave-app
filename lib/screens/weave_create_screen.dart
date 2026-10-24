import 'package:flutter/material.dart';

import '../services/group_service.dart';
import '../services/l10n.dart';
import '../services/weave_service.dart';
import '../theme/app_theme.dart';
import '../widgets/group_create_sheet.dart';
import '../widgets/weave_activity_widgets.dart';
import '../widgets/weave_error_view.dart';
import 'weave_detail_screen.dart';

/// Từ chiều rộng này trở lên, form chia hai cột: thông tin hoạt động bên trái,
/// mời thành viên bên phải. Dưới mức này: một cột.
const double _kWeaveCreateTwoColumnBreakpoint = 900;
const double _kWeaveCreateWideMaxWidth = 1040;
const double _kWeaveCreateNarrowMaxWidth = 600;

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
  late Future<List<GroupInfo>> _groups = _loadGroups();

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

  Future<void> _createGroup() async {
    final g = await showCreateGroupSheet(context);
    if (g == null || !mounted) return;
    // Tải lại danh sách rồi chọn nhóm theo id: DropdownButton so sánh theo
    // đối tượng, nên phải dùng đúng phiên bản có trong danh sách mới.
    final reload = _loadGroups();
    final list = await reload;
    if (!mounted) return;
    GroupInfo? fresh;
    for (final x in list) {
      if (x.id == g.id) fresh = x;
    }
    setState(() {
      _groups = Future.value(list);
      if (fresh != null) _selectGroup(fresh, notify: false);
    });
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('Hãy nhập tên hoạt động', 'Enter an activity name')),
        ),
      );
      return;
    }
    if (_group == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Hãy chọn nhóm', 'Pick a group'))),
      );
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
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => WeaveDetailScreen(activityId: a.id)),
      );
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
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );

  /// Phần thông tin: tên, mô tả, nhóm, thời gian. Viền, bo góc và màu focus của
  /// các ô nhập lấy từ theme.
  List<Widget> _basicFields(List<GroupInfo> groups) {
    return [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _createGroup,
          icon: const Icon(Icons.group_add_outlined),
          label: Text(tr('Tạo nhóm mới', 'New group')),
        ),
      ),
      TextField(
        controller: _title,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: tr('Tên hoạt động', 'Activity name'),
          hintText: tr('Ví dụ: Đà Lạt cuối tuần', 'e.g. Weekend in Da Lat'),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _desc,
        maxLines: 3,
        maxLength: 300,
        decoration: InputDecoration(
          labelText: tr('Mô tả (không bắt buộc)', 'Description (optional)'),
        ),
      ),
      if (widget.groupId == null) ...[
        _label(tr('Nhóm', 'Group')),
        DropdownButtonFormField<GroupInfo>(
          key: ValueKey(_group?.id),
          initialValue: _group,
          isExpanded: true,
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
        label: Text(
          _range == null
              ? tr(
            'Chọn khoảng ngày (có thể bỏ qua)',
            'Pick date range (optional)',
          )
              : weaveRange(_range!.start, _range!.end),
        ),
      ),
    ];
  }

  /// Phần mời thành viên (chỉ có khi đã chọn nhóm).
  List<Widget> _inviteeFields() {
    final g = _group;
    if (g == null) return const [];
    final others = g.memberIds.where((u) => u != WeaveService.me).toList();
    return [
      _label(tr('Mời thành viên', 'Invite members')),
      if (others.isEmpty)
        Text(
          tr(
            'Nhóm này chưa có thành viên nào khác.',
            'No other members in this group.',
          ),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      for (final uid in others)
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
    ];
  }

  /// Nút tạo hoạt động: hành động chính duy nhất của màn hình (màu theo theme).
  Widget _submitButton() {
    return FilledButton(
      onPressed: _busy ? null : _submit,
      child: _busy
          ? const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.onBrand,
        ),
      )
          : Text(tr('Tạo hoạt động', 'Create activity')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Tạo hoạt động', 'New activity'))),
      body: FutureBuilder<List<GroupInfo>>(
        future: _groups,
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('WeaveCreate: load groups failed: ${snap.error}');
            return WeaveErrorView(
              message: tr('Không tải được danh sách nhóm.', 'Could not load your groups.'),
              onRetry: () => setState(() {
                _groups = _loadGroups();
              }),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data!;
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(
                        'Bạn chưa tham gia nhóm nào. Hãy tạo nhóm trước.',
                        'You are not in any group yet. Create a group first.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _createGroup,
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(tr('Tạo nhóm', 'Create group')),
                    ),
                  ],
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns =
                  constraints.maxWidth >= _kWeaveCreateTwoColumnBreakpoint;

              // ListView chiếm full chiều rộng (lăn chuột ở hai lề vẫn cuộn);
              // nội dung được canh giữa bằng padding, giống các màn khác.
              if (twoColumns) {
                // Rộng: thông tin bên trái, mời thành viên (card) bên phải.
                return ListView(
                  padding: weaveCenteredPadding(
                    constraints.maxWidth,
                    maxWidth: _kWeaveCreateWideMaxWidth,
                    h: WeaveSpacing.xl,
                    top: WeaveSpacing.xl,
                    bottom: WeaveSpacing.xl,
                  ),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ..._basicFields(groups),
                              const SizedBox(height: 24),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _submitButton(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: WeaveSpacing.xl),
                        SizedBox(
                          width: 340,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                WeaveSpacing.lg,
                                0,
                                WeaveSpacing.lg,
                                WeaveSpacing.lg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _group == null
                                    ? [
                                  _label(
                                    tr(
                                      'Mời thành viên',
                                      'Invite members',
                                    ),
                                  ),
                                  Text(
                                    tr(
                                      'Chọn nhóm để mời thành viên.',
                                      'Pick a group to invite members.',
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ]
                                    : _inviteeFields(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              // Hẹp: một cột như cũ.
              return ListView(
                padding: weaveCenteredPadding(
                  constraints.maxWidth,
                  maxWidth: _kWeaveCreateNarrowMaxWidth,
                  h: 16,
                  top: 16,
                  bottom: 16,
                ),
                children: [
                  ..._basicFields(groups),
                  ..._inviteeFields(),
                  const SizedBox(height: 24),
                  _submitButton(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}