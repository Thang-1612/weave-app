import 'package:flutter/material.dart';
import '../models/post.dart';
import '../screens/forks_screen.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';

/// Dòng "Rẽ nhánh từ bài của X" trên bài đã rẽ nhánh. Bấm để mở bài gốc.
class ForkOrigin extends StatelessWidget {
  final Post post;
  const ForkOrigin({super.key, required this.post});

  Future<void> _openOriginal(BuildContext context) async {
    final id = post.forkedFrom;
    if (id == null) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final original = await PostService.getPost(id);
    if (original == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr(
            'Bài gốc đã bị xóa hoặc bạn không có quyền xem',
            'The original post was deleted or you cannot view it',
          )),
        ),
      );
      return;
    }
    nav.push(
      MaterialPageRoute(builder: (_) => ForksScreen(original: original)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (post.forkedFrom == null) return const SizedBox.shrink();
    final who = post.forkedFromAuthor ?? tr('người dùng', 'a user');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openOriginal(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_split, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  tr('Rẽ nhánh từ bài của $who', "Forked from $who's post"),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Số nhánh của bài gốc, bấm để xem danh sách. Ẩn khi chưa có nhánh.
class ForkCount extends StatefulWidget {
  final Post post;
  const ForkCount({super.key, required this.post});

  @override
  State<ForkCount> createState() => _ForkCountState();
}

class _ForkCountState extends State<ForkCount> {
  int _n = 0;

  @override
  void initState() {
    super.initState();
    PostService.forkTick.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    PostService.forkTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.post.collection != 'posts') return;
    try {
      final n = await PostService.forkCount(widget.post.id);
      if (mounted) setState(() => _n = n);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_n == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ForksScreen(original: widget.post),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_split, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                '$_n ${tr('nhánh', 'forks')}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}