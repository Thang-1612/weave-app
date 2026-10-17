import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/space.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

const _viLetters = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

/// Bỏ dấu tiếng Việt và chuyển về chữ thường để tìm kiếm ("bong da" khớp "Bóng đá").
String _fold(String input) {
  var r = input.toLowerCase();
  _viLetters.forEach((plain, accented) {
    for (final ch in accented.split('')) {
      r = r.replaceAll(ch, plain);
    }
  });
  return r;
}

/// Bảng chọn chủ đề. [suggested] được tô nổi bật kèm nhãn "Gợi ý",
/// [current] là chủ đề đang dùng. Trả về mã chủ đề, hoặc null nếu đóng bảng.
/// [isHidden] (tùy chọn): trả về true để ẩn chủ đề đó khỏi bảng.
Future<String?> showSpacePicker(
    BuildContext context, {
      String? suggested,
      String? current,
      String? title,
      String? subtitle,
      bool Function(String spaceId)? isHidden,
    }) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _SpacePickerSheet(
      suggested: suggested,
      current: current,
      title: title,
      subtitle: subtitle,
      isHidden: isHidden,
    ),
  );
}

class _SpacePickerSheet extends StatefulWidget {
  final String? suggested;
  final String? current;
  final String? title;
  final String? subtitle;
  final bool Function(String spaceId)? isHidden;

  const _SpacePickerSheet({
    this.suggested,
    this.current,
    this.title,
    this.subtitle,
    this.isHidden,
  });

  @override
  State<_SpacePickerSheet> createState() => _SpacePickerSheetState();
}

class _SpacePickerSheetState extends State<_SpacePickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _visible(Space s) => !(widget.isHidden?.call(s.id) ?? false);

  Widget _tile(Space s, {String? groupName}) {
    final isCurrent = widget.current == s.id;
    final isSuggested = widget.suggested == s.id;
    return ListTile(
      leading: Text(s.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(tr(s.name, s.nameEn ?? s.name)),
      subtitle: groupName == null ? null : Text(groupName),
      selected: isCurrent,
      tileColor: isSuggested ? AppColors.soft : null,
      trailing: isCurrent
          ? const Icon(Icons.check_circle, color: AppColors.brand)
          : (isSuggested
          ? Text(
        tr('✨ Gợi ý', '✨ Suggested'),
        style: const TextStyle(
          color: AppColors.brand,
          fontWeight: FontWeight.w700,
        ),
      )
          : null),
      onTap: () => Navigator.of(context).pop(s.id),
    );
  }

  List<Widget> _searchResults() {
    final q = _fold(_query.trim());
    final results = <Widget>[];
    for (final g in spaceGroups) {
      final groupName = tr(g.name, g.nameEn ?? g.name);
      final groupMatch =
          _fold(g.name).contains(q) || _fold(g.nameEn ?? '').contains(q);
      for (final s in g.children) {
        if (!_visible(s)) continue;
        final match = groupMatch ||
            _fold(s.name).contains(q) ||
            _fold(s.nameEn ?? '').contains(q);
        if (match) results.add(_tile(s, groupName: groupName));
      }
    }
    if (results.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              tr('Không tìm thấy chủ đề phù hợp', 'No matching topics'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ];
    }
    return results;
  }

  List<Widget> _groupedList() {
    final focusId = widget.current ?? widget.suggested;
    final activeGroupId = focusId == null ? null : groupOfSpace(focusId)?.id;
    final out = <Widget>[];

    // Chủ đề được gợi ý hiện ngay trên cùng cho dễ chọn
    final sg = widget.suggested == null ? null : findSpace(widget.suggested!);
    if (sg != null && _visible(sg)) {
      out.add(_tile(sg));
      out.add(const Divider(height: 1));
    }

    for (final g in spaceGroups) {
      final children = g.children.where(_visible).toList();
      if (children.isEmpty) continue;
      out.add(
        ExpansionTile(
          key: ValueKey('pick_${g.id}'),
          initiallyExpanded: activeGroupId == g.id,
          leading: Text(g.emoji, style: const TextStyle(fontSize: 24)),
          title: Text(tr(g.name, g.nameEn ?? g.name)),
          children: [for (final s in children) _tile(s)],
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    // Chiều cao cố định, thu nhỏ khi bàn phím hiện lên để không bị tràn.
    final height = math.max(
      240.0,
      math.min(
        media.size.height * 0.85,
        media.size.height - inset - media.padding.top - 24,
      ),
    );
    final searching = _query.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              widget.title ?? tr('Chọn chủ đề', 'Choose a topic'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (widget.subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _controller,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: tr('Tìm chủ đề...', 'Search topics...'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: searching ? _searchResults() : _groupedList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}