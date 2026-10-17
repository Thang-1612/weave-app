import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../widgets/chat_widgets.dart';
import 'new_chat_screen.dart';

class ChatInfoScreen extends StatelessWidget {
  final String chatId;
  const ChatInfoScreen({super.key, required this.chatId});

  Future<String?> _ask(BuildContext context, String title, String initial) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
  }

  void _snack(BuildContext c, String m) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final svc = ChatService.I;
    final me = svc.me;
    return StreamBuilder<Chat?>(
      stream: svc.chat(chatId),
      builder: (context, snap) {
        final chat = snap.data;
        if (chat == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final isAdmin = chat.admins.contains(me);
        final canDisappear = !chat.isGroup || isAdmin;

        return Scaffold(
          appBar: AppBar(title: const Text('Thông tin trò chuyện')),
          body: ListView(children: [
            const SizedBox(height: 16),
            Center(child: ChatAvatar(chat, radius: 40)),
            const SizedBox(height: 8),
            Center(child: ChatTitle(chat, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
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
              subtitle: Text(canDisappear
                  ? disappearLabel(chat.disappearAfterSec)
                  : '${disappearLabel(chat.disappearAfterSec)} (chỉ quản trị viên đổi được)'),
              onTap: !canDisappear
                  ? null
                  : () async {
                final v = await showDialog<int>(
                  context: context,
                  builder: (ctx) => SimpleDialog(title: const Text('Tự hủy sau'), children: [
                    for (final e in {'Tắt': 0, '1 giờ': 3600, '24 giờ': 86400, '7 ngày': 604800}.entries)
                      SimpleDialogOption(onPressed: () => Navigator.pop(ctx, e.value), child: Text(e.key)),
                  ]),
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
                secondary: const Icon(Icons.block, color: Colors.red),
                title: const Text('Chặn người này'),
                value: chat.blockedBy.contains(me),
                onChanged: (v) => svc.setBlocked(chat, v),
              ),
            if (chat.isGroup) ...[
              const Divider(),
              ListTile(title: Text('Thành viên (${chat.members.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Thêm thành viên'),
                  onTap: () async {
                    final r = await Navigator.of(context).push<List<String>>(MaterialPageRoute(
                        builder: (_) => NewChatScreen(pickOnly: true, exclude: chat.members)));
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
                    builder: (c, s) => Text((s.data?.name ?? '…') + (u == me ? ' (bạn)' : '')),
                  ),
                  trailing: chat.admins.contains(u)
                      ? const Text('Quản trị', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                      : null,
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text('Rời nhóm', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Rời nhóm?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rời')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    try {
                      await svc.leave(chat);
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    } catch (e) {
                      if (context.mounted) _snack(context, '$e');
                    }
                  }
                },
              ),
            ],
          ]),
        );
      },
    );
  }
}