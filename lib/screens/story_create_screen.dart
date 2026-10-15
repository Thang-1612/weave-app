import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../models/story_models.dart';
import '../services/l10n.dart';
import '../services/story_ai_service.dart';
import '../services/story_service.dart';
import '../theme/app_theme.dart';
import '../widgets/story_widgets.dart';
import 'story_detail_screen.dart';

const kMaxStoryPhotos = 10;
const kMaxStoryNotes = 20;
// Ảnh sau khi nén phải nhỏ để document Firestore dưới 1 MiB. Khi có thể,
// thay bước nén bên dưới bằng hàm trong image_utils.dart (tối đa khoảng 160 KB).
const kMaxPhotoBytes = 600 * 1024;

class StoryCreateScreen extends StatefulWidget {
  const StoryCreateScreen({super.key});

  @override
  State<StoryCreateScreen> createState() => _StoryCreateScreenState();
}

class _StoryCreateScreenState extends State<StoryCreateScreen> {
  final _titleCtrl = TextEditingController();
  final List<StorySource> _sources = [];
  StoryKind _kind = StoryKind.week;
  bool _busy = false;
  String? _error;
  int _seq = 0;

  int _count(SourceType t) => _sources.where((s) => s.type == t).length;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final files = await ImagePicker()
        .pickMultiImage(maxWidth: 1280, imageQuality: 70);
    if (files.isEmpty || !mounted) return;
    var skipped = 0;
    for (final f in files) {
      if (_count(SourceType.photo) >= kMaxStoryPhotos) {
        skipped++;
        continue;
      }
      final bytes = await f.readAsBytes();
      if (bytes.length > kMaxPhotoBytes) {
        skipped++;
        continue;
      }
      DateTime date;
      try {
        date = await f.lastModified();
      } catch (_) {
        date = DateTime.now();
      }
      _sources.add(StorySource(
        id: 's${++_seq}',
        type: SourceType.photo,
        imageB64: base64Encode(bytes),
        date: date,
      ));
    }
    if (!mounted) return;
    setState(() {});
    if (skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          '$skipped ảnh bị bỏ qua (quá nhiều hoặc quá lớn)',
          '$skipped photos skipped (too many or too large)',
        )),
      ));
    }
  }

  Future<void> _addNote() async {
    if (_count(SourceType.note) >= kMaxStoryNotes) return;
    final text = await showStoryTextDialog(
      context,
      title: tr('Thêm ghi chú', 'Add a note'),
      hint: tr('Hôm nay mình đã làm gì, ở đâu, với ai...',
          'What I did today, where, with whom...'),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    setState(() => _sources.add(StorySource(
      id: 's${++_seq}',
      type: SourceType.note,
      text: text.trim(),
      date: DateTime.now(),
    )));
  }

  Future<void> _changeDate(int i) async {
    final cur = _sources[i].date;
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null || !mounted) return;
    setState(() => _sources[i] = _sources[i].copyWith(date: d));
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await StoryAiService.generate(
        kind: _kind,
        userTitle: _titleCtrl.text,
        sources: _sources,
      );
      final id = await StoryService.createFromDraft(
        kind: _kind,
        draft: draft,
        sources: _sources,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => StoryDetailScreen(storyId: id)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate = _sources.isNotEmpty && !_busy;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Tạo câu chuyện', 'Create a story'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final k in StoryKind.values)
                ChoiceChip(
                  avatar: Icon(storyKindIcon(k), size: 16),
                  label: Text(storyKindLabel(k)),
                  selected: _kind == k,
                  selectedColor: AppColors.soft,
                  onSelected: _busy ? null : (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            maxLength: 60,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: tr('Tiêu đề (không bắt buộc)', 'Title (optional)'),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _addPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(tr('Ảnh (${_count(SourceType.photo)}/$kMaxStoryPhotos)',
                      'Photos (${_count(SourceType.photo)}/$kMaxStoryPhotos)')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _addNote,
                  icon: const Icon(Icons.notes),
                  label: Text(tr('Ghi chú (${_count(SourceType.note)}/$kMaxStoryNotes)',
                      'Notes (${_count(SourceType.note)}/$kMaxStoryNotes)')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_sources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                tr('Chọn ảnh hoặc viết vài ghi chú. AI chỉ kể lại những gì có trong đó.',
                    'Pick photos or write a few notes. The AI only retells what is in them.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          for (var i = 0; i < _sources.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _sources[i].imageBytes != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_sources[i].imageBytes!,
                    width: 48, height: 48, fit: BoxFit.cover),
              )
                  : const CircleAvatar(
                backgroundColor: AppColors.soft,
                child: Icon(Icons.notes, color: AppColors.brand),
              ),
              title: Text(
                _sources[i].type == SourceType.photo
                    ? tr('Ảnh', 'Photo')
                    : _sources[i].text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                  tr('Ngày ${fmtDate(_sources[i].date)} (chạm để đổi)',
                      'Date ${fmtDate(_sources[i].date)} (tap to change)')),
              onTap: _busy ? null : () => _changeDate(i),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed:
                _busy ? null : () => setState(() => _sources.removeAt(i)),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: canGenerate ? _generate : null,
            icon: _busy
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.auto_awesome),
            label: Text(_busy
                ? tr('Đang dựng câu chuyện...', 'Building your story...')
                : tr('Dựng câu chuyện', 'Build my story')),
          ),
        ],
      ),
    );
  }
}