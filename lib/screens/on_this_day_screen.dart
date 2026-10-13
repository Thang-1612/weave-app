import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../services/on_this_day_service.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _fmtDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// Màn hình "Ngày này năm xưa": các bài của mình đăng vào hôm nay của những
/// năm trước, nhóm theo năm.
class OnThisDayScreen extends StatefulWidget {
  const OnThisDayScreen({super.key});

  @override
  State<OnThisDayScreen> createState() => _OnThisDayScreenState();
}

class _OnThisDayScreenState extends State<OnThisDayScreen> {
  late Future<List<OnThisDayGroup>> _future = _load();

  Future<List<OnThisDayGroup>> _load() async {
    try {
      return await OnThisDayService.load();
    } catch (e) {
      // Thiếu chỉ mục thì lỗi này có kèm đường link tạo chỉ mục
      debugPrint('on this day error: $e');
      rethrow;
    }
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.history, size: 56, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          tr(
            'Chưa có kỷ niệm nào vào ngày này',
            'No memories on this day yet',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'Những bài bạn đăng hôm nay sẽ xuất hiện ở đây vào những năm sau.',
            'What you post today will show up here in the years to come.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _error(Object error) {
    final detail = '$error';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Text(
          tr('Không tải được kỷ niệm', 'Could not load your memories'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          detail.length > 200 ? '${detail.substring(0, 200)}...' : detail,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _refresh,
            child: Text(tr('Thử lại', 'Retry')),
          ),
        ),
      ],
    );
  }

  Widget _list(List<OnThisDayGroup> groups) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.history, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  tr(
                    '${g.yearsAgo} năm trước',
                    g.yearsAgo == 1 ? '1 year ago' : '${g.yearsAgo} years ago',
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _fmtDate(g.date),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          for (final p in g.posts)
            PostCard(
              key: ValueKey('otd_${p.id}'),
              post: p,
              openProfileOnTap: false,
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        title: Text(tr('Ngày này năm xưa', 'On this day')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<OnThisDayGroup>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) return _error(snap.error!);
                final groups = snap.data ?? const <OnThisDayGroup>[];
                if (groups.isEmpty) return _empty();
                return _list(groups);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Mục bấm để mở "Ngày này năm xưa". Đặt vào menu, ngăn kéo hoặc trang cá
/// nhân: `const OnThisDayTile()`.
class OnThisDayTile extends StatelessWidget {
  const OnThisDayTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(tr('Ngày này năm xưa', 'On this day')),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OnThisDayScreen()),
        );
      },
    );
  }
}