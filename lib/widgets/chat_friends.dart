import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../screens/chat_room_screen.dart';
import '../services/chat_service.dart';
import 'chat_widgets.dart';

/// Dải bạn bè nằm ngang; bấm vào để mở (hoặc tạo) chat 1-1.
/// Có [onOpen] (máy tính) thì gọi lại với chatId thay vì mở màn hình mới.
class FriendsStrip extends StatelessWidget {
  final void Function(String chatId)? onOpen;
  const FriendsStrip({super.key, this.onOpen});

  Future<void> _tap(BuildContext context, String uid) async {
    final cb = onOpen;
    if (cb == null) return openChatWith(context, uid);
    final messenger = ScaffoldMessenger.of(context);
    try {
      cb(await ChatService.I.ensureDirect(uid));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Không mở được chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: ChatService.I.friendIds(),
      builder: (context, s) {
        final ids = s.data ?? const <String>[];
        if (ids.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Bạn bè',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: ids.length,
                itemBuilder: (c, i) {
                  final uid = ids[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _tap(context, uid),
                    child: SizedBox(
                      width: 76,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          UserAvatar(uid, radius: 28),
                          const SizedBox(height: 6),
                          FutureBuilder<ChatUser>(
                            future: ChatService.I.user(uid),
                            initialData: ChatService.I.cached(uid),
                            builder: (c, u) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                u.data?.name ?? '…',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}