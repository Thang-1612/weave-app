import 'package:flutter/material.dart';

import '../models/weave_activity.dart';
import '../models/weave_poll.dart';
import '../services/l10n.dart';
import '../services/maps_launcher.dart';
import '../services/weave_service.dart';
import '../theme/app_theme.dart';
import '../widgets/place_picker_screen.dart';
import '../widgets/weave_activity_widgets.dart';
import '../widgets/weave_error_view.dart';
import '../widgets/weave_extras_widgets.dart';
import '../widgets/weave_moments_tab.dart';
import '../widgets/weave_state_views.dart';

/// Từ bề rộng KHUNG CHỨA này trở lên: Tổng quan cố định bên trái, các tab bên
/// phải. (Đo bằng LayoutBuilder chứ không phải cả cửa sổ, vì khung điều hướng
/// desktop có thể đã chiếm một phần chiều ngang bằng sidebar.)
/// 960 = 400 cho Tổng quan + tối thiểu 560 cho các tab.
const double _kWeaveDetailWideBreakpoint = 960;
const double _kWeaveOverviewWidth = 400;

// Tab "Nhiệm vụ" đã được tạm ẩn khỏi bản beta (đưa vào backlog).
// Khi hoàn thiện: thêm lại Tab + nội dung ở cả hai bố cục và tăng length.

class WeaveDetailScreen extends StatefulWidget {
  final String activityId;
  const WeaveDetailScreen({super.key, required this.activityId});

  @override
  State<WeaveDetailScreen> createState() => _WeaveDetailScreenState();
}

class _WeaveDetailScreenState extends State<WeaveDetailScreen> {
  // Tạo stream một lần (không tạo lại mỗi lần build). Nút Thử lại gán stream mới.
  late Stream<WeaveActivity?> _stream = WeaveService.watchOne(
    widget.activityId,
  );

