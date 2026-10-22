import 'package:flutter/material.dart';
import '../models/space.dart';
import '../services/feed_recipe_service.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import '../widgets/space_picker.dart';

/// Quản lý công thức bảng tin: người dùng tự đặt luật cho bảng tin của mình.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  FeedRecipeState? _s;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await FeedRecipeService.load();
      if (mounted) setState(() => _s = s);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _persist(FeedRecipeState n) async {
    setState(() => _s = n);
    await FeedRecipeService.save(n);
  }

  Future<void> _edit([FeedRecipe? r]) async {
    final res = await showDialog<FeedRecipe>(
      context: context,
      builder: (_) => _RecipeDialog(initial: r),
    );
    final cur = _s;
    if (res == null || cur == null) return;
    final items = [...cur.items];
    final i = items.indexWhere((e) => e.id == res.id);
    if (i >= 0) {
      items[i] = res;
    } else {
      items.add(res);
    }
    await _persist(FeedRecipeState(items, i >= 0 ? cur.activeId : res.id));
  }

  Future<void> _delete(FeedRecipe r) async {
    final cur = _s;
    if (cur == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Xóa công thức "${r.name}"?', 'Delete recipe "${r.name}"?')),
        content: Text(tr('Công thức sẽ bị xóa và không thể khôi phục.',
            'The recipe will be deleted and cannot be restored.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Xóa', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _persist(FeedRecipeState(
      cur.items.where((e) => e.id != r.id).toList(),
      cur.activeId == r.id ? null : cur.activeId,
    ));
  }

  String _describe(FeedRecipe r) {
    final parts = <String>[];
    if (r.spaceIds.isNotEmpty) {
      parts.add(r.spaceIds
          .map((id) => findSpace(id)?.emoji ?? '')
          .where((e) => e.isNotEmpty)
          .join(' '));
    } else {
      parts.add(tr('Mọi chủ đề', 'All topics'));
    }
    if (r.minBlocks > 0) {
      parts.add(tr('từ ${r.minBlocks} khối', '${r.minBlocks}+ blocks'));
    }
    if (r.withUpdates) parts.add(tr('bài sống', 'living posts'));
    if (r.withImages) parts.add(tr('có ảnh', 'with images'));
    if (r.maxAgeDays > 0) {
      parts.add(
          tr('trong ${r.maxAgeDays} ngày', 'within ${r.maxAgeDays} days'));
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Công thức bảng tin', 'Feed recipes')),
      ),
      // Màu và bo góc của FAB lấy từ floatingActionButtonTheme.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: s == null ? null : () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(tr('Công thức mới', 'New recipe')),
      ),
      body: _error != null
          ? Center(child: SelectableText(_error!))
          : s == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  tr(
                    'Tự đặt luật cho bảng tin "Tất cả": chọn chủ đề, độ dài bài, chỉ bài sống, chỉ bài có ảnh... Bấm một công thức để dùng, bấm lại để tắt.',
                    'Write your own rules for the "All" feed: topics, post length, living posts only, images only... Tap a recipe to use it, tap again to turn it off.',
                  ),
                  style: const TextStyle(
                      color: AppColors.textSecondary, height: 1.4),
                ),
              ),
              for (final r in s.items)
                Card(
                  // Công thức đang dùng: nền soft và viền Brand.
                  color: s.activeId == r.id ? AppColors.soft : null,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(WeaveRadius.card),
                    side: BorderSide(
                      color: s.activeId == r.id
                          ? AppColors.brand
                          : AppColors.border,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      s.activeId == r.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: AppColors.brand,
                    ),
                    title: Text(r.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    subtitle: Text(_describe(r)),
                    onTap: () => _persist(FeedRecipeState(
                      s.items,
                      s.activeId == r.id ? null : r.id,
                    )),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: tr('Sửa', 'Edit'),
                          icon: const Icon(Icons.edit_outlined,
                              size: 20),
                          onPressed: () => _edit(r),
                        ),
                        IconButton(
                          tooltip: tr('Xóa', 'Delete'),
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: AppColors.danger),
                          onPressed: () => _delete(r),
                        ),
                      ],
                    ),
                  ),
                ),
              if (s.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr('Chưa có công thức nào.', 'No recipes yet.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeDialog extends StatefulWidget {
  final FeedRecipe? initial;
  const _RecipeDialog({this.initial});

  @override
  State<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends State<_RecipeDialog> {
  late final TextEditingController _name =
  TextEditingController(text: widget.initial?.name ?? '');
  late List<String> _spaces = [...?widget.initial?.spaceIds];
  late int _minBlocks = widget.initial?.minBlocks ?? 0;
  late bool _withUpdates = widget.initial?.withUpdates ?? false;
  late bool _withImages = widget.initial?.withImages ?? false;
  late int _maxAge = widget.initial?.maxAgeDays ?? 0;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addSpace() async {
    final picked = await showSpacePicker(
      context,
      current: null,
      title: tr('Thêm chủ đề vào công thức', 'Add a topic to the recipe'),
    );
    if (picked != null && !_spaces.contains(picked) && _spaces.length < 30) {
      setState(() => _spaces = [..._spaces, picked]);
    }
  }

  Widget _row(String label, Widget control) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          control,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _name.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.initial == null
          ? tr('Công thức mới', 'New recipe')
          : tr('Sửa công thức', 'Edit recipe')),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: tr('Tên công thức', 'Recipe name'),
                ),
              ),
              Text(tr('Chủ đề (để trống = mọi chủ đề)',
                  'Topics (empty = all topics)')),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  for (final id in _spaces)
                    InputChip(
                      label: Text(
                        '${findSpace(id)?.emoji ?? ''} ${tr(findSpace(id)?.name ?? id, findSpace(id)?.nameEn ?? findSpace(id)?.name ?? id)}',
                      ),
                      onDeleted: () => setState(() =>
                      _spaces = _spaces.where((e) => e != id).toList()),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(tr('Thêm chủ đề', 'Add topic')),
                    onPressed: _addSpace,
                  ),
                ],
              ),
              _row(
                tr('Số khối tối thiểu', 'Minimum blocks'),
                DropdownButton<int>(
                  value: _minBlocks,
                  items: [
                    for (final v in const [0, 2, 3, 5])
                      DropdownMenuItem(
                        value: v,
                        child: Text(v == 0 ? tr('Bất kỳ', 'Any') : '$v'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _minBlocks = v ?? 0),
                ),
              ),
              _row(
                tr('Mới trong vòng', 'Fresh within'),
                DropdownButton<int>(
                  value: _maxAge,
                  items: [
                    for (final v in const [0, 1, 7, 30])
                      DropdownMenuItem(
                        value: v,
                        child: Text(v == 0
                            ? tr('Bất kỳ lúc nào', 'Any time')
                            : tr('$v ngày', '$v days')),
                      ),
                  ],
                  onChanged: (v) => setState(() => _maxAge = v ?? 0),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Chỉ bài sống (có cập nhật)',
                    'Living posts only (with updates)')),
                value: _withUpdates,
                onChanged: (v) => setState(() => _withUpdates = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Chỉ bài có ảnh', 'Posts with images only')),
                value: _withImages,
                onChanged: (v) => setState(() => _withImages = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Hủy', 'Cancel')),
        ),
        FilledButton(
          onPressed: canSave
              ? () => Navigator.of(context).pop(FeedRecipe(
            id: widget.initial?.id ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            name: _name.text.trim(),
            spaceIds: _spaces,
            minBlocks: _minBlocks,
            withUpdates: _withUpdates,
            withImages: _withImages,
            maxAgeDays: _maxAge,
          ))
              : null,
          child: Text(tr('Lưu', 'Save')),
        ),
      ],
    );
  }
}