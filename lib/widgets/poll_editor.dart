import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';

/// Bản nháp bình chọn đang soạn: danh sách ô nhập, tùy chọn chọn nhiều và
/// thời hạn khóa.
class PollDraft extends ChangeNotifier {
  final List<TextEditingController> controllers = [];
  bool multiple = false;

  /// Khóa bình chọn sau khoảng thời gian này kể từ lúc đăng (null = không giới hạn).
  Duration? closeAfter;

  PollDraft() {
    controllers.add(_make());
    controllers.add(_make());
  }

  TextEditingController _make() {
    final c = TextEditingController();
    c.addListener(notifyListeners);
    return c;
  }

  bool get canAdd => controllers.length < PostService.maxPollOptions;

  void add() {
    if (!canAdd) return;
    controllers.add(_make());
    notifyListeners();
  }

  void removeAt(int i) {
    if (controllers.length <= 2) return;
    controllers.removeAt(i).dispose();
    notifyListeners();
  }

  void setMultiple(bool v) {
    multiple = v;
    notifyListeners();
  }

  void setCloseAfter(Duration? d) {
    closeAfter = d;
    notifyListeners();
  }

  /// Các lựa chọn đã điền: bỏ ô trống và bỏ trùng (không phân biệt hoa thường).
  List<String> get options {
    final seen = <String>{};
    final out = <String>[];
    for (final c in controllers) {
      final t = c.text.trim();
      if (t.isNotEmpty && seen.add(t.toLowerCase())) out.add(t);
    }
    return out;
  }

  bool get valid => options.length >= 2;

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }
}

/// Mở hộp soạn bình chọn dạng bảng trượt từ dưới lên (tránh làm tràn màn
/// hình soạn bài khi bàn phím đang mở).
Future<void> showPollEditorSheet(BuildContext context, PollDraft draft) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: PollEditor(
          draft: draft,
          onDone: () => Navigator.of(ctx).pop(),
        ),
      ),
    ),
  );
}

class PollEditor extends StatelessWidget {
  final PollDraft draft;
  final VoidCallback onDone;

  const PollEditor({super.key, required this.draft, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final closeOptions = <(String, Duration?)>[
      (tr('Không giới hạn', 'No limit'), null),
      (tr('1 giờ', '1 hour'), const Duration(hours: 1)),
      (tr('24 giờ', '24 hours'), const Duration(hours: 24)),
      (tr('3 ngày', '3 days'), const Duration(days: 3)),
      (tr('7 ngày', '7 days'), const Duration(days: 7)),
    ];

    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final n = draft.controllers.length;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Tạo bình chọn', 'Create a poll'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    'Tối đa ${PostService.maxPollOptions} lựa chọn. Người xem phải bình chọn mới thấy kết quả.',
                    'Up to ${PostService.maxPollOptions} options. Viewers must vote to see the results.',
                  ),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < n; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      key: ObjectKey(draft.controllers[i]),
                      controller: draft.controllers[i],
                      maxLength: 80,
                      decoration: InputDecoration(
                        hintText: tr('Lựa chọn ${i + 1}', 'Option ${i + 1}'),
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: n > 2
                            ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => draft.removeAt(i),
                        )
                            : null,
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: draft.canAdd ? draft.add : null,
                  icon: const Icon(Icons.add),
                  label: Text(
                    '${tr('Thêm lựa chọn', 'Add option')} ($n/${PostService.maxPollOptions})',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: draft.multiple,
                  onChanged: draft.setMultiple,
                  title: Text(
                    tr('Cho chọn nhiều đáp án', 'Allow multiple answers'),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('Khóa bình chọn sau', 'Close the poll after'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final o in closeOptions)
                      ChoiceChip(
                        label: Text(o.$1),
                        selected: draft.closeAfter == o.$2,
                        onSelected: (_) => draft.setCloseAfter(o.$2),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    'Sau khi khóa, không ai bỏ phiếu, đổi hay rút phiếu được nữa và mọi người đều xem được kết quả.',
                    'Once closed, nobody can vote, change or remove a vote, and everyone can see the results.',
                  ),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onDone,
                    child: Text(tr('Xong', 'Done')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}