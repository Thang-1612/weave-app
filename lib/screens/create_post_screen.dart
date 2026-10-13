import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../models/space.dart';
import '../services/auto_category.dart';
import '../services/capsule_service.dart';
import '../services/image_utils.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audience_picker.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/poll_editor.dart';
import '../widgets/reaction_picker.dart';
import '../widgets/space_picker.dart';

/// Một khối đang soạn: text, image hoặc link.
class _Draft {
  final Key key = UniqueKey();
  final String type;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final Uint8List? bytes;
  final int width;
  final int height;
  final String url;
  final String title;

  _Draft.text()
      : type = 'text',
        controller = TextEditingController(),
        focusNode = FocusNode(),
        bytes = null,
        width = 0,
        height = 0,
        url = '',
        title = '';

  _Draft.image(this.bytes, this.width, this.height)
      : type = 'image',
        controller = null,
        focusNode = null,
        url = '',
        title = '';

  _Draft.link(this.url, this.title)
      : type = 'link',
        controller = null,
        focusNode = null,
        bytes = null,
        width = 0,
        height = 0;
}

class CreatePostScreen extends StatefulWidget {
  final String? initialSpaceId;
  final Post? forkOf; // rẽ nhánh từ bài này

  const CreatePostScreen({super.key, this.initialSpaceId, this.forkOf});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const _maxImages = 4;

  // null = để app tự nhận biết chủ đề từ nội dung bài viết
  late String? _spaceId = widget.initialSpaceId ?? widget.forkOf?.spaceId;
  final List<_Draft> _drafts = [];
  final List<_Draft> _trash = []; // khối đã xóa, dọn khi đóng màn hình
  _Draft? _lastText; // ô chữ được bấm vào gần nhất (nơi chèn emoji)
  bool _posting = false;
  bool _busy = false; // đang xử lý ảnh
  bool _classifying = false; // đang nhận biết chủ đề
  String _visibility = 'public'; // public, friends hoặc me
  DateTime? _openAt; // ngày mở hộp thời gian, null = đăng bài thường
  DateTime? _expiresAt; // tự ẩn bài sau thời điểm này, null = không
  bool _isQuestion = false; // đăng như một câu hỏi cần đáp án
  PollDraft? _poll; // bình chọn đang soạn, null = không có bình chọn

  void _refresh() {
    if (mounted) setState(() {});
  }

  _Draft _newText([String initial = '']) {
    final d = _Draft.text();
    if (initial.isNotEmpty) d.controller!.text = initial;
    d.controller!.addListener(_refresh);
    d.focusNode!.addListener(() {
      if (d.focusNode!.hasFocus) _lastText = d;
    });
    return d;
  }

  @override
  void initState() {
    super.initState();
    final src = widget.forkOf;
    if (src != null) {
      // Chép các khối của bài gốc để chỉnh sửa
      for (final b in src.blocks) {
        final type = b['type'];
        if (type == 'text') {
          _drafts.add(_newText(b['text'] as String? ?? ''));
        } else if (type == 'image') {
          try {
            _drafts.add(_Draft.image(
              base64Decode(b['data'] as String? ?? ''),
              (b['w'] as num?)?.toInt() ?? 0,
              (b['h'] as num?)?.toInt() ?? 0,
            ));
          } catch (_) {}
        } else if (type == 'link') {
          _drafts.add(_Draft.link(
            b['url'] as String? ?? '',
            b['title'] as String? ?? '',
          ));
        }
      }
      _drafts.add(_newText()); // ô trống để viết thêm phần của bạn
    } else {
      _drafts.add(_newText());
    }
  }

  bool get _hasContent => _drafts.any(
        (d) => d.type == 'text' ? d.controller!.text.trim().isNotEmpty : true,
  );

  // Có bình chọn thì phải điền ít nhất 2 lựa chọn
  bool get _canPost =>
      _hasContent && !_posting && !_busy && (_poll?.valid ?? true);

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Ảnh đầu tiên của bài (đã nén), dùng để AI nhận biết chủ đề.
  Uint8List? _firstImageBytes() {
    for (final d in _drafts) {
      if (d.type == 'image') return d.bytes;
    }
    return null;
  }

