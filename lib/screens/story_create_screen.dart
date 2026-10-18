import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/story_models.dart';
import '../services/image_utils.dart';
import '../services/l10n.dart';
import '../services/story_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/story_widgets.dart';
import 'story_detail_screen.dart';

const kMaxStoryPhotos = 10;
const kMaxStoryNotes = 20;
/// Số lần dựng truyện bằng AI mỗi ngày trên thiết bị này.
const kStoryDailyLimit = 5;

/// Từ chiều rộng này trở lên: hai cột. Dưới mức này: chia thành 3 bước.
const double _kStoryCreateWideBreakpoint = 900;
const int _kStorySteps = 3;

class StoryCreateScreen extends StatefulWidget {
  const StoryCreateScreen({super.key});

  @override
  State<StoryCreateScreen> createState() => _StoryCreateScreenState();
}

class _StoryCreateScreenState extends State<StoryCreateScreen> {
  final _titleCtrl = TextEditingController();
  final List<StorySource> _sources = [];
  StoryKind _kind = StoryKind.week;
  bool _busy = false; // đang dựng truyện
  bool _picking = false; // đang nén ảnh
  String? _error;
  int _seq = 0;
  int _step = 0; // chỉ dùng ở bố cục hẹp (0..2)

  int _count(SourceType t) => _sources.where((s) => s.type == t).length;

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty || !mounted) return;
    setState(() => _picking = true);
    var skipped = 0;
    for (final f in files) {
      if (_count(SourceType.photo) >= kMaxStoryPhotos) {
        skipped++;
        continue;
      }
      try {
        // compressImage đã nén ảnh xuống tối đa 160 KB, vừa cho Firestore
        // và cho việc gửi ảnh vào AI.
        final c = await compressImage(await f.readAsBytes());
        DateTime date;
        try {
          date = await f.lastModified();
        } catch (_) {
          date = DateTime.now();
        }
        _sources.add(StorySource(
          id: 's${++_seq}',
          type: SourceType.photo,
          imageB64: base64Encode(c.bytes),
          date: date,
        ));
      } catch (_) {
        skipped++;
      }
    }
    if (!mounted) return;
    setState(() => _picking = false);
    if (skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          '$skipped ảnh bị bỏ qua (quá nhiều hoặc không đọc được)',
          '$skipped photos skipped (too many or unreadable)',
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
    final d = await showDatePicker(
      context: context,
      initialDate: _sources[i].date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null || !mounted) return;
    setState(() => _sources[i] = _sources[i].copyWith(date: d));
  }

  Future<void> _generate() async {
    final used = await UsageService.instance.countToday('story');
    if (used >= kStoryDailyLimit) {
      if (mounted) {
        setState(() => _error = tr(
          'Hôm nay bạn đã dựng $kStoryDailyLimit câu chuyện. Hãy quay lại vào ngày mai nhé.',
          'You have built $kStoryDailyLimit stories today. Come back tomorrow.',
        ));
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await StoryAi.generate(
        kind: _kind,
        userTitle: _titleCtrl.text,
        sources: _sources,
      );
      await UsageService.instance.bumpCount('story'); // chỉ tính khi AI thành công
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
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------
  // Các khối dùng chung cho cả hai bố cục
  // ---------------------------------------------------------------------

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: WeaveSpacing.sm),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );

  /// Loại câu chuyện + tiêu đề.
  Widget _kindAndTitle(bool locked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(tr('Loại câu chuyện', 'Story type')),
        ChipTheme(
          data: ChipTheme.of(context).copyWith(
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.soft,
            side: const BorderSide(color: AppColors.border),
            shape: const StadiumBorder(),
            showCheckmark: false,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in StoryKind.values)
                ChoiceChip(
                  avatar: Icon(storyKindIcon(k), size: 16),
                  label: Text(storyKindLabel(k)),
                  selected: _kind == k,
                  onSelected: locked ? null : (_) => setState(() => _kind = k),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleCtrl,
          maxLength: 60,
          enabled: !locked,
          decoration: InputDecoration(
            labelText: tr('Tiêu đề (không bắt buộc)', 'Title (optional)'),
          ),
        ),
      ],
    );
  }

  /// Hai nút thêm ảnh và ghi chú.
  Widget _addButtons(bool locked) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: locked ? null : _addPhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(tr(
                'Ảnh (${_count(SourceType.photo)}/$kMaxStoryPhotos)',
                'Photos (${_count(SourceType.photo)}/$kMaxStoryPhotos)')),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: locked ? null : _addNote,
            icon: const Icon(Icons.notes),
            label: Text(tr(
                'Ghi chú (${_count(SourceType.note)}/$kMaxStoryNotes)',
                'Notes (${_count(SourceType.note)}/$kMaxStoryNotes)')),
          ),
        ),
      ],
    );
  }

  /// Danh sách ảnh và ghi chú đã thêm (hoặc dòng hướng dẫn khi còn trống).
  List<Widget> _sourceTiles(bool locked) {
    if (_sources.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            tr('Chọn ảnh hoặc viết vài ghi chú. AI chỉ kể lại những gì có trong đó.',
                'Pick photos or write a few notes. The AI only retells what is in them.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ];
    }
    return [
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
          subtitle: Text(tr('Ngày ${fmtDate(_sources[i].date)} (chạm để đổi)',
              'Date ${fmtDate(_sources[i].date)} (tap to change)')),
          onTap: locked ? null : () => _changeDate(i),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed:
            locked ? null : () => setState(() => _sources.removeAt(i)),
          ),
        ),
    ];
  }

  /// Tóm tắt trước khi dựng: loại, tiêu đề, số ảnh và ghi chú.
  Widget _summary() {
    final title = _titleCtrl.text.trim();
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(storyKindIcon(_kind), storyKindLabel(_kind)),
        row(Icons.title,
            title.isEmpty ? tr('Tiêu đề: AI tự đặt', 'Title: chosen by the AI') : title),
        row(Icons.photo_outlined,
            tr('${_count(SourceType.photo)} ảnh', '${_count(SourceType.photo)} photos')),
        row(Icons.notes,
            tr('${_count(SourceType.note)} ghi chú', '${_count(SourceType.note)} notes')),
      ],
    );
  }

  /// Lỗi (nếu có) + nút Dựng câu chuyện: hành động chính duy nhất của màn hình.
  Widget _buildAction(bool locked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ),
        FilledButton.icon(
          onPressed: (_sources.isNotEmpty && !locked) ? _generate : null,
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
    );
  }

  // ---------------------------------------------------------------------
  // Bố cục rộng: ảnh/ghi chú bên trái, tùy chọn và nút dựng bên phải
  // ---------------------------------------------------------------------
  Widget _wide(bool locked) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Padding(
          padding: const EdgeInsets.all(WeaveSpacing.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel(tr('Ảnh và ghi chú', 'Photos and notes')),
                    _addButtons(locked),
                    if (_picking)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(children: _sourceTiles(locked)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WeaveSpacing.xl),
              SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(WeaveSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _kindAndTitle(locked),
                          const Divider(height: 32),
                          _summary(),
                          const SizedBox(height: 8),
                          _buildAction(locked),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Bố cục hẹp: 3 bước (Loại và tiêu đề, Ảnh và ghi chú, Dựng)
  // ---------------------------------------------------------------------
  Widget _narrow(bool locked) {
    final titles = [
      tr('Loại và tiêu đề', 'Type and title'),
      tr('Ảnh và ghi chú', 'Photos and notes'),
      tr('Xem lại và dựng', 'Review and build'),
    ];

    final Widget content;
    switch (_step) {
      case 0:
        content = _kindAndTitle(locked);
        break;
      case 1:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _addButtons(locked),
            if (_picking)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 12),
            ..._sourceTiles(locked),
          ],
        );
        break;
      default:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summary(),
            const SizedBox(height: 16),
            _buildAction(locked),
          ],
        );
    }

    final canNext = !locked && (_step != 1 || _sources.isNotEmpty);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Bước ${_step + 1}/$_kStorySteps · ${titles[_step]}',
                    'Step ${_step + 1}/$_kStorySteps · ${titles[_step]}'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_step + 1) / _kStorySteps,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
                backgroundColor: AppColors.border,
              ),
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [content],
              ),
            ),
          ),
        ),
        Material(
          color: AppColors.surface,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: locked ? null : () => setState(() => _step--),
                        child: Text(tr('Quay lại', 'Back')),
                      ),
                    const Spacer(),
                    // Bước cuối đã có nút Dựng trong nội dung, nên không có nút Tiếp tục
                    if (_step < _kStorySteps - 1)
                      FilledButton(
                        onPressed: canNext ? () => setState(() => _step++) : null,
                        child: Text(tr('Tiếp tục', 'Continue')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = _busy || _picking;
    final wide =
        MediaQuery.sizeOf(context).width >= _kStoryCreateWideBreakpoint;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Tạo câu chuyện', 'Create a story'))),
      body: wide ? _wide(locked) : _narrow(locked),
    );
  }
}