import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../services/on_this_day_service.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _fmtDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// Từ chiều rộng này trở lên: bộ lọc theo năm bên trái, danh sách bên phải.
/// Dưới mức này: hàng chip năm ở đầu trang.
const double _kOtdWideBreakpoint = 900;
const double _kOtdFilterWidth = 260;
const double _kOtdContentMaxWidth = 1040;

/// Màn hình "Ngày này năm xưa": các bài của mình đăng vào hôm nay của những
/// năm trước, nhóm theo năm.
class OnThisDayScreen extends StatefulWidget {
  const OnThisDayScreen({super.key});

  @override
  State<OnThisDayScreen> createState() => _OnThisDayScreenState();
}

class _OnThisDayScreenState extends State<OnThisDayScreen> {
  late Future<List<OnThisDayGroup>> _future = _load();

  /// Năm đang lọc theo "số năm trước"; null = hiện tất cả.
  int? _yearsAgo;

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

  String _yearsLabel(int yearsAgo) => tr(
    '$yearsAgo năm trước',
    yearsAgo == 1 ? '1 year ago' : '$yearsAgo years ago',
  );

  /// Trạng thái trống. [width] là bề rộng khung chứa, để căn giữa nội dung
  /// mà ListView vẫn full chiều rộng (lăn chuột ở lề vẫn hoạt động).
  Widget _empty(double width) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: weaveCenteredPadding(width, h: 32, top: 32, bottom: 32),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.history, size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        Text(
          tr(
            'Chưa có kỷ niệm nào vào ngày này',
            'No memories on this day yet',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'Những bài bạn đăng hôm nay sẽ xuất hiện ở đây vào những năm sau.',
            'What you post today will show up here in the years to come.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _error(Object error, double width) {
    final detail = '$error';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: weaveCenteredPadding(width, h: 32, top: 32, bottom: 32),
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
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

  /// Danh sách các nhóm theo năm (đã lọc). Nhóm nào cũng có tiêu đề nhỏ
  /// "N năm trước + ngày" làm metadata, các bài vẽ bằng PostCard.
  List<Widget> _groupWidgets(List<OnThisDayGroup> groups) {
    final shown = _yearsAgo == null
        ? groups
        : groups.where((g) => g.yearsAgo == _yearsAgo).toList();
    return [
      for (final g in shown) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.history, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                _yearsLabel(g.yearsAgo),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmtDate(g.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
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
      const SizedBox(height: WeaveSpacing.xl),
    ];
  }

  // ---------------------------------------------------------------------
  // Bộ lọc theo năm
  // ---------------------------------------------------------------------

  /// Rộng: danh sách năm dạng menu (có số bài), chọn một mục để lọc.
  Widget _yearMenu(List<OnThisDayGroup> groups) {
    final total = groups.fold<int>(0, (s, g) => s + g.posts.length);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              tr('LỌC THEO NĂM', 'FILTER BY YEAR'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ListTile(
            dense: true,
            selected: _yearsAgo == null,
            title: Text(tr('Tất cả', 'All')),
            trailing: Text('$total'),
            onTap: () => setState(() => _yearsAgo = null),
          ),
          for (final g in groups)
            ListTile(
              dense: true,
              selected: _yearsAgo == g.yearsAgo,
              title: Text(_yearsLabel(g.yearsAgo)),
              subtitle: Text(_fmtDate(g.date)),
              trailing: Text('${g.posts.length}'),
              onTap: () => setState(() => _yearsAgo = g.yearsAgo),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Hẹp: hàng chip cuộn ngang ở đầu trang.
  Widget _yearChips(List<OnThisDayGroup> groups) {
    return SizedBox(
      height: 52,
      // Màu và viền đã có trong chipTheme chung; chỉ giữ dạng viên thuốc, không tick.
      child: ChipTheme(
        data: ChipTheme.of(context).copyWith(
          shape: const StadiumBorder(),
          showCheckmark: false,
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tr('Tất cả', 'All')),
                selected: _yearsAgo == null,
                onSelected: (_) => setState(() => _yearsAgo = null),
              ),
            ),
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_yearsLabel(g.yearsAgo)),
                  selected: _yearsAgo == g.yearsAgo,
                  onSelected: (_) => setState(() => _yearsAgo = g.yearsAgo),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(List<OnThisDayGroup> groups) {
    // Năm đang lọc không còn trong dữ liệu mới (sau khi làm mới): bỏ lọc
    final yearStillExists =
        _yearsAgo == null || groups.any((g) => g.yearsAgo == _yearsAgo);
    if (!yearStillExists) _yearsAgo = null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final wide = w >= _kOtdWideBreakpoint;

        if (wide) {
          // Rộng: bộ lọc năm | danh sách cuộn riêng. Danh sách kéo dài tới
          // mép phải cửa sổ để lăn chuột ở lề phải vẫn cuộn được; nội dung
          // vẫn căn trong 1040 px.
          final margin = w > _kOtdContentMaxWidth
              ? (w - _kOtdContentMaxWidth) / 2
              : 0.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: margin + WeaveSpacing.xl),
              SizedBox(
                width: _kOtdFilterWidth,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: WeaveSpacing.xl),
                  child: _yearMenu(groups),
                ),
              ),
              const SizedBox(width: WeaveSpacing.sm),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      0,
                      WeaveSpacing.xl,
                      margin + WeaveSpacing.xl,
                      0,
                    ),
                    children: _groupWidgets(groups),
                  ),
                ),
              ),
            ],
          );
        }

        // Hẹp: chip năm ở đầu trang (căn giữa tối đa 600), danh sách bên dưới
        // full chiều rộng, nội dung căn giữa bằng padding.
        return Column(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _yearChips(groups),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: weaveCenteredPadding(w, h: 0, top: 0, bottom: 0),
                  children: _groupWidgets(groups),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Ngày này năm xưa', 'On this day')),
      ),
      body: FutureBuilder<List<OnThisDayGroup>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          // Trạng thái lỗi / trống: vẫn kéo để làm mới được.
          if (snap.hasError) {
            return LayoutBuilder(
              builder: (context, c) => RefreshIndicator(
                onRefresh: _refresh,
                child: _error(snap.error!, c.maxWidth),
              ),
            );
          }
          final groups = snap.data ?? const <OnThisDayGroup>[];
          if (groups.isEmpty) {
            return LayoutBuilder(
              builder: (context, c) => RefreshIndicator(
                onRefresh: _refresh,
                child: _empty(c.maxWidth),
              ),
            );
          }
          return _body(groups);
        },
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