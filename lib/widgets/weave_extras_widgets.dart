import 'package:flutter/material.dart';

import '../models/weave_poll.dart';
import '../services/l10n.dart';
import '../services/weave_service.dart';
import '../theme/app_theme.dart';
import 'weave_activity_widgets.dart';

// ======================================================================
// POLL
// ======================================================================

class WeavePollCard extends StatelessWidget {
  final String activityId;
  final WeavePoll poll;
  final bool isHost;
  const WeavePollCard({
    super.key,
    required this.activityId,
    required this.poll,
    required this.isHost,
  });

  void _snack(BuildContext context, Object e) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));

  Future<void> _toggle(
      BuildContext context, String optionId, List<String> mine) async {
    final List<String> next;
    if (poll.multi) {
      next = mine.contains(optionId)
          ? (List<String>.of(mine)..remove(optionId))
          : [...mine, optionId];
    } else {
      next = mine.contains(optionId) ? <String>[] : [optionId];
    }
    try {
      await WeaveService.vote(activityId, poll.id, next);
    } catch (e) {
      if (context.mounted) _snack(context, e);
    }
  }

  Future<void> _close(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Chốt kết quả?', 'Close this poll?')),
        content: Text(poll.kind == PollKind.place
            ? tr('Lựa chọn nhiều phiếu nhất sẽ thành địa điểm của hoạt động.',
            'The top choice becomes the activity place.')
            : tr('Lựa chọn nhiều phiếu nhất sẽ thành ngày của hoạt động.',
            'The top choice becomes the activity date.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('Hủy', 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('Chốt', 'Close'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await WeaveService.closePoll(activityId, poll);
    } catch (e) {
      if (context.mounted) _snack(context, e);
    }
  }

  Widget _statusChip() {
    final String text;
    final Color bg;
    final Color fg;
    if (poll.closed) {
      text = tr('Đã chốt', 'Closed');
      bg = const Color(0xFFEEEEEE);
      fg = const Color(0xFF616161);
    } else if (poll.isExpired) {
      text = tr('Hết hạn', 'Expired');
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
    } else {
      text = tr('Đang mở', 'Open');
      bg = const Color(0xFFE7F7EC);
      fg = const Color(0xFF2E7D32);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style:
          TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _option(
      BuildContext context,
      WeavePollOption o, {
        required int n,
        required int total,
        required bool selected,
        required bool winner,
        required List<String> voters,
        required List<String> mine,
      }) {
    final pct = total == 0 ? 0.0 : n / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: poll.isOpen ? () => _toggle(context, o.id, mine) : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected || winner ? AppColors.brand : AppColors.border,
              width: selected || winner ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct,
                    child:
                    Container(color: AppColors.brand.withOpacity(0.12)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        winner
                            ? Icons.emoji_events
                            : selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: selected || winner
                            ? AppColors.brand
                            : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if ((o.address ?? '').isNotEmpty)
                              Text(o.address!,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      if (voters.isNotEmpty)
                        WeaveAvatarStack(uids: voters, max: 3),
                      const SizedBox(width: 8),
                      Text('$n',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: StreamBuilder<List<WeaveVote>>(
          stream: WeaveService.watchVotes(activityId, poll.id),
          builder: (context, snap) {
            final votes = snap.data ?? const <WeaveVote>[];
            final tally = weaveTally(poll, votes);
            final total = votes.where((v) => v.optionIds.isNotEmpty).length;
            final mine = votes
                .where((v) => v.userId == WeaveService.me)
                .expand((v) => v.optionIds)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                        poll.kind == PollKind.place
                            ? Icons.place
                            : Icons.event,
                        color: AppColors.brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(poll.question,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    '$total ${tr('người đã bầu', 'voted')}',
                    if (poll.multi) tr('chọn nhiều', 'multiple choice'),
                    if (poll.closesAt != null && !poll.closed)
                      '${tr('hạn', 'ends')} ${weaveDate(poll.closesAt!)}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                for (final o in poll.options)
                  _option(
                    context,
                    o,
                    n: tally[o.id] ?? 0,
                    total: total,
                    selected: mine.contains(o.id),
                    winner: poll.closed && poll.winnerOptionId == o.id,
                    voters: [
                      for (final v in votes)
                        if (v.optionIds.contains(o.id)) v.userId
                    ],
                    mine: mine,
                  ),
                if (isHost && !poll.closed)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () => _close(context),
                      child: Text(tr('Chốt kết quả', 'Close poll')),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> showWeaveCreatePollSheet(
    BuildContext context, String activityId) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreatePollSheet(activityId: activityId),
    );

class _CreatePollSheet extends StatefulWidget {
  final String activityId;
  const _CreatePollSheet({required this.activityId});

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  PollKind _kind = PollKind.place;
  final _question = TextEditingController();
  final List<TextEditingController> _places = [
    TextEditingController(),
    TextEditingController(),
  ];
  final List<DateTime> _dates = [];
  bool _multi = false;
  int? _closeHours; // null = không hạn
  bool _busy = false;

  String get _defaultQuestion => _kind == PollKind.place
      ? tr('Mình đi đâu?', 'Where should we go?')
      : tr('Mình đi ngày nào?', 'Which day works?');

  Future<void> _addDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null) return;
    final day = DateTime(d.year, d.month, d.day);
    if (!_dates.contains(day)) setState(() => _dates.add(day));
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final List<WeavePollOption> options;
    if (_kind == PollKind.place) {
      final names = _places
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();
      options = [
        for (var i = 0; i < names.length; i++)
          WeavePollOption(id: 'o$i', label: names[i]),
      ];
    } else {
      final ds = List<DateTime>.of(_dates)..sort();
      options = [
        for (var i = 0; i < ds.length; i++)
          WeavePollOption(id: 'o$i', label: weaveDate(ds[i]), date: ds[i]),
      ];
    }
    if (options.length < 2) {
      messenger.showSnackBar(SnackBar(
          content: Text(tr('Cần ít nhất 2 lựa chọn', 'Add at least 2 options'))));
      return;
    }

    setState(() => _busy = true);
    try {
      await WeaveService.createPoll(
        widget.activityId,
        kind: _kind,
        question:
        _question.text.trim().isEmpty ? _defaultQuestion : _question.text,
        options: options,
        multi: _multi,
        closesAt: _closeHours == null
            ? null
            : DateTime.now().add(Duration(hours: _closeHours!)),
      );
      nav.pop();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _question.dispose();
    for (final c in _places) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Tạo bình chọn', 'New poll'),
                style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            SegmentedButton<PollKind>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: PollKind.place,
                    icon: const Icon(Icons.place),
                    label: Text(tr('Địa điểm', 'Place'))),
                ButtonSegment(
                    value: PollKind.date,
                    icon: const Icon(Icons.event),
                    label: Text(tr('Ngày', 'Date'))),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _question,
              decoration: InputDecoration(
                labelText: tr('Câu hỏi', 'Question'),
                hintText: _defaultQuestion,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_kind == PollKind.place) ...[
              for (var i = 0; i < _places.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _places[i],
                    decoration: InputDecoration(
                      labelText: '${tr('Địa điểm', 'Place')} ${i + 1}',
                      border: const OutlineInputBorder(),
                      suffixIcon: _places.length > 2
                          ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _places.removeAt(i).dispose();
                        }),
                      )
                          : null,
                    ),
                  ),
                ),
              if (_places.length < 6)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _places.add(TextEditingController())),
                    icon: const Icon(Icons.add),
                    label: Text(tr('Thêm địa điểm', 'Add place')),
                  ),
                ),
            ] else ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final d in (List<DateTime>.of(_dates)..sort()))
                    InputChip(
                      label: Text(weaveDate(d)),
                      onDeleted: () => setState(() => _dates.remove(d)),
                    ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _dates.length < 6 ? _addDate : null,
                  icon: const Icon(Icons.add),
                  label: Text(tr('Thêm ngày', 'Add date')),
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Cho chọn nhiều đáp án', 'Allow multiple choices')),
              value: _multi,
              onChanged: (v) => setState(() => _multi = v),
            ),
            DropdownButtonFormField<int?>(
              value: _closeHours,
              decoration: InputDecoration(
                labelText: tr('Hạn bình chọn', 'Deadline'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(tr('Không giới hạn', 'No deadline'))),
                DropdownMenuItem(value: 24, child: Text(tr('24 giờ', '24 hours'))),
                DropdownMenuItem(value: 72, child: Text(tr('3 ngày', '3 days'))),
                DropdownMenuItem(value: 168, child: Text(tr('7 ngày', '7 days'))),
              ],
              onChanged: (v) => setState(() => _closeHours = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _busy ? null : _submit,
              child: Text(tr('Tạo bình chọn', 'Create poll')),
            ),
          ],
        ),
      ),
    );
  }
}