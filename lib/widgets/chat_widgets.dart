import '../theme/app_theme.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

String hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String dayLabel(DateTime t) {
  final now = DateTime.now();
  if (sameDay(t, now)) return 'Hôm nay';
  if (sameDay(t, now.subtract(const Duration(days: 1)))) return 'Hôm qua';
  return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
}

String listTime(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  if (sameDay(t, now)) return hm(t);
  if (sameDay(t, now.subtract(const Duration(days: 1)))) return 'Hôm qua';
  return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';
}

String disappearLabel(int sec) {
  if (sec == 0) return 'Tắt';
  if (sec < 3600) return '${sec ~/ 60} phút';
  if (sec < 86400) return '${sec ~/ 3600} giờ';
  return '${sec ~/ 86400} ngày';
}

// ───────────── Avatar ─────────────
Widget avatarFrom(String? av, String name, double r) {
  ImageProvider? img;
  if (av != null && av.isNotEmpty) {
    if (av.startsWith('http')) {
      img = NetworkImage(av);
    } else {
      try {
        img = MemoryImage(base64Decode(av.contains(',') ? av.split(',').last : av));
      } catch (_) {}
    }
  }
  return CircleAvatar(
    radius: r,
    backgroundColor: AppColors.soft,
    foregroundColor: AppColors.brand,
    backgroundImage: img,
    child: img == null
        ? Text(name.isEmpty ? '?' : name.characters.first.toUpperCase())
        : null,
  );
}

class UserAvatar extends StatelessWidget {
  final String uid;
  final double radius;
  const UserAvatar(this.uid, {super.key, this.radius = 22});
  @override
  Widget build(BuildContext context) => FutureBuilder<ChatUser>(
    future: ChatService.I.user(uid),
    initialData: ChatService.I.cached(uid),
    builder: (c, s) => avatarFrom(s.data?.avatar, s.data?.name ?? '?', radius),
  );
}

class ChatAvatar extends StatelessWidget {
  final Chat chat;
  final double radius;
  const ChatAvatar(this.chat, {super.key, this.radius = 24});
  @override
  Widget build(BuildContext context) => chat.isGroup
      ? CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.soft,
    foregroundColor: AppColors.brand,
    child: const Icon(Icons.groups),
  )
      : UserAvatar(chat.otherId(ChatService.I.me), radius: radius);
}

class ChatTitle extends StatelessWidget {
  final Chat chat;
  final TextStyle? style;
  const ChatTitle(this.chat, {super.key, this.style});
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: ChatService.I.chatName(chat),
    initialData: chat.isGroup
        ? (chat.name.isEmpty ? 'Nhóm chat' : chat.name)
        : ChatService.I.cached(chat.otherId(ChatService.I.me))?.name,
    builder: (c, s) => Text(s.data ?? '…',
        maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
  );
}

