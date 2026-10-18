import 'dart:async';

import 'package:flutter/material.dart';
import '../models/interactions.dart';
import '../models/post.dart';
import '../services/interaction_service.dart';
import '../theme/app_theme.dart';
import '../services/l10n.dart';

const _customMarker = '__custom__';

/// Emoji hợp lệ: không chứa chữ, số, khoảng trắng và có ký tự ở vùng biểu tượng.
bool isValidEmoji(String t) {
  if (t.isEmpty || t.length > 16) return false;
  if (RegExp(r'[\p{L}\p{N}\s]', unicode: true).hasMatch(t)) return false;
  return t.runes.any((r) => r >= 0x2190 || r == 0xA9 || r == 0xAE);
}

/// Mở bàn phím để người dùng chọn một icon bất kỳ. Tự đóng khi nhận được emoji.
Future<String?> showEmojiEntrySheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(WeaveRadius.card),
      ),
    ),
    builder: (_) => const _EmojiEntrySheet(),
  );
}

/// Khay cảm xúc: các cảm xúc chính, icon tự chọn gần đây và nút "＋".
class _PickerBubble extends StatelessWidget {
  final String? current;
  final List<String> recent;
  final ValueChanged<String> onSelect; // emoji, hoặc _customMarker

  const _PickerBubble({
    required this.current,
    required this.recent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(32),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Không cắt phần biểu tượng phóng to nhảy ra ngoài khay
        clipBehavior: Clip.none,
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < mainReactions.length; i++)
              _EmojiTile(
                index: i,
                emoji: mainReactions[i].emoji,
                label: mainReactions[i].text,
                selected: current == mainReactions[i].emoji,
                onTap: () => onSelect(mainReactions[i].emoji),
              ),
            if (recent.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(width: 1, height: 28, color: AppColors.border),
              const SizedBox(width: 4),
              for (var j = 0; j < recent.length; j++)
                _EmojiTile(
                  index: mainReactions.length + j,
                  emoji: recent[j],
                  label: tr('Icon của bạn', 'Your icon'),
                  selected: current == recent[j],
                  onTap: () => onSelect(recent[j]),
                ),
            ],
            const SizedBox(width: 4),
            Tooltip(
              message: tr('Chọn biểu tượng khác', 'Pick another emoji'),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onSelect(_customMarker),
                child: Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                  ),
                  child: const Icon(Icons.add, color: AppColors.brand),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một biểu tượng trong khay: bật lên khi khay mở, phóng to và nhảy lên khi
/// rê chuột (hoặc chạm giữ), kèm nhãn tên phía trên.
class _EmojiTile extends StatefulWidget {
  final int index;
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _EmojiTile({
    required this.index,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_EmojiTile> createState() => _EmojiTileState();
}

class _EmojiTileState extends State<_EmojiTile> {
  bool _hover = false;
  bool _pressed = false;

  bool get _active => _hover || _pressed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      // Biểu tượng càng về sau càng bật lên muộn hơn một chút
      duration: Duration(milliseconds: 180 + widget.index * 45),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(
        scale: v.clamp(0.0, 1.3).toDouble(),
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            onHover: (h) => setState(() => _hover = h),
            onHighlightChanged: (p) => setState(() => _pressed = p),
            child: AnimatedSlide(
              offset: Offset(0, _active ? -0.14 : 0),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: AnimatedScale(
                scale: _active ? 1.5 : 1.0,
                alignment: Alignment.bottomCenter,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.selected ? AppColors.soft : null,
                  ),
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
            ),
          ),
          // Nhãn tên phía trên biểu tượng đang trỏ vào
          Positioned(
            top: -34,
            left: -40,
            right: -40,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _active ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC111827),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiEntrySheet extends StatefulWidget {
  const _EmojiEntrySheet();

  @override
  State<_EmojiEntrySheet> createState() => _EmojiEntrySheetState();
}

class _EmojiEntrySheetState extends State<_EmojiEntrySheet> {
  final _controller = TextEditingController();
  String? _error;

  void _onChanged(String value) {
    final t = value.trim();
    if (t.isEmpty) {
      setState(() => _error = null);
      return;
    }
    if (isValidEmoji(t)) {
      Navigator.of(context).pop(t);
    } else {
      setState(() => _error = tr(
        'Chỉ nhập biểu tượng cảm xúc (emoji)',
        'Enter emoji only',
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('Chọn biểu tượng cảm xúc', 'Pick an emoji'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'Mở bàn phím emoji rồi chọn một biểu tượng.\nTrên Windows: nhấn Windows + dấu chấm (.).',
              'Open your emoji keyboard and pick one.\nOn Windows: press Windows + period (.).',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32),
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: '😊',
              errorText: _error,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(WeaveRadius.card),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(WeaveRadius.card),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vùng bấm có khay cảm xúc, dùng chung cho bài viết và bình luận.
/// - Bấm: thả hoặc bỏ 👍.
/// - Rê chuột vào (laptop): hiện khay cảm xúc.
/// - Chạm giữ (điện thoại) hoặc chuột phải: hiện khay cảm xúc.
class ReactionTrigger extends StatefulWidget {
  /// Cảm xúc hiện tại của tôi (null nếu chưa thả).
  final Stream<String?> mine;

  /// Gọi khi người dùng thả, đổi hoặc bỏ một cảm xúc.
  final Future<void> Function(String emoji) onApply;

  /// Giao diện bên trong vùng bấm.
  final Widget Function(BuildContext context, String? mine) builder;

  final BorderRadius borderRadius;

  const ReactionTrigger({
    super.key,
    required this.mine,
    required this.onApply,
    required this.builder,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  State<ReactionTrigger> createState() => _ReactionTriggerState();
}

class _ReactionTriggerState extends State<ReactionTrigger> {
  final _anchor = GlobalKey();
  final _link = LayerLink();

  OverlayEntry? _entry;
  Timer? _openTimer;
  Timer? _closeTimer;
  bool _overButton = false;
  bool _overBubble = false;
  String? _current;
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final list = await ReactionService.recentCustom();
    if (mounted) _recent = list;
  }

  @override
  void dispose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  Future<void> _apply(String emoji) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onApply(emoji);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${tr('Không thả được cảm xúc', 'Could not react')}: $e',
          ),
        ),
      );
    }
  }

  void _closePicker() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _entry?.remove();
    _entry = null;
    _overBubble = false;
  }

  // Rê chuột vào: chờ một chút rồi mới mở, tránh hiện khi chỉ lướt qua
  void _scheduleOpen() {
    _closeTimer?.cancel();
    if (_entry != null) return;
    _openTimer?.cancel();
    _openTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _overButton) _showPicker(modal: false);
    });
  }

  // Rời cả nút lẫn khay: chờ một chút rồi đóng, để kịp di chuột sang khay
  void _scheduleClose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 250), () {
      if (!_overButton && !_overBubble) _closePicker();
    });
  }

  /// [modal] = true (chạm giữ / chuột phải): có lớp nền trong suốt,
  /// chạm ra ngoài để đóng. false (rê chuột): tự đóng khi chuột rời đi.
  void _showPicker({required bool modal}) {
    if (_entry != null) {
      if (!modal) return;
      _closePicker();
    }

    final anchorContext = _anchor.currentContext;
    if (anchorContext == null) return;
    final box = anchorContext.findRenderObject();
    if (box is! RenderBox) return;

    final overlay = Overlay.of(context);
    final origin = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.of(context).size;

    final count = mainReactions.length + _recent.length + 1;
    final width = (count * 46.0 + 24).clamp(0.0, screen.width - 16).toDouble();

    // Dịch khay sang trái/phải để không tràn ra ngoài màn hình
    var shift = 0.0;
    if (origin.dx + width > screen.width - 8) {
      shift = screen.width - 8 - width - origin.dx;
    }
    if (origin.dx + shift < 8) shift = 8 - origin.dx;

    // Nút sát mép trên màn hình thì mở khay xuống phía dưới
    final above = origin.dy > 72;

    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          if (modal)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closePicker,
                child: const SizedBox.expand(),
              ),
            ),
          Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: above ? Alignment.topLeft : Alignment.bottomLeft,
              followerAnchor: above ? Alignment.bottomLeft : Alignment.topLeft,
              offset: Offset(shift, above ? -4 : 4),
              child: SizedBox(
                width: width,
                child: MouseRegion(
                  onEnter: (_) {
                    _overBubble = true;
                    _closeTimer?.cancel();
                  },
                  onExit: (_) {
                    _overBubble = false;
                    _scheduleClose();
                  },
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 150),
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, (1 - v) * (above ? 8 : -8)),
                        child: child,
                      ),
                    ),
                    child: _PickerBubble(
                      current: _current,
                      recent: _recent,
                      onSelect: _choose,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  Future<void> _choose(String value) async {
    _closePicker();
    if (value == _customMarker) {
      final custom = await showEmojiEntrySheet(context);
      if (custom == null || !mounted) return;
      await ReactionService.rememberCustom(custom);
      _recent = await ReactionService.recentCustom();
      await _apply(custom);
    } else {
      await _apply(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: widget.mine,
      builder: (context, snap) {
        final mine = snap.data;
        _current = mine;

        return CompositedTransformTarget(
          link: _link,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) {
              _overButton = true;
              _scheduleOpen();
            },
            onExit: (_) {
              _overButton = false;
              _scheduleClose();
            },
            child: InkWell(
              key: _anchor,
              borderRadius: widget.borderRadius,
              onTap: () {
                _closePicker();
                _apply(mine ?? '👍');
              },
              onLongPress: () => _showPicker(modal: true),
              onSecondaryTap: () => _showPicker(modal: true),
              child: widget.builder(context, mine),
            ),
          ),
        );
      },
    );
  }
}

