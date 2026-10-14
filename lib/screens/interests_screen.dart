import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/l10n.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

const _maxTags = 10;

const _presets = [
  'flutter',
  'lập trình',
  'âm nhạc',
  'phim ảnh',
  'bóng đá',
  'du lịch',
  'đọc sách',
  'nhiếp ảnh',
  'khởi nghiệp',
  'học ngoại ngữ',
  'nấu ăn',
  'game',
  'thể thao',
  'thiết kế',
];

/// Chỉnh sở thích và mục tiêu/dự án đang làm. Trả về true nếu đã lưu.
class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final _interests = <String>[];
  final _goals = <String>[];
  final _interestCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _interestCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final p = await UserService.watchProfile(uid).first;
      if (p != null) {
        _interests.addAll(p.interests);
        _goals.addAll(p.goalTags);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _add(List<String> list, TextEditingController ctrl, [String? value]) {
    final t = normalizeTag(value ?? ctrl.text);
    if (t.isEmpty || list.contains(t)) {
      ctrl.clear();
      return;
    }
    if (list.length >= _maxTags) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Tối đa $_maxTags thẻ mỗi mục.',
            'Up to $_maxTags tags per section.')),
      ));
      return;
    }
    setState(() => list.add(t));
    ctrl.clear();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserService.saveTags(interests: _interests, goalTags: _goals);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Không lưu được. Thử lại nhé.',
            'Could not save. Please try again.')),
      ));
    }
  }

  Widget _section({
    required String title,
    required String hint,
    required List<String> list,
    required TextEditingController ctrl,
    bool showPresets = false,
  }) {
    final presets = _presets.where((p) => !list.contains(p)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _add(list, ctrl),
            ),
          ),
          onSubmitted: (_) => _add(list, ctrl),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in list)
              InputChip(
                label: Text(t),
                onDeleted: () => setState(() => list.remove(t)),
              ),
          ],
        ),
        if (showPresets && presets.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(tr('Gợi ý', 'Suggestions'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final p in presets)
                ActionChip(
                  label: Text(p),
                  onPressed: () => _add(list, ctrl, p),
                ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        title: Text(tr('Sở thích & mục tiêu', 'Interests & goals')),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: Text(tr('Lưu', 'Save')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            title: tr('Sở thích', 'Interests'),
            hint: tr('Ví dụ: âm nhạc', 'e.g. music'),
            list: _interests,
            ctrl: _interestCtrl,
            showPresets: true,
          ),
          const SizedBox(height: 24),
          _section(
            title: tr('Mục tiêu / dự án đang làm', 'Goals / current projects'),
            hint: tr('Ví dụ: học tiếng Nhật', 'e.g. learn Japanese'),
            list: _goals,
            ctrl: _goalCtrl,
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              'Các thẻ này giúp tìm bạn cùng sở thích và hiện điểm chung trên bản đồ quan hệ.',
              'These tags help find people with shared interests and show common ground on the map.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}