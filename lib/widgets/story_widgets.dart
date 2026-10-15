import 'package:flutter/material.dart';
import '../models/story_models.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

String storyKindLabel(StoryKind k) {
  switch (k) {
    case StoryKind.trip:
      return tr('Chuyến đi', 'Trip');
    case StoryKind.learning:
      return tr('Hành trình học', 'Learning journey');
    case StoryKind.week:
      return tr('Recap tuần', 'Weekly recap');
  }
}

IconData storyKindIcon(StoryKind k) {
  switch (k) {
    case StoryKind.trip:
      return Icons.flight_takeoff;
    case StoryKind.learning:
      return Icons.school_outlined;
    case StoryKind.week:
      return Icons.calendar_view_week_outlined;
  }
}

String storyMoodLabel(String m) {
  switch (m) {
    case 'joyful':
      return tr('Vui vẻ', 'Joyful');
    case 'adventurous':
      return tr('Phiêu lưu', 'Adventurous');
    case 'reflective':
      return tr('Suy tư', 'Reflective');
    case 'nostalgic':
      return tr('Hoài niệm', 'Nostalgic');
    case 'energetic':
      return tr('Năng động', 'Energetic');
    default:
      return tr('Bình yên', 'Calm');
  }
}

/// Gợi ý nhạc theo tâm trạng. Chỉ là gợi ý thể loại, chưa phát nhạc.
String storyMusicHint(String m) {
  switch (m) {
    case 'joyful':
      return tr('nhạc pop nhẹ, tươi sáng', 'light, bright pop');
    case 'adventurous':
      return tr('nhạc acoustic, nhịp đi đường', 'upbeat acoustic');
    case 'reflective':
      return tr('piano chậm, ambient', 'slow piano, ambient');
    case 'nostalgic':
      return tr('guitar mộc, lo-fi', 'soft guitar, lo-fi');
    case 'energetic':
      return tr('nhạc điện tử nhịp nhanh', 'fast electronic');
    default:
      return tr('nhạc nhẹ, thư giãn', 'calm, relaxing');
  }
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Hộp nhập văn bản nhiều dòng. Trả về null nếu hủy.
Future<String?> showStoryTextDialog(
    BuildContext context, {
      required String title,
      String initial = '',
      String? hint,
      int maxLength = 800,
    }) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 6,
          minLines: 3,
          maxLength: maxLength,
          decoration: InputDecoration(hintText: hint),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr('Hủy', 'Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: Text(tr('Lưu', 'Save')),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Xem tư liệu gốc của một đoạn (ảnh hoặc ghi chú).
void showStorySourceSheet(BuildContext context, StorySource s) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final bytes = s.imageBytes;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Tư liệu gốc · ${fmtDate(s.date)}',
                    'Original source · ${fmtDate(s.date)}'),
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (bytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                )
              else
                Flexible(child: SingleChildScrollView(
                  child: SelectableText(
                    s.text,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                )),
            ],
          ),
        ),
      );
    },
  );
}

class StorySourceChip extends StatelessWidget {
  final StorySource source;

  const StorySourceChip({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final icon = source.type == SourceType.photo
        ? Icons.image_outlined
        : source.type == SourceType.voice
        ? Icons.mic_none
        : Icons.notes;
    return ActionChip(
      avatar: Icon(icon, size: 14, color: AppColors.brand),
      label: Text(fmtDate(source.date)),
      labelStyle: const TextStyle(fontSize: 12),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
      onPressed: () => showStorySourceSheet(context, source),
    );
  }
}

class StoryBlockCard extends StatelessWidget {
  final StoryBlock block;
  final Map<String, StorySource> sources;
  final bool canEdit;
  final String currentUid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const StoryBlockCard({
    super.key,
    required this.block,
    required this.sources,
    required this.canEdit,
    required this.currentUid,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final linked = [
      for (final id in block.sourceIds)
        if (sources[id] != null) sources[id]!,
    ];
    final photo = block.type == kBlockMedia && linked.isNotEmpty
        ? linked.first.imageBytes
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  photo,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (block.text.isNotEmpty)
            block.type == kBlockQuote
                ? Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.brand, width: 3),
                ),
              ),
              child: Text(
                block.text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
                : Text(
              block.text,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                block.aiGenerated ? Icons.auto_awesome : Icons.edit_outlined,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  block.aiGenerated
                      ? tr('AI viết từ nguồn bên dưới',
                      'AI wrote this from the sources below')
                      : block.lastEditedBy == currentUid
                      ? tr('Bạn đã chỉnh sửa', 'Edited by you')
                      : tr('Đã được chỉnh sửa', 'Edited by a collaborator'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              if (canEdit) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
          if (linked.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [for (final s in linked) StorySourceChip(source: s)],
            ),
        ],
      ),
    );
  }
}

/// Các câu AI cần người dùng bổ sung (thay vì tự đoán).
class StoryMissingCard extends StatelessWidget {
  final List<String> questions;

  const StoryMissingCard({super.key, required this.questions});

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('AI cần thêm thông tin, nên chưa tự điền:',
                'The AI needs more info and did not guess:'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final q in questions)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $q'),
            ),
        ],
      ),
    );
  }
}