/// Nút cảm xúc trên bài viết.
///
/// Cùng chiều cao (44), bo góc (12) và cỡ chữ (15, đậm vừa) với nút Bình luận
/// (TextButton theo theme), để hàng nút thích / bình luận / lưu / chia sẻ
/// đồng đều và có cùng hiệu ứng rê chuột, nhấn.
class ReactionButton extends StatefulWidget {
  final Post post;

  const ReactionButton({super.key, required this.post});

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton> {
  late final Stream<String?> _mine = ReactionService.watchMyReaction(
    widget.post.id,
    collection: widget.post.collection,
  );

  @override
  Widget build(BuildContext context) {
    return ReactionTrigger(
      mine: _mine,
      borderRadius: BorderRadius.circular(WeaveRadius.control),
      onApply: (emoji) => ReactionService.setReaction(widget.post, emoji),
      builder: (context, mine) {
        final color = mine != null ? AppColors.brand : AppColors.textSecondary;
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: WeaveSizes.buttonHeightCompact,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: WeaveSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mine != null)
                  Text(mine, style: const TextStyle(fontSize: 20))
                else
                  Icon(Icons.thumb_up_alt_outlined, size: 20, color: color),
                const SizedBox(width: 6),
                Text(
                  mine != null ? reactionLabel(mine) : tr('Thích', 'Like'),
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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