  Widget _plain(Widget body) => Scaffold(appBar: AppBar(), body: body);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WeaveActivity?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('WeaveDetail: load failed: ${snap.error}');
          return _plain(
            WeaveErrorView(
              message: tr(
                'Không tải được hoạt động.',
                'Could not load this activity.',
              ),
              onRetry: () => setState(
                    () => _stream = WeaveService.watchOne(widget.activityId),
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return _plain(const WeaveLoadingView());
        }
        final a = snap.data;
        if (a == null) {
          return _plain(
            WeaveEmptyView(
              icon: Icons.event_busy_outlined,
              title: tr(
                'Hoạt động không còn tồn tại.',
                'This activity no longer exists.',
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) =>
          constraints.maxWidth >= _kWeaveDetailWideBreakpoint
              ? _wide(a)
              : _narrow(a),
        );
      },
    );
  }

  // ───────────── Hẹp (điện thoại): 3 tab ─────────────
  Widget _narrow(WeaveActivity a) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(a.title, overflow: TextOverflow.ellipsis),
          // AppBar nền sáng: tab dùng màu thương hiệu (trước đây là chữ trắng)
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.brand,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.brand,
            tabs: [
              Tab(text: tr('Tổng quan', 'Overview')),
              Tab(text: tr('Bình chọn', 'Polls')),
              Tab(text: tr('Khoảnh khắc', 'Moments')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(activity: a),
            _PollsTab(activity: a),
            WeaveMomentsTab(activity: a),
          ],
        ),
      ),
    );
  }

  // ───────────── Rộng (desktop): Tổng quan | Bình chọn, Khoảnh khắc ─────────────
  Widget _wide(WeaveActivity a) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: Text(a.title, overflow: TextOverflow.ellipsis)),
        body: Row(
          children: [
            // Material (không phải ColoredBox) để ListTile thành viên vẽ được hiệu ứng chạm
            SizedBox(
              width: _kWeaveOverviewWidth,
              child: Material(
                color: AppColors.surface,
                child: _OverviewTab(activity: a),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Material(
                    color: AppColors.surface,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelColor: AppColors.brand,
                          unselectedLabelColor: AppColors.textSecondary,
                          indicatorColor: AppColors.brand,
                          tabs: [
                            Tab(text: tr('Bình chọn', 'Polls')),
                            Tab(text: tr('Khoảnh khắc', 'Moments')),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _PollsTab(activity: a),
                        WeaveMomentsTab(activity: a),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  final WeaveActivity activity;
  const _OverviewTab({required this.activity});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _busy = false;

  // Tạo stream thành viên một lần: tránh đăng ký lại mỗi khi đổi _busy
  // (làm danh sách thành viên nhấp nháy rỗng).
  late final Stream<List<WeaveMember>> _members = WeaveService.watchMembers(
    widget.activity.id,
  );

  WeaveActivity get a => widget.activity;
  bool get _isHost => a.hostId == WeaveService.me;

  Future<void> _run(
      Future<void> Function() action, {
        String? doneMsg,
        bool popAfter = false,
      }) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (doneMsg != null) {
        messenger.showSnackBar(SnackBar(content: Text(doneMsg)));
      }
      if (popAfter) {
        nav.pop();
        return;
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _busy = false);
  }

  /// [danger] = true: nút xác nhận màu đỏ (hành động nguy hiểm, như rời hoạt động).
  /// [confirmLabel]: nhãn nút xác nhận, nên nêu rõ hành động thay vì "Đồng ý".
  Future<bool> _confirm(
      String title,
      String body, {
        bool danger = false,
        String? confirmLabel,
      }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.pop(c, true),
            child: Text(confirmLabel ?? tr('Đồng ý', 'OK')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Widget _heading(String t) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _info(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final notSet = tr('Chưa chốt', 'Not decided');
    return StreamBuilder<List<WeaveMember>>(
      stream: _members,
      builder: (context, snap) {
        final members = snap.data ?? const <WeaveMember>[];
        WeaveMember? mine;
        for (final m in members) {
          if (m.userId == WeaveService.me) mine = m;
        }
        final going = members.where((m) => m.rsvp == RsvpStatus.going).length;

        // ListView chiếm full chiều rộng khung chứa (lăn chuột ở lề vẫn cuộn),
        // nội dung được canh giữa bằng padding thay vì ConstrainedBox.
        return LayoutBuilder(
          builder: (context, c) => ListView(
            padding: weaveCenteredPadding(c.maxWidth, top: 16, bottom: 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: WeaveStatusChip(status: a.status),
              ),
              if (a.description != null) ...[
                const SizedBox(height: 12),
                Text(a.description!, style: const TextStyle(height: 1.4)),
              ],
              const SizedBox(height: 16),
              _info(
                Icons.event,
                tr('Ngày', 'Date'),
                a.lockedDate != null
                    ? weaveDate(a.lockedDate!)
                    : '${weaveRange(a.startAt, a.endAt)} (${tr('dự kiến', 'planned')})',
              ),
              _info(
                Icons.place,
                tr('Địa điểm', 'Place'),
                a.lockedPlace?.name ?? notSet,
              ),
              if ((a.lockedPlace?.address ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 30, bottom: 8),
                  child: Text(
                    a.lockedPlace!.address!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (a.lockedPlace?.lat != null && a.lockedPlace?.lng != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: WeaveMapPreview(place: a.lockedPlace!),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (a.lockedPlace != null)
                    OutlinedButton.icon(
                      onPressed: () =>
                          openInGoogleMaps(context, a.lockedPlace!),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(tr('Mở Google Maps', 'Open in Google Maps')),
                    ),
                  if (_isHost && !a.isEnded)
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                        final p = await pickWeavePlace(
                          context,
                          initial: a.lockedPlace,
                        );
                        if (p == null || !mounted) return;
                        await _run(
                              () => WeaveService.lockPlace(a.id, p),
                          doneMsg: tr('Đã chọn địa điểm', 'Place saved'),
                        );
                      },
                      icon: const Icon(Icons.edit_location_alt_outlined),
                      label: Text(
                        a.lockedPlace == null
                            ? tr('Chọn địa điểm', 'Choose place')
                            : tr('Đổi địa điểm', 'Change place'),
                      ),
                    ),
                ],
              ),
              if (mine != null && !a.isEnded) ...[
                _heading(tr('Bạn có tham gia không?', 'Are you in?')),
                WeaveRsvpSelector(
                  current: mine.rsvp,
                  enabled: !_busy,
                  onChanged: (s) =>
                      _run(() => WeaveService.updateRsvp(a.id, s)),
                ),
              ],
              _heading(
                '${tr('Thành viên', 'Members')} · $going/${members.length} ${tr('tham gia', 'going')}',
              ),
              for (final m in members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: WeaveUserAvatar(uid: m.userId),
                  title: WeaveUserName(
                    uid: m.userId,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    m.isHost
                        ? tr('Chủ hoạt động', 'Host')
                        : weaveRsvpLabel(m.rsvp),
                  ),
                ),
              const SizedBox(height: 20),
              // Mỗi trạng thái chỉ có một nút chính nổi bật (màu theo theme)
              if (_isHost && a.status == WeaveStatus.planning)
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                        () => WeaveService.start(a.id),
                    doneMsg: tr(
                      'Hoạt động đã bắt đầu',
                      'Activity started',
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(tr('Bắt đầu hoạt động', 'Start activity')),
                ),
              if (_isHost && a.status == WeaveStatus.active)
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                    // Đã bỏ nhắc tới "nhiệm vụ" vì tab này tạm ẩn khỏi beta.
                    // Nếu WeaveService.end vẫn dùng dữ liệu nhiệm vụ để dựng
                    // nhật ký thì hãy kiểm tra lại câu chữ này.
                    final ok = await _confirm(
                      tr('Kết thúc hoạt động?', 'End activity?'),
                      tr(
                        'Sau khi kết thúc, nhật ký nhóm sẽ được tạo từ ảnh và khoảnh khắc của mọi người.',
                        'Once ended, a group journal is built from everyone’s photos and moments.',
                      ),
                      confirmLabel: tr('Kết thúc', 'End'),
                    );
                    if (ok) {
                      _run(
                            () => WeaveService.end(a.id),
                        doneMsg: tr(
                          'Đã kết thúc hoạt động',
                          'Activity ended',
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.flag),
                  label: Text(tr('Kết thúc hoạt động', 'End activity')),
                ),
              // Rời hoạt động: nút viền màu đỏ Danger + hộp xác nhận
              if (!_isHost && !a.isEnded)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  onPressed: _busy
                      ? null
                      : () async {
                    final ok = await _confirm(
                      tr('Rời hoạt động?', 'Leave activity?'),
                      tr(
                        'Bạn sẽ không còn thấy hoạt động này.',
                        'You will no longer see this activity.',
                      ),
                      danger: true,
                      confirmLabel: tr('Rời', 'Leave'),
                    );
                    if (ok) {
                      _run(
                            () => WeaveService.leave(a.id),
                        popAfter: true,
                      );
                    }
                  },
                  child: Text(tr('Rời hoạt động', 'Leave activity')),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PollsTab extends StatefulWidget {
  final WeaveActivity activity;
  const _PollsTab({required this.activity});

  @override
  State<_PollsTab> createState() => _PollsTabState();
}

class _PollsTabState extends State<_PollsTab> {
  // Tạo stream một lần. Nút Thử lại gán stream mới.
  late Stream<List<WeavePoll>> _stream = WeaveService.watchPolls(
    widget.activity.id,
  );

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final isHost = activity.hostId == WeaveService.me;
    return StreamBuilder<List<WeavePoll>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('WeaveDetail polls: load failed: ${snap.error}');
          return WeaveErrorView(
            message: tr('Không tải được bình chọn.', 'Could not load polls.'),
            onRetry: () => setState(
                  () => _stream = WeaveService.watchPolls(widget.activity.id),
            ),
          );
        }
        if (!snap.hasData) {
          return const WeaveLoadingView();
        }
        final polls = snap.data!;
        return LayoutBuilder(
          builder: (context, c) => ListView(
            padding: weaveCenteredPadding(c.maxWidth, top: 16, bottom: 16),
            children: [
              if (!activity.isEnded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  // Tonal (nhấn nhẹ): ở bố cục rộng, Tổng quan đã có nút chính
                  // (Bắt đầu / Kết thúc hoạt động) hiển thị cùng lúc.
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        showWeaveCreatePollSheet(context, activity.id),
                    icon: const Icon(Icons.add),
                    label: Text(tr('Tạo bình chọn', 'New poll')),
                  ),
                ),
              if (polls.isEmpty)
                WeaveEmptyView(
                  icon: Icons.poll_outlined,
                  title: tr('Chưa có bình chọn nào.', 'No polls yet.'),
                  description: tr(
                    'Tạo một bình chọn để cùng chọn địa điểm hoặc ngày.',
                    'Create one to pick a place or a date together.',
                  ),
                ),
              for (final p in polls)
                WeavePollCard(activityId: activity.id, poll: p, isHost: isHost),
            ],
          ),
        );
      },
    );
  }
}