  Future<void> _pickAudience() async {
    final picked = await showAudiencePicker(context, current: _visibility);
    if (picked == null || !mounted) return;
    if (picked == 'public' && _openAt != null) {
      _snack(tr('Hộp thời gian không thể đăng công khai',
          'A time capsule cannot be public'));
      return;
    }
    setState(() {
      _visibility = picked;
      // Bài không công khai không tính điểm đáp án nên tắt chế độ câu hỏi
      if (picked != 'public') _isQuestion = false;
    });
  }

  /// Mở hộp soạn bình chọn (tạo bản nháp nếu chưa có).
  Future<void> _editPoll() async {
    final draft = _poll ?? (PollDraft()..addListener(_refresh));
    setState(() => _poll = draft);
    await showPollEditorSheet(context, draft);
  }

  /// Bỏ bình chọn. Dọn bản nháp sau khung hình hiện tại để không có widget
  /// nào còn nghe một đối tượng đã bị hủy.
  void _removePoll() {
    final old = _poll;
    setState(() => _poll = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  Future<void> _pickOpenAt() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _openAt ?? now.add(const Duration(days: 180)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: tr('Chọn ngày mở hộp', 'Choose the opening date'),
    );
    if (d == null || !mounted) return;
    setState(() {
      _openAt = DateTime(d.year, d.month, d.day, 8);
      _isQuestion = false; // hộp thời gian không phải câu hỏi
      if (_visibility == 'public') _visibility = 'friends';
    });
    // Hộp thời gian không có bình chọn
    if (_poll != null) _removePoll();
  }

  Future<void> _pickExpiry() async {
    final options = <(String, Duration?)>[
      (tr('Không tự ẩn', 'Never'), null),
      (tr('Sau 24 giờ', 'After 24 hours'), const Duration(hours: 24)),
      (tr('Sau 3 ngày', 'After 3 days'), const Duration(days: 3)),
      (tr('Sau 7 ngày', 'After 7 days'), const Duration(days: 7)),
      (tr('Sau 30 ngày', 'After 30 days'), const Duration(days: 30)),
    ];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++)
              ListTile(
                title: Text(options[i].$1),
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final d = options[picked].$2;
    setState(() => _expiresAt = d == null ? null : DateTime.now().add(d));
  }

  String _spaceChipLabel() {
    final id = _spaceId;
    if (id == null) return tr('Chọn chủ đề', 'Choose topic');
    final s = findSpace(id);
    if (s == null) return id;
    return '${s.emoji} ${tr(s.name, s.nameEn ?? s.name)}';
  }

  Future<void> _pickSpace() async {
    final picked = await showSpacePicker(
      context,
      current: _spaceId,
      title: tr('Chọn chủ đề cho bài viết', 'Choose a topic for your post'),
    );
    if (picked != null && mounted) setState(() => _spaceId = picked);
  }

  void _remove(int i) {
    setState(() {
      final d = _drafts.removeAt(i);
      if (_lastText == d) _lastText = null;
      _trash.add(d);
      if (_drafts.isEmpty) _drafts.add(_newText());
    });
  }

  _Draft _appendText() {
    final d = _newText();
    setState(() => _drafts.add(d));
    return d;
  }

  void _addText() => _appendText();

  Future<void> _addImage() async {
    if (_drafts.where((d) => d.type == 'image').length >= _maxImages) {
      _snack(
        tr(
          'Tối đa $_maxImages ảnh mỗi bài viết',
          'At most $_maxImages images per post',
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      setState(() => _busy = true);
      final raw = await picked.readAsBytes();
      final result = await compressImage(raw);
      if (!mounted) return;
      setState(() {
        _drafts.add(_Draft.image(result.bytes, result.width, result.height));
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content:
          Text('${tr('Không thêm được ảnh', 'Could not add image')}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addLink() async {
    final result = await showDialog<_LinkResult>(
      context: context,
      builder: (_) => const _LinkDialog(),
    );
    if (result == null || !mounted) return;
    setState(() => _drafts.add(_Draft.link(result.url, result.title)));
  }

  /// Chọn emoji rồi chèn vào ô chữ tại vị trí con trỏ.
  Future<void> _addEmoji() async {
    final e = await showEmojiEntrySheet(context);
    if (e == null || !mounted) return;
    _insertEmoji(e);
  }

  void _insertEmoji(String emoji) {
    // Ô chữ đang dùng, nếu không có thì ô chữ cuối cùng, nếu không có thì tạo mới
    _Draft? target = _lastText;
    if (target == null || !_drafts.contains(target)) {
      target = null;
      for (final d in _drafts.reversed) {
        if (d.type == 'text') {
          target = d;
          break;
        }
      }
    }
    final draft = target ?? _appendText();

    final c = draft.controller!;
    final len = c.text.length;
    final sel = c.selection;
    final start = sel.isValid ? sel.start.clamp(0, len).toInt() : len;
    final end = sel.isValid ? sel.end.clamp(0, len).toInt() : len;

    c.value = TextEditingValue(
      text: c.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    draft.focusNode!.requestFocus();
  }

  Future<void> _post() async {
    final messenger = ScaffoldMessenger.of(context);

    final blocks = <Map<String, dynamic>>[];
    for (final d in _drafts) {
      if (d.type == 'text') {
        final t = d.controller!.text.trim();
        if (t.isNotEmpty) blocks.add({'type': 'text', 'text': t});
      } else if (d.type == 'image') {
        blocks.add({
          'type': 'image',
          'data': base64Encode(d.bytes!),
          'w': d.width,
          'h': d.height,
        });
      } else if (d.type == 'link') {
        blocks.add({'type': 'link', 'url': d.url, 'title': d.title});
      }
    }
    if (blocks.isEmpty) return;

    // Firestore giới hạn khoảng 1 MiB mỗi bài viết
    if (jsonEncode(blocks).length > 900 * 1024) {
      _snack(
        tr(
          'Bài viết quá lớn, hãy bớt ảnh',
          'This post is too large, try removing some images',
        ),
      );
      return;
    }

    setState(() => _posting = true);
    try {
      // Câu hỏi không gắn chủ đề: bỏ qua bước chọn và nhận biết chủ đề
      var spaceId = _isQuestion ? '' : _spaceId;
      var source = 'user';

      if (spaceId == null) {
        // Chưa chọn chủ đề: app tự nhận biết từ chữ, liên kết và ảnh
        setState(() => _classifying = true);
        final decision = await AutoCategory.decide(
          blocks: blocks,
          imageBytes: _firstImageBytes(),
        );
        if (!mounted) return;
        setState(() => _classifying = false);

        if (decision.spaceId != null && decision.confident) {
          spaceId = decision.spaceId;
          source = decision.source;
        } else {
          // Chưa chắc chắn: hỏi người dùng, gợi ý sẵn lựa chọn khả dĩ nhất
          final picked = await showSpacePicker(
            context,
            suggested: decision.spaceId,
            title: tr(
              'Bài viết thuộc chủ đề nào?',
              'Which topic does this post belong to?',
            ),
            subtitle: tr(
              'App chưa chắc chắn, bạn chọn giúp nhé',
              'The app is not sure, please choose',
            ),
          );
          if (picked == null) {
            if (mounted) setState(() => _posting = false);
            return;
          }
          spaceId = picked;
        }
      }

      final chosen = spaceId!;

      // Hộp thời gian (không giữ liên kết rẽ nhánh, không có bình chọn)
      if (_openAt != null) {
        await CapsuleService.create(
          spaceId: chosen,
          blocks: blocks,
          openAt: _openAt!,
          visibility: _visibility,
          spaceSource: source,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(
          content: Text(
            '${tr('Đã niêm phong, hộp sẽ mở vào', 'Sealed, opens on')} ${CapsuleService.fmtDate(_openAt!)}',
          ),
        ));
        return;
      }

      await PostService.createPost(
        spaceId: chosen,
        blocks: blocks,
        spaceSource: source,
        visibility: _visibility,
        forkedFrom: widget.forkOf?.id,
        forkedFromAuthor: widget.forkOf?.authorName,
        expiresAt: _expiresAt,
        isQuestion: _isQuestion,
        pollOptions: _poll?.options,
        pollMultiple: _poll?.multiple ?? false,
        pollClosesAt: _poll?.closeAfter == null
            ? null
            : DateTime.now().add(_poll!.closeAfter!),
      );
      if (!mounted) return;
      Navigator.of(context).pop();

      final space = findSpace(chosen) ?? defaultSpaces.first;
      final spaceLabel =
          '${space.emoji} ${tr(space.name, space.nameEn ?? space.name)}';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            (source == 'user' || _isQuestion)
                ? tr('Đã đăng bài viết', 'Post published')
                : tr(
              'Đã đăng và tự xếp vào $spaceLabel',
              'Published and automatically filed under $spaceLabel',
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _posting = false;
          _classifying = false;
        });
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('${tr('Không đăng được', 'Could not publish')}: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final d in [..._drafts, ..._trash]) {
      d.controller?.dispose();
      d.focusNode?.dispose();
    }
    _poll?.dispose();
    super.dispose();
  }

  Widget _buildBlock(_Draft d, int i) {
    switch (d.type) {
      case 'text':
        return TextField(
          controller: d.controller,
          focusNode: d.focusNode,
          maxLines: null,
          decoration: InputDecoration(
            hintText: i == 0
                ? (_isQuestion
                ? tr('Bạn muốn hỏi điều gì?', 'What would you like to ask?')
                : tr('Bạn đang nghĩ gì?', "What's on your mind?"))
                : tr('Viết tiếp...', 'Keep writing...'),
            border: InputBorder.none,
          ),
        );
      case 'image':
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              d.bytes!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        );
      case 'link':
        return Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.link, color: AppColors.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d.title.isNotEmpty)
                      Text(
                        d.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    Text(
                      d.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: TextButton.icon(
        onPressed: _busy || _posting ? null : onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: TextButton.styleFrom(foregroundColor: AppColors.brand),
      ),
    );
  }

  String _pollChipLabel() {
    final poll = _poll;
    if (poll == null) return tr('Thêm bình chọn', 'Add a poll');
    final n = poll.options.length;
    return poll.valid
        ? tr('Bình chọn: $n lựa chọn', 'Poll: $n options')
        : tr('Bình chọn (cần ít nhất 2 lựa chọn)',
        'Poll (needs at least 2 options)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        title: Text(tr('Tạo bài viết', 'Create post')),
        actions: [
          TextButton(
            onPressed: _canPost ? _post : null,
            child: _posting
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Text(
              tr('Đăng', 'Post'),
              style: TextStyle(
                color: _canPost
                    ? Colors.white
                    : const Color.fromRGBO(255, 255, 255, 0.6),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              // Chủ đề (câu hỏi không có chủ đề)
              if (!_isQuestion)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          avatar: const Icon(Icons.auto_awesome, size: 16),
                          label: Text(tr('Tự động', 'Auto')),
                          selected: _spaceId == null,
                          onSelected: (_) => setState(() => _spaceId = null),
                        ),
                        ActionChip(
                          backgroundColor:
                          _spaceId != null ? AppColors.soft : null,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_spaceChipLabel()),
                              const Icon(Icons.arrow_drop_down, size: 18),
                            ],
                          ),
                          onPressed: _posting ? null : _pickSpace,
                        ),
                      ],
                    ),
                  ),
                ),
              // Đối tượng xem: Công khai / Bạn bè / Chỉ mình tôi
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: Icon(audienceIcon(_visibility), size: 16),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(audienceLabel(_visibility)),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                    onPressed: _posting ? null : _pickAudience,
                  ),
                ),
              ),
              if (_visibility != 'public')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      audienceHint(_visibility),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              // Hộp thời gian (câu hỏi không dùng)
              if (!_isQuestion)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      avatar: const Icon(Icons.hourglass_bottom, size: 16),
                      label: Text(_openAt == null
                          ? tr('Hẹn giờ mở', 'Time capsule')
                          : '${tr('Mở vào', 'Opens on')} ${CapsuleService.fmtDate(_openAt!)}'),
                      onPressed: _posting ? null : _pickOpenAt,
                      onDeleted: _openAt == null
                          ? null
                          : () => setState(() => _openAt = null),
                    ),
                  ),
                ),
              if (_openAt == null && !_isQuestion)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      avatar: const Icon(Icons.timer_off_outlined, size: 16),
                      label: Text(_expiresAt == null
                          ? tr('Tự ẩn sau...', 'Auto-hide after...')
                          : '${tr('Tự ẩn vào', 'Hides on')} ${CapsuleService.fmtDate(_expiresAt!)}'),
                      onPressed: _posting ? null : _pickExpiry,
                      onDeleted: _expiresAt == null
                          ? null
                          : () => setState(() => _expiresAt = null),
                    ),
                  ),
                ),
              // Câu hỏi: người xem trả lời bằng bình luận, tác giả chọn đáp án.
              // Chỉ hiện ở bài công khai vì bài khác không tính điểm đáp án.
              if (_openAt == null &&
                  widget.forkOf == null &&
                  _visibility == 'public')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      avatar: const Icon(Icons.help_outline, size: 16),
                      label: Text(tr('Đây là câu hỏi', 'This is a question')),
                      selected: _isQuestion,
                      onSelected: _posting
                          ? null
                          : (v) => setState(() {
                        _isQuestion = v;
                        if (v) _expiresAt = null;
                      }),
                    ),
                  ),
                ),
              if (_isQuestion)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr(
                        'Mọi người trả lời bằng bình luận, bạn chọn đáp án đúng nhất.',
                        'People answer in comments, and you pick the best answer.',
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              // Bình chọn: người xem chọn đáp án, kết quả hiện sau khi bỏ phiếu
              if (_openAt == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      avatar: const Icon(Icons.poll_outlined, size: 16),
                      label: Text(_pollChipLabel()),
                      selected: _poll != null,
                      onPressed: _posting ? null : _editPoll,
                      onDeleted: _poll == null ? null : _removePoll,
                    ),
                  ),
                ),
              // Thông báo đang rẽ nhánh
              if (widget.forkOf != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call_split,
                            size: 16, color: AppColors.brand),
                        const SizedBox(width: 6),
                        Text(
                          '${tr('Rẽ nhánh từ bài của', 'Forking')} ${widget.forkOf!.authorName}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.brand),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_busy || _classifying)
                const LinearProgressIndicator(minHeight: 2),
              if (_classifying)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr(
                        'Đang nhận biết chủ đề của bài viết...',
                        'Detecting the topic of your post...',
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  itemCount: _drafts.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final d = _drafts.removeAt(oldIndex);
                      _drafts.insert(newIndex, d);
                    });
                  },
                  itemBuilder: (context, i) {
                    final d = _drafts[i];
                    return Padding(
                      key: d.key,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.only(top: 12, right: 6),
                              child: Icon(
                                Icons.drag_indicator,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(child: _buildBlock(d, i)),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => _remove(i),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    _toolButton(Icons.text_fields, tr('Chữ', 'Text'), _addText),
                    _toolButton(
                      Icons.image_outlined,
                      tr('Ảnh', 'Photo'),
                      _addImage,
                    ),
                    _toolButton(Icons.link, 'Link', _addLink),
                    _toolButton(
                      Icons.emoji_emotions_outlined,
                      'Icon',
                      _addEmoji,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkResult {
  final String url;
  final String title;

  const _LinkResult(this.url, this.title);
}

String? _normalizeUrl(String input) {
  var v = input.trim();
  if (v.isEmpty) return null;
  if (!v.contains('://')) v = 'https://$v';
  final uri = Uri.tryParse(v);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (!uri.host.contains('.')) return null;
  return uri.toString();
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  String? _error;

  void _submit() {
    final url = _normalizeUrl(_url.text);
    if (url == null) {
      setState(() => _error = tr(
        'Địa chỉ liên kết không hợp lệ',
        'The link address is not valid',
      ));
      return;
    }
    Navigator.of(context).pop(_LinkResult(url, _title.text.trim()));
  }

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(tr('Thêm liên kết', 'Add a link')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _submit(),
              decoration: authInputDecoration(
                tr('Địa chỉ (URL)', 'Address (URL)'),
                Icons.link,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: authInputDecoration(
                tr('Tiêu đề (không bắt buộc)', 'Title (optional)'),
                Icons.title,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthErrorBox(message: _error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Hủy', 'Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
          onPressed: _submit,
          child: Text(tr('Thêm', 'Add')),
        ),
      ],
    );
  }
}