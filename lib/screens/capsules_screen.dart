import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/capsule_service.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';
import '../widgets/weave_error_view.dart';
import '../widgets/weave_state_views.dart';

/// Từ chiều rộng này trở lên: bộ lọc bên trái, danh sách bên phải.
/// Dưới mức này: bộ lọc nằm ở đầu trang.
const double _kCapsulesWideBreakpoint = 900;
const double _kCapsulesFilterWidth = 260;
const double _kCapsulesContentMaxWidth = 1040;

class CapsulesScreen extends StatefulWidget {
  const CapsulesScreen({super.key});

  @override
  State<CapsulesScreen> createState() => _CapsulesScreenState();
}

class _CapsulesScreenState extends State<CapsulesScreen> {
  late Future<(List<QueryDocumentSnapshot<Map<String, dynamic>>>, List<Post>)>
  _future = _load();

  int _scope = 0; // 0 tất cả, 1 hộp của tôi, 2 gửi cho tôi
  int _status = 0; // 0 tất cả, 1 đang niêm phong, 2 đã mở

  Future<(List<QueryDocumentSnapshot<Map<String, dynamic>>>, List<Post>)>
  _load() async {
    final r = await Future.wait([
      CapsuleService.mine(),
      CapsuleService.openedForMe(),
    ]);
    return (
    r[0] as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
    r[1] as List<Post>,
    );
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Lỗi được FutureBuilder hiển thị; không để RefreshIndicator ném tiếp.
    }
  }

  Future<void> _deleteCapsule(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Xóa hộp thời gian?', 'Delete this time capsule?')),
        content: Text(
          tr(
            'Hộp thời gian sẽ bị xóa vĩnh viễn, không khôi phục được.',
            'The time capsule will be permanently deleted and cannot be restored.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Xóa vĩnh viễn', 'Delete forever')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await CapsuleService.delete(id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
      return;
    }
    if (mounted) _reload();
  }

  Widget _title(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(
      s,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
    ),
  );

  Widget _hint(String s) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(s, style: const TextStyle(color: AppColors.textSecondary)),
  );

  /// Hộp còn niêm phong: chỉ hiện ngày mở và số ngày còn lại, TUYỆT ĐỐI không
  /// hiện nội dung. Chỉ hộp đã tới hạn mới được vẽ bằng PostCard.
  Widget _lockedTile(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final openAt = (data['openAt'] as Timestamp).toDate();
    final days = openAt.difference(DateTime.now()).inDays;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: WeaveSpacing.lg,
        vertical: WeaveSpacing.sm,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.soft,
          child: Icon(Icons.lock_clock, color: AppColors.brand),
        ),
        title: Text(
          '${tr('Mở vào', 'Opens on')} ${CapsuleService.fmtDate(openAt)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          days > 0
              ? tr('Còn $days ngày', '$days days left')
              : tr('Sắp mở', 'Opening soon'),
        ),
        trailing: IconButton(
          tooltip: tr('Xóa hộp', 'Delete capsule'),
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteCapsule(d.id),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Bộ lọc
  // ---------------------------------------------------------------------

  Widget _chipGroup({
    required String label,
    required List<(String, int)> options,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: WeaveSpacing.sm),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Wrap(
          spacing: WeaveSpacing.sm,
          runSpacing: WeaveSpacing.sm,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(o.$1),
                selected: value == o.$2,
                onSelected: (_) => onChanged(o.$2),
              ),
          ],
        ),
      ],
    );
  }

  Widget _filters(
      int mineCount,
      int lockedCount,
      int openedCount,
      int recvCount,
      ) {
    // Màu và viền đã có trong chipTheme chung; chỉ giữ dạng viên thuốc, không tick.
    return ChipTheme(
      data: ChipTheme.of(
        context,
      ).copyWith(shape: const StadiumBorder(), showCheckmark: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chipGroup(
            label: tr('Hiển thị', 'Show'),
            options: [
              (tr('Tất cả', 'All'), 0),
              (tr('Hộp của tôi ($mineCount)', 'My capsules ($mineCount)'), 1),
              (tr('Gửi cho tôi ($recvCount)', 'Sent to me ($recvCount)'), 2),
            ],
            value: _scope,
            onChanged: (v) => setState(() => _scope = v),
          ),
          const SizedBox(height: WeaveSpacing.lg),
          _chipGroup(
            label: tr('Trạng thái', 'Status'),
            options: [
              (tr('Tất cả', 'All'), 0),
              (
              tr('Đang niêm phong ($lockedCount)', 'Sealed ($lockedCount)'),
              1,
              ),
              (tr('Đã mở ($openedCount)', 'Opened ($openedCount)'), 2),
            ],
            value: _status,
            onChanged: (v) => setState(() => _status = v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Hộp thời gian', 'Time capsules'))),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('CapsulesScreen load error: ${snap.error}');
            return WeaveErrorView(
              message: tr(
                'Không tải được hộp thời gian.',
                'Could not load time capsules.',
              ),
              onRetry: () => _reload(),
            );
          }
          if (!snap.hasData) {
            return const WeaveLoadingView();
          }
          final (mine, received) = snap.data!;
          final now = DateTime.now();

          bool isLocked(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              (d.data()['openAt'] as Timestamp).toDate().isAfter(now);

          final lockedCount = mine.where(isLocked).length;
          final openedCount = mine.length - lockedCount;

          // Áp dụng bộ lọc. Hộp còn niêm phong luôn chỉ vẽ bằng _lockedTile.
          final showMine = _scope != 2;
          final showReceived =
              _scope != 1 && _status != 1; // "gửi cho tôi" đều đã mở
          final mineShown = mine.where((d) {
            if (_status == 0) return true;
            return _status == 1 ? isLocked(d) : !isLocked(d);
          }).toList();

          final content = <Widget>[
            if (showMine) ...[
              _title(tr('Hộp của tôi', 'My capsules')),
              if (mine.isEmpty)
                _hint(
                  tr(
                    'Chưa có hộp nào. Khi soạn bài, chọn "Hẹn giờ mở".',
                    'None yet. When writing a post, choose "Time capsule".',
                  ),
                )
              else if (mineShown.isEmpty)
                _hint(
                  tr(
                    'Không có hộp nào khớp bộ lọc.',
                    'No capsules match the filter.',
                  ),
                ),
              for (final d in mineShown)
                if (isLocked(d))
                  _lockedTile(d)
                else
                  PostCard(
                    key: ValueKey('capsules_${d.id}'),
                    post: Post.fromDoc(d),
                  ),
            ],
            if (showReceived) ...[
              _title(tr('Gửi cho tôi', 'Sent to me')),
              if (received.isEmpty)
                _hint(
                  tr('Chưa có hộp nào được mở.', 'No capsules opened yet.'),
                ),
              for (final p in received)
                PostCard(key: ValueKey('capsules_${p.id}'), post: p),
            ],
            const SizedBox(height: WeaveSpacing.xl),
          ];

          final filters = _filters(
            mine.length,
            lockedCount,
            openedCount,
            received.length,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final wide = w >= _kCapsulesWideBreakpoint;

              if (wide) {
                // Rộng: bộ lọc (card cố định) | danh sách cuộn riêng.
                // Danh sách kéo dài tới mép phải cửa sổ để lăn chuột ở lề
                // phải vẫn cuộn được; nội dung vẫn căn trong 1040 px.
                final margin = w > _kCapsulesContentMaxWidth
                    ? (w - _kCapsulesContentMaxWidth) / 2
                    : 0.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: margin + WeaveSpacing.xl),
                    SizedBox(
                      width: _kCapsulesFilterWidth,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(top: WeaveSpacing.xl),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(WeaveSpacing.lg),
                            child: filters,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: WeaveSpacing.sm),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            0,
                            WeaveSpacing.xl,
                            margin + WeaveSpacing.xl,
                            0,
                          ),
                          children: content,
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Hẹp: bộ lọc ở đầu trang, rồi tới danh sách. ListView full
              // chiều rộng, nội dung căn giữa tối đa 600 bằng padding.
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: weaveCenteredPadding(w, h: 0, top: 0, bottom: 0),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: filters,
                    ),
                    ...content,
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}