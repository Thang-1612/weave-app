import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// Hộp thoại nhập một đoạn chữ ngắn. Trả về chữ đã cắt khoảng trắng,
/// hoặc null nếu người dùng hủy.
Future<String?> showTextPrompt(
    BuildContext context, {
      required String title,
      required String hint,
      required String action,
      int maxLen = 300,
      bool allowEmpty = false,
    }) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      hint: hint,
      action: action,
      maxLen: maxLen,
      allowEmpty: allowEmpty,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String action;
  final int maxLen;
  final bool allowEmpty;

  const _TextPromptDialog({
    required this.title,
    required this.hint,
    required this.action,
    required this.maxLen,
    required this.allowEmpty,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _c = TextEditingController();

  bool get _ok => widget.allowEmpty || _c.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _c.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _c,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          maxLength: widget.maxLen,
          decoration: InputDecoration(
            hintText: widget.hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Hủy', 'Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
          onPressed: _ok ? () => Navigator.of(context).pop(_c.text.trim()) : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}