// ───────────── Bong bóng tin nhắn ─────────────
class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool mine, showName;
  final VoidCallback onLongPress, onReply;
  final void Function(String emoji) onReact;
  final VoidCallback? onOpenPost;
  final String me;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.mine,
    required this.showName,
    required this.me,
    required this.onLongPress,
    required this.onReply,
    required this.onReact,
    this.onOpenPost,
  });

  static final Map<String, Uint8List> _img = {};

  /// Chiều rộng tối đa của bong bóng: 75% chiều rộng, trong khoảng 200–460.
  static double _maxBubbleWidth(BuildContext context) =>
      (MediaQuery.of(context).size.width * 0.75).clamp(200.0, 460.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Tin của mình: Brand Indigo, chữ trắng. Tin của người khác: nền Surface + viền mảnh.
    final bg = mine ? AppColors.brand : (dark ? Colors.grey.shade800 : AppColors.surface);
    final fg = mine ? Colors.white : (dark ? Colors.white : AppColors.textPrimary);
    final sub = mine ? Colors.white.withValues(alpha: .75) : AppColors.textSecondary;
    final maxW = _maxBubbleWidth(context);
    final grouped = <String, int>{};
    msg.reactions.forEach((_, e) => grouped[e] = (grouped[e] ?? 0) + 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          onHorizontalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0).abs() > 500) onReply();
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Column(
              crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 18),
                    ),
                    // Viền mảnh thay cho bóng đổ (card/bong bóng phẳng theo design system)
                    border: mine ? null : Border.all(color: AppColors.border),
                  ),
                  child: _content(context, fg, sub),
                ),
                if (grouped.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Wrap(spacing: 4, children: [
                      for (final e in grouped.entries)
                        InkWell(
                          onTap: () => onReact(e.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: msg.reactions[me] == e.key
                                  ? AppColors.soft
                                  : (dark ? AppColors.textSecondary : AppColors.surface),
                              border: Border.all(
                                color: msg.reactions[me] == e.key
                                    ? AppColors.brand
                                    : AppColors.border,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(e.value > 1 ? '${e.key} ${e.value}' : e.key,
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Color fg, Color sub) {
    if (msg.deleted) {
      return Text('Tin nhắn đã thu hồi',
          style: TextStyle(fontStyle: FontStyle.italic, color: sub));
    }
    final kids = <Widget>[];
    if (showName) {
      kids.add(FutureBuilder<ChatUser>(
        future: ChatService.I.user(msg.senderId),
        initialData: ChatService.I.cached(msg.senderId),
        builder: (c, s) => Text(s.data?.name ?? '',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brand)),
      ));
    }
    if (msg.replyTo != null) {
      kids.add(Container(
        margin: const EdgeInsets.only(bottom: 4, top: 2),
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
            border: Border(
                left: BorderSide(color: mine ? Colors.white : AppColors.brand, width: 3))),
        child: Text((msg.replyTo!['text'] ?? '').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: sub)),
      ));
    }
    if (msg.type == 'image' && msg.imageB64 != null) {
      final bytes = _img.putIfAbsent(msg.id, () => base64Decode(msg.imageB64!));
      // Ảnh co theo bong bóng: không vượt chiều rộng tối đa trên màn hình hẹp
      final imgW = (_maxBubbleWidth(context) - 28).clamp(120.0, 240.0).toDouble();
      kids.add(GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(bytes, width: imgW, fit: BoxFit.cover, gaplessPlayback: true),
        ),
      ));
    }
    if (msg.type == 'post') {
      kids.add(InkWell(
        onTap: onOpenPost,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              border: Border.all(color: sub), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.article_outlined, size: 16, color: sub),
              const SizedBox(width: 4),
              Text('Bài viết', style: TextStyle(fontSize: 11, color: sub)),
            ]),
            const SizedBox(height: 4),
            Text(msg.postTitle ?? 'Bài viết',
                style: TextStyle(fontWeight: FontWeight.bold, color: fg)),
            if (msg.text.isNotEmpty)
              Text(msg.text,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg)),
          ]),
        ),
      ));
    }
    if (msg.type == 'text' && msg.text.isNotEmpty) {
      kids.add(SelectableText(msg.text, style: TextStyle(color: fg, fontSize: 15, height: 1.3)));
    }
    kids.add(Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (msg.expireAt != null)
          Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(Icons.timer_outlined, size: 11, color: sub)),
        Text(hm(msg.createdAt) + (msg.editedAt != null ? ' · đã sửa' : ''),
            style: TextStyle(fontSize: 10, color: sub)),
        if (msg.pending)
          Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Icon(Icons.schedule, size: 11, color: sub)),
      ]),
    ));
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: kids);
  }
}

// ───────────── Chấm đỏ tổng cho menu ─────────────
class ChatUnreadBadge extends StatelessWidget {
  final Widget child;
  const ChatUnreadBadge({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) return child;
    return StreamBuilder<int>(
      stream: ChatService.I.totalUnread(),
      builder: (c, s) {
        final n = s.data ?? 0;
        return Badge(
          isLabelVisible: n > 0,
          label: Text(n > 99 ? '99+' : '$n'),
          child: child,
        );
      },
    );
  }
}

// ───────────── Chia sẻ bài viết vào chat ─────────────
Future<void> showShareToChatSheet(BuildContext context,
    {required String postId, required String title, String snippet = ''}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(WeaveRadius.card)),
    ),
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(children: [
          const ListTile(
              title: Text('Gửi bài viết tới…', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: StreamBuilder<List<Chat>>(
              stream: ChatService.I.myChats(),
              builder: (c, s) {
                final list = (s.data ?? []).where((x) => x.hasMessages || x.isGroup).toList();
                if (list.isEmpty) {
                  return const Center(child: Text('Chưa có cuộc trò chuyện nào'));
                }
                return ListView(children: [
                  for (final chat in list)
                    ListTile(
                      leading: ChatAvatar(chat),
                      title: ChatTitle(chat),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        try {
                          await ChatService.I.sendPost(chat, postId, title, snippet);
                          messenger.showSnackBar(const SnackBar(content: Text('Đã gửi bài viết')));
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('Không gửi được: $e')));
                        }
                      },
                    ),
                ]);
              },
            ),
          ),
        ]),
      ),
    ),
  );
}