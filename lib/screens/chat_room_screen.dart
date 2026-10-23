import '../theme/app_theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../widgets/chat_widgets.dart';
import 'chat_info_screen.dart';

/// Gắn vào nút "Nhắn tin" ở hồ sơ người dùng.
Future<void> openChatWith(BuildContext context, String uid) async {
  try {
    final id = await ChatService.I.ensureDirect(uid);
    if (!context.mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: id)));
  } catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Không mở được chat: $e')));
  }
}

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  const ChatRoomScreen({super.key, required this.chatId});
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  /// Trên màn rộng, nội dung chat được canh giữa và giới hạn bề ngang này.
  static const double _maxContentWidth = 900;

  final svc = ChatService.I;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  late final Stream<Chat?> _chatStream = svc.chat(widget.chatId);
  late Stream<List<ChatMessage>> _msgStream = svc.messages(
    widget.chatId,
    _limit,
  );
  int _limit = 40;
  bool _canLoadMore = false, _marking = false, _aiBusy = false;
  ChatMessage? _reply, _editing;
  List<String> _suggest = [];
  List<ChatMessage> _cur = [];
  Chat? _chat;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    svc.cleanupExpired(widget.chatId);
    // Chỉ vẽ lại định kỳ khi thật sự cần: có chỉ báo "đang soạn" hoặc có
    // tin tự hủy sắp hết hạn. Tránh dựng lại cả màn mỗi 2 giây.
    _tick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final needs =
          (_chat?.typing.isNotEmpty ?? false) ||
          _cur.any((m) => m.expireAt != null);
      if (needs) setState(() {});
    });
    _scroll.addListener(() {
      if (_canLoadMore &&
          _scroll.hasClients &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _canLoadMore = false;
        setState(() {
          _limit += 40;
          _msgStream = svc.messages(widget.chatId, _limit);
        });
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _err(String m) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Canh giữa và giới hạn bề ngang cho các thanh cố định (banner, gợi ý, composer).
  /// Danh sách tin nhắn không dùng hàm này để lăn chuột ở lề vẫn cuộn được.
  Widget _centered(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxContentWidth),
      child: child,
    ),
  );

  bool _otherTyping(Chat c) {
    final now = DateTime.now();
    return c.typing.entries.any(
      (e) => e.key != svc.me && now.difference(e.value).inSeconds < 6,
    );
  }

  String? _seenText(Chat chat, ChatMessage m) {
    final me = svc.me;
    final seen = chat.members
        .where(
          (u) =>
              u != me &&
              chat.lastRead[u] != null &&
              !chat.lastRead[u]!.isBefore(m.createdAt),
        )
        .length;
    if (chat.isGroup) return seen > 0 ? 'Đã xem bởi $seen' : 'Đã gửi';
    return seen > 0 ? 'Đã xem' : 'Đã gửi';
  }

  Future<void> _submit() async {
    final chat = _chat;
    final t = _ctrl.text.trim();
    if (chat == null || t.isEmpty) return;
    final reply = _reply, editing = _editing;
    _ctrl.clear();
    setState(() {
      _reply = null;
      _editing = null;
      _suggest = [];
    });
    try {
      if (editing != null) {
        await svc.edit(chat.id, editing.id, t);
      } else {
        await svc.sendText(chat, t, replyTo: reply);
      }
    } catch (e) {
      _err('Không gửi được: $e');
    }
  }

  Future<void> _pickImage() async {
    final chat = _chat;
    if (chat == null) return;
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 65,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final reply = _reply;
      setState(() => _reply = null);
      await svc.sendImage(chat, bytes, replyTo: reply);
    } catch (e) {
      _err('$e');
    }
  }

  String _transcript({int take = 8}) {
    final me = svc.me;
    final l = _cur
        .where((m) => m.type == 'text' && !m.deleted)
        .take(take)
        .toList()
        .reversed;
    return l
        .map((m) => '${m.senderId == me ? "Tôi" : "Họ"}: ${m.text}')
        .join('\n');
  }

  Future<void> _suggestReplies() async {
    final ai = ChatConfig.aiComplete;
    if (ai == null || _cur.isEmpty) return;
    setState(() => _aiBusy = true);
    try {
      final out = await ai(
        'Dưới đây là đoạn hội thoại. Hãy gợi ý 3 câu trả lời ngắn, tự nhiên bằng tiếng Việt cho "Tôi" '
        'đáp lại tin nhắn cuối. Mỗi câu một dòng, không đánh số, không giải thích.\n\n${_transcript()}',
      );
      final lines = out
          .split('\n')
          .map(
            (s) => s.replaceFirst(RegExp(r'^[\s\-\*\u2022\d\.\)]+'), '').trim(),
          )
          .where((s) => s.isNotEmpty)
          .take(3)
          .toList();
      if (mounted) setState(() => _suggest = lines);
    } catch (e) {
      _err('AI lỗi: $e');
    }
    if (mounted) setState(() => _aiBusy = false);
  }

  Future<void> _summarize() async {
    final ai = ChatConfig.aiComplete;
    if (ai == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    String res;
    try {
      res = await ai(
        'Tóm tắt ngắn gọn cuộc trò chuyện sau bằng tiếng Việt (3-5 gạch đầu dòng):\n\n${_transcript(take: 40)}',
      );
    } catch (e) {
      res = 'AI lỗi: $e';
    }
    if (!mounted) return;
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tóm tắt cuộc trò chuyện'),
        content: SingleChildScrollView(child: Text(res)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showActions(ChatMessage m) {
    if (m.deleted || m.type == 'system') return;
    final mine = m.senderId == svc.me;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in ['👍', '❤️', '😂', '😮', '😢', '🙏'])
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        svc
                            .react(widget.chatId, m, e)
                            .catchError((x) => _err('$x'));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Trả lời'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _reply = m;
                  _editing = null;
                });
              },
            ),
            if (m.type == 'text')
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Sao chép'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: m.text));
                },
              ),
            if (mine && m.type == 'text')
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Sửa'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _editing = m;
                    _reply = null;
                    _ctrl.text = m.text;
                  });
                },
              ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.undo, color: AppColors.danger),
                title: const Text(
                  'Thu hồi',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  svc.recall(widget.chatId, m.id).catchError((x) => _err('$x'));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Chat?>(
      stream: _chatStream,
      builder: (context, cs) {
        final chat = cs.data;
        _chat = chat;
        if (cs.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text('Không mở được cuộc trò chuyện\n${cs.error}'),
            ),
          );
        }
        if (chat == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final me = svc.me;
        final typing = ChatConfig.enableTyping && _otherTyping(chat);
        final blocked = chat.blockedBy.isNotEmpty;
        final isRequest =
            !chat.isGroup &&
            !chat.acceptedBy.contains(me) &&
            chat.lastSenderId != me &&
            chat.hasMessages;

        return Scaffold(
          // Bàn phím mở thì thân Scaffold co lại, composer luôn nằm sát phía trên bàn phím
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            titleSpacing: 0,
            title: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatInfoScreen(chatId: chat.id),
                ),
              ),
              child: Row(
                children: [
                  ChatAvatar(chat, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChatTitle(chat, style: const TextStyle(fontSize: 16)),
                        if (typing || chat.isGroup)
                          Text(
                            typing
                                ? 'Đang soạn tin…'
                                : '${chat.members.length} thành viên',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (ChatConfig.aiComplete != null)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'sum') _summarize();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'sum',
                      child: Text('✨ Tóm tắt bằng AI'),
                    ),
                  ],
                ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatInfoScreen(chatId: chat.id),
                  ),
                ),
              ),
            ],
          ),
          // Không bọc cả cột trong ConstrainedBox: danh sách tin nhắn chiếm full
          // bề ngang (lăn chuột ở lề vẫn cuộn), các thanh cố định tự canh giữa.
          body: Column(
            children: [
              if (isRequest)
                _centered(
                  Container(
                    width: double.infinity,
                    // Màu vàng nhạt giữ nguyên: màu ngữ nghĩa "cần chú ý"
                    color: Colors.amber.withValues(alpha: .2),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        const Text(
                          'Người này chưa có trong danh sách của bạn. Trả lời hoặc chấp nhận để trò chuyện.',
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => svc.accept(chat),
                              child: const Text('Chấp nhận'),
                            ),
                            TextButton(
                              onPressed: () => svc.setBlocked(chat, true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.danger,
                              ),
                              child: const Text('Chặn'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (chat.disappearAfterSec > 0)
                _centered(
                  Container(
                    width: double.infinity,
                    color: AppColors.soft,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '⏱ Tin nhắn tự hủy sau ${disappearLabel(chat.disappearAfterSec)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              Expanded(child: _messages(chat)),
              if (_suggest.isNotEmpty)
                _centered(
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        for (final s in _suggest)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(color: AppColors.border),
                              label: Text(s),
                              onPressed: () => setState(() {
                                _ctrl.text = s;
                                _suggest = [];
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              _centered(blocked ? _blockedBar(chat, me) : _composer(chat)),
            ],
          ),
        );
      },
    );
  }

  Widget _blockedBar(Chat chat, String me) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: chat.blockedBy.contains(me)
          ? Row(
              children: [
                const Expanded(child: Text('Bạn đã chặn người này.')),
                TextButton(
                  onPressed: () => svc.setBlocked(chat, false),
                  child: const Text('Bỏ chặn'),
                ),
              ],
            )
          : const Text(
              'Bạn không thể nhắn tin cho người này.',
              textAlign: TextAlign.center,
            ),
    ),
  );

  // Màn chào khi cuộc trò chuyện còn trống
  Widget _emptyState(Chat chat) {
    final greeting = chat.isGroup ? 'Chào mọi người 👋' : 'Chào bạn 👋';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatAvatar(chat, radius: 44),
            const SizedBox(height: 14),
            ChatTitle(
              chat,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hãy gửi lời chào đầu tiên',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ActionChip(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              avatar: const Text('👋'),
              label: Text(greeting),
              onPressed: () =>
                  svc.sendText(chat, greeting).catchError((x) => _err('$x')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messages(Chat chat) {
    final me = svc.me;
    return StreamBuilder<List<ChatMessage>>(
      stream: _msgStream,
      builder: (context, ms) {
        final all = ms.data ?? const <ChatMessage>[];
        final now = DateTime.now();
        final msgs = all
            .where((m) => m.expireAt == null || m.expireAt!.isAfter(now))
            .toList();
        _cur = msgs;
        _canLoadMore = all.length >= _limit;

        if (chat.unreadFor(me) > 0 && !_marking) {
          _marking = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await svc.markRead(chat);
            _marking = false;
          });
        }
        if (ms.connectionState == ConnectionState.waiting && !ms.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (msgs.isEmpty) return _emptyState(chat);

        final myLast = msgs.indexWhere(
          (m) => m.senderId == me && !m.pending && m.type != 'system',
        );
        return LayoutBuilder(
          builder: (context, box) => ListView.builder(
            reverse: true,
            controller: _scroll,
            // Canh giữa cột tối đa 900 bằng padding (ListView vẫn full bề ngang)
            padding: weaveCenteredPadding(
              box.maxWidth,
              maxWidth: _maxContentWidth,
              h: 0,
              top: 8,
              bottom: 8,
            ),
            itemCount: msgs.length,
            itemBuilder: (c, i) {
              final m = msgs[i];
              final older = i + 1 < msgs.length ? msgs[i + 1] : null;
              final newDay =
                  older == null || !sameDay(older.createdAt, m.createdAt);
              final dayChip = newDay
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            dayLabel(m.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null;

              if (m.type == 'system') {
                return Column(
                  children: [
                    ?dayChip,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 20,
                      ),
                      child: Text(
                        m.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final mine = m.senderId == me;
              final showName =
                  chat.isGroup &&
                  !mine &&
                  (older == null || older.senderId != m.senderId || newDay);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?dayChip,
                  MessageBubble(
                    msg: m,
                    mine: mine,
                    me: me,
                    showName: showName,
                    onLongPress: () => _showActions(m),
                    onReply: () => setState(() {
                      if (!m.deleted) {
                        _reply = m;
                        _editing = null;
                      }
                    }),
                    onReact: (e) =>
                        svc.react(chat.id, m, e).catchError((x) => _err('$x')),
                    onOpenPost: m.postId == null
                        ? null
                        : () => ChatConfig.openPost?.call(context, m.postId!),
                  ),
                  if (i == myLast)
                    Padding(
                      padding: const EdgeInsets.only(right: 16, top: 1),
                      child: Text(
                        _seenText(chat, m) ?? '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _composer(Chat chat) {
    final bar = _editing != null || _reply != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canSend = _ctrl.text.trim().isNotEmpty;
    final wide = MediaQuery.of(context).size.width >= 900;

    final field = TextField(
      controller: _ctrl,
      minLines: 1,
      maxLines: 5,
      maxLength: 4000,
      buildCounter: (
        _, {
        required currentLength,
        required isFocused,
        maxLength,
      }) => null,
      onChanged: (_) {
        if (ChatConfig.enableTyping) svc.typing(chat.id);
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'Nhắn tin…',
        isDense: true,
        filled: true,
        fillColor: dark ? Colors.grey.shade800 : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    );

    // Composer nằm cố định cuối cột. SafeArea tránh thanh home của điện thoại;
    // bàn phím được Scaffold xử lý (resizeToAvoidBottomInset).
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bar)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              decoration: BoxDecoration(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                  left: BorderSide(color: AppColors.brand, width: 3),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(
                children: [
                  Icon(
                    _editing != null ? Icons.edit : Icons.reply,
                    size: 16,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _editing != null
                          ? 'Đang sửa tin nhắn'
                          : 'Trả lời: ${_reply!.type == 'image' ? '📷 Ảnh' : (_reply!.type == 'post' ? '🔗 ${_reply!.postTitle ?? ''}' : _reply!.text)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      if (_editing != null) _ctrl.clear();
                      _editing = null;
                      _reply = null;
                    }),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Gửi ảnh',
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                if (ChatConfig.aiComplete != null)
                  IconButton(
                    tooltip: 'Gợi ý trả lời bằng AI',
                    onPressed: _aiBusy ? null : _suggestReplies,
                    icon: _aiBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                  ),
                // Máy tính: Enter để gửi, Shift+Enter để xuống dòng
                Expanded(
                  child: wide
                      ? CallbackShortcuts(
                          bindings: {
                            const SingleActivator(
                              LogicalKeyboardKey.enter,
                            ): () =>
                                _submit(),
                          },
                          child: field,
                        )
                      : field,
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Material(
                    color: canSend
                        ? AppColors.brand
                        : AppColors.textSecondary.withValues(alpha: .4),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: canSend ? _submit : null,
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Icon(
                          _editing != null
                              ? Icons.check_rounded
                              : Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
