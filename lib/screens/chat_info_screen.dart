import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/weave_error_view.dart';
import '../widgets/weave_state_views.dart';
import 'new_chat_screen.dart';

class ChatInfoScreen extends StatefulWidget {
  final String chatId;
  const ChatInfoScreen({super.key, required this.chatId});

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  /// Trên màn rộng (hoặc trong khung phải của desktop), nội dung được canh giữa
  /// và giới hạn bề ngang này.
  static const double _maxContentWidth = 640;

  // Tạo stream một lần (không tạo lại mỗi lần build). Nút Thử lại gán stream mới.
  late Stream<Chat?> _stream = ChatService.I.chat(widget.chatId);

  Future<String?> _ask(BuildContext context, String title, String initial) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  /// Hộp xác nhận cho hành động nguy hiểm: nút xác nhận màu đỏ Danger.
  Future<bool> _confirmDanger(
      BuildContext context, {
        required String title,
        String? content,
        required String action,
      }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: content == null ? null : Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _snack(BuildContext c, String m) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final svc = ChatService.I;
    final me = svc.me;
    return StreamBuilder<Chat?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('ChatInfo: load failed: ${snap.error}');
          return Scaffold(
            appBar: AppBar(),
            body: WeaveErrorView(
              message: tr(
                'Không tải được thông tin cuộc trò chuyện.',
                'Could not load the chat info.',
              ),
              onRetry: () =>
                  setState(() => _stream = ChatService.I.chat(widget.chatId)),
            ),
          );
        }
        final chat = snap.data;
        if (chat == null) {
          final waiting = snap.connectionState == ConnectionState.waiting;
          return Scaffold(
            appBar: AppBar(),
            body: waiting
                ? const WeaveLoadingView()
                : WeaveEmptyView(
              icon: Icons.chat_bubble_outline,
              title: tr(
                'Cuộc trò chuyện không còn tồn tại',
                'This chat no longer exists',
              ),
            ),
          );
        }
        final isAdmin = chat.admins.contains(me);
        final canDisappear = !chat.isGroup || isAdmin;

        return Scaffold(
          appBar: AppBar(title: const Text('Thông tin trò chuyện')),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: ListView(
                children: [
                  const SizedBox(height: 16),
                  Center(child: ChatAvatar(chat, radius: 40)),
                  const SizedBox(height: 8),
                  Center(
                    child: ChatTitle(
                      chat,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (chat.isGroup && isAdmin)
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Đổi tên nhóm'),
                      onTap: () async {
                        final n = await _ask(context, 'Tên nhóm', chat.name);
                        if (n != null && n.isNotEmpty) {
                          try {
                            await svc.rename(chat, n);
                          } catch (e) {
                            if (context.mounted) _snack(context, '$e');
                          }
                        }
                      },
                    ),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_off_outlined),
                    title: const Text('Tắt thông báo'),
                    subtitle: const Text('Không tính vào chấm đỏ'),
                    value: chat.mutedBy.contains(me),
                    onChanged: (v) => svc.setMuted(chat, v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.push_pin_outlined),
                    title: const Text('Ghim lên đầu danh sách'),
                    value: chat.pinnedBy.contains(me),
                    onChanged: (v) => svc.setPinned(chat, v),
                  ),
                  ListTile(
                    enabled: canDisappear,
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Tin nhắn tự hủy'),
                    subtitle: Text(
                      canDisappear
                          ? disappearLabel(chat.disappearAfterSec)
                          : '${disappearLabel(chat.disappearAfterSec)} (chỉ quản trị viên đổi được)',
                    ),
                    onTap: !canDisappear
                        ? null
                        : () async {
                      final v = await showDialog<int>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: const Text('Tự hủy sau'),
                          children: [
                            for (final e in {
                              'Tắt': 0,
                              '1 giờ': 3600,
                              '24 giờ': 86400,
                              '7 ngày': 604800,
                            }.entries)
                              SimpleDialogOption(
                                onPressed: () =>
                                    Navigator.pop(ctx, e.value),
                                child: Text(e.key),
                              ),
                          ],
                        ),
                      );
                      if (v != null && v != chat.disappearAfterSec) {
                        try {
                          await svc.setDisappear(chat, v);
                        } catch (e) {
                          if (context.mounted) _snack(context, '$e');
                        }
                      }
                    },
                  ),
                  if (!chat.isGroup)
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.block,
                        color: AppColors.danger,
                      ),
                      title: const Text('Chặn người này'),
                      value: chat.blockedBy.contains(me),
                      onChanged: (v) async {
                        // Bật chặn là hành động nguy hiểm: hỏi xác nhận. Bỏ chặn thì làm ngay.
                        if (v) {
                          final ok = await _confirmDanger(
                            context,
                            title: 'Chặn người này?',
                            content:
                            'Hai bạn sẽ không nhắn tin được cho nhau cho đến khi bạn bỏ chặn.',
                            action: 'Chặn',
                          );
                          if (!ok) return;
                        }
                        try {
                          await svc.setBlocked(chat, v);
                        } catch (e) {
                          if (context.mounted) _snack(context, '$e');
                        }
                      },
                    ),
                  if (chat.isGroup) ...[
                    const Divider(),
                    ListTile(
                      title: Text(
                        'Thành viên (${chat.members.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isAdmin)
                      ListTile(
                        leading: const Icon(Icons.person_add),
                        title: const Text('Thêm thành viên'),
                        onTap: () async {
                          final r = await Navigator.of(context)
                              .push<List<String>>(
                            MaterialPageRoute(
                              builder: (_) => NewChatScreen(
                                pickOnly: true,
                                exclude: chat.members,
                              ),
                            ),
                          );
                          if (r != null && r.isNotEmpty) {
                            try {
                              await svc.addMembers(chat, r);
                            } catch (e) {
                              if (context.mounted) _snack(context, '$e');
                            }
                          }
                        },
                      ),
                    for (final u in chat.members)
                      ListTile(
                        leading: UserAvatar(u, radius: 18),
                        title: FutureBuilder<ChatUser>(
                          future: svc.user(u),
                          initialData: svc.cached(u),
                          builder: (c, s) => Text(
                            (s.data?.name ?? '…') + (u == me ? ' (bạn)' : ''),
                          ),
                        ),
                        trailing: chat.admins.contains(u)
                            ? const Text(
                          'Quản trị',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        )
                            : null,
                      ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.exit_to_app,
                        color: AppColors.danger,
                      ),
                      title: const Text(
                        'Rời nhóm',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      onTap: () async {
                        final ok = await _confirmDanger(
                          context,
                          title: 'Rời nhóm?',
                          action: 'Rời',
                        );
                        if (ok) {
                          try {
                            await svc.leave(chat);
                            if (context.mounted) {
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            }
                          } catch (e) {
                            if (context.mounted) _snack(context, '$e');
                          }
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}