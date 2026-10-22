import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/l10n.dart';
import '../services/response_service.dart';
import '../theme/app_theme.dart';

class ResponseBar extends StatefulWidget {
  final Post post;
  const ResponseBar({super.key, required this.post});

  @override
  State<ResponseBar> createState() => _ResponseBarState();
}

class _ResponseBarState extends State<ResponseBar> {
  late final List<ResponseType>? _set = responsesFor(widget.post);
  late final Stream<String?> _mine = ResponseService.watchMine(widget.post);
  Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final set = _set;
    if (set == null) return;
    try {
      final c = await ResponseService.counts(
          widget.post, set.map((e) => e.id).toList());
      if (mounted) setState(() => _counts = c);
    } catch (_) {
      // lỗi đếm thì vẫn hiện nút, chỉ không có số
    }
  }

  Future<void> _tap(String type) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ResponseService.toggle(widget.post, type);
      await _loadCounts();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final set = _set;
    if (set == null) return const SizedBox.shrink();

    return StreamBuilder<String?>(
      stream: _mine,
      builder: (context, snap) {
        final mine = snap.data;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 0,
            children: [
              for (final r in set)
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  selected: mine == r.id,
                  // Cùng kiểu chip với các màn khác: nền trắng + viền mảnh,
                  // đang chọn thì nền Soft Indigo, viền và chữ Brand Indigo
                  selectedColor: AppColors.soft,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                    color: mine == r.id ? AppColors.brand : AppColors.border,
                  ),
                  shape: const StadiumBorder(),
                  label: Text(
                    '${r.emoji} ${tr(r.vi, r.en)}'
                        '${(_counts[r.id] ?? 0) > 0 ? ' · ${_counts[r.id]}' : ''}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                      mine == r.id ? FontWeight.w700 : FontWeight.w500,
                      color:
                      mine == r.id ? AppColors.brand : AppColors.textPrimary,
                    ),
                  ),
                  onSelected: (_) => _tap(r.id),
                ),
            ],
          ),
        );
      },
    );
  }
}