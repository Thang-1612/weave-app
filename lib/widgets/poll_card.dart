import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/l10n.dart';
import '../services/poll_service.dart';
import '../theme/app_theme.dart';

/// Bình chọn trong bài. Người xem phải bình chọn mới thấy kết quả (tránh bị
/// ảnh hưởng); tác giả có thể xem kết quả mà không cần bình chọn.
class PollCard extends StatefulWidget {
  final Post post;

  const PollCard({super.key, required this.post});

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  late final Stream<List<String>?> _mine =
  PollService.watchMyVote(widget.post);

  final Set<String> _selected = {};
  PollResults? _results;
  bool _loading = false;
  bool _failed = false;
  bool _voting = false;
  bool _changing = false; // đang đổi bình chọn
  bool _peek = false; // tác giả xem kết quả khi chưa bình chọn

  static const _grey = TextStyle(fontSize: 12, color: Colors.grey);

  Future<void> _loadResults() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final r = await PollService.results(widget.post);
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _voting = true);
    try {
      await PollService.vote(widget.post, _selected);
      if (!mounted) return;
      setState(() {
        _changing = false;
        _peek = false;
      });
      await _loadResults();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${tr('Không bình chọn được', 'Could not vote')}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _retract() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PollService.removeVote(widget.post);
      if (!mounted) return;
      setState(() {
        _results = null;
        _changing = false;
        _selected.clear();
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${tr('Không rút được phiếu', 'Could not remove your vote')}: $e',
          ),
        ),
      );
    }
  }

  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.poll_outlined, size: 18, color: AppColors.brand),
        const SizedBox(width: 6),
        Text(
          tr('Bình chọn', 'Poll'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (widget.post.pollMultiple)
          Text(
            ' · ${tr('chọn nhiều', 'multiple answers')}',
            style: _grey,
          ),
      ],
    );
  }

  Widget _choiceRow(PollOption o) {
    final picked = _selected.contains(o.id);
    final multiple = widget.post.pollMultiple;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _voting
          ? null
          : () => setState(() {
        if (multiple) {
          if (!_selected.remove(o.id)) _selected.add(o.id);
        } else {
          _selected
            ..clear()
            ..add(o.id);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              multiple
                  ? (picked ? Icons.check_box : Icons.check_box_outline_blank)
                  : (picked
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              color: picked ? AppColors.brand : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(o.text)),
          ],
        ),
      ),
    );
  }

  List<Widget> _voteView(List<String>? mine, bool isAuthor) {
    return [
      for (final o in widget.post.pollOptions) _choiceRow(o),
      const SizedBox(height: 4),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: _selected.isEmpty || _voting ? null : _submit,
            child: _voting
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Text(tr('Bình chọn', 'Vote')),
          ),
          if (_changing)
            TextButton(
              onPressed: () => setState(() {
                _changing = false;
                _selected.clear();
              }),
              child: Text(tr('Hủy', 'Cancel')),
            ),
          if (isAuthor && mine == null)
            TextButton(
              onPressed: () => setState(() => _peek = true),
              child: Text(tr('Xem kết quả', 'See results')),
            ),
        ],
      ),
      if (!isAuthor)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            tr('Bình chọn để xem kết quả', 'Vote to see the results'),
            style: _grey,
          ),
        ),
    ];
  }

  Widget _resultRow(PollOption o, PollResults r, List<String> mine) {
    final count = r.counts[o.id] ?? 0;
    final frac = r.voters == 0 ? 0.0 : (count / r.voters).clamp(0.0, 1.0);
    final isMine = mine.contains(o.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            const SizedBox(
              height: 40,
              width: double.infinity,
              child: ColoredBox(color: Color(0xFFE5E7EB)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: frac,
                child: SizedBox(
                  height: 40,
                  child: ColoredBox(
                    color: isMine
                        ? const Color(0xFFC7D2FE)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (isMine) ...[
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        o.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                          isMine ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$count · ${(frac * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultsView(List<String> mine, bool hasVote) {
    final r = _results;
    return [
      if (r == null && _failed)
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Không tải được kết quả', 'Could not load the results'),
                style: _grey,
              ),
            ),
            TextButton(
              onPressed: _loadResults,
              child: Text(tr('Thử lại', 'Retry')),
            ),
          ],
        )
      else if (r == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(minHeight: 2),
        )
      else
        for (final o in widget.post.pollOptions) _resultRow(o, r, mine),
      const SizedBox(height: 4),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          if (r != null)
            Text(
              tr('${r.voters} người đã bình chọn', '${r.voters} votes'),
              style: _grey,
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: tr('Cập nhật kết quả', 'Refresh results'),
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _loading ? null : _loadResults,
          ),
          if (hasVote)
            TextButton(
              onPressed: () => setState(() {
                _changing = true;
                _selected
                  ..clear()
                  ..addAll(mine);
              }),
              child: Text(tr('Đổi bình chọn', 'Change vote')),
            ),
          if (hasVote)
            TextButton(
              onPressed: _retract,
              child: Text(tr('Rút phiếu', 'Remove vote')),
            ),
          if (!hasVote && _peek)
            TextButton(
              onPressed: () => setState(() => _peek = false),
              child: Text(tr('Quay lại', 'Back')),
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isAuthor = FirebaseAuth.instance.currentUser?.uid == post.authorId;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: StreamBuilder<List<String>?>(
        stream: _mine,
        builder: (context, snap) {
          if (snap.hasError) {
            return Text(
              tr('Không tải được bình chọn', 'Could not load the poll'),
              style: _grey,
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          final mine = snap.data;
          final showResults = (mine != null && !_changing) || _peek;
          if (showResults && _results == null && !_loading && !_failed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadResults();
            });
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 8),
              if (showResults)
                ..._resultsView(mine ?? const <String>[], mine != null)
              else
                ..._voteView(mine, isAuthor),
            ],
          );
        },
      ),
    );
  }
}