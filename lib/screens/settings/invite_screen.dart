import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/friend_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/friend_button.dart';
import '../../widgets/settings_widgets.dart';
import '../../widgets/suggested_people.dart';
import 'favorites_screen.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  late final Stream<List<Friendship>> _stream = FriendService.watchMine();

  String get _inviteText => tr(
    'Mình đang dùng Weave để chia sẻ và trò chuyện theo chủ đề. Tham gia cùng mình nhé: https://social-app-353f0.web.app',
    'I am using Weave to share and chat by topic. Join me: https://social-app-353f0.web.app',
  );

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _inviteText));
    messenger.showSnackBar(
      SnackBar(content: Text(tr('Đã sao chép lời mời', 'Invitation copied'))),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid ?? '';

    return SettingsScaffold(
      title: tr('Theo dõi và mời bạn bè', 'Follow and invite friends'),
      body: StreamBuilder<List<Friendship>>(
        stream: _stream,
        builder: (context, snap) {
          final all = snap.data ?? const <Friendship>[];
          final incoming = all
              .where((f) => !f.accepted && f.requesterId != me)
              .toList();
          final outgoing = all
              .where((f) => !f.accepted && f.requesterId == me)
              .toList();
          final friends = all.where((f) => f.accepted).length;

          return settingsList([
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      _stat('$friends', tr('Bạn bè', 'Friends')),
                      _stat(
                        '${incoming.length}',
                        tr('Lời mời nhận', 'Requests'),
                      ),
                      _stat('${outgoing.length}', tr('Đã gửi', 'Sent')),
                    ],
                  ),
                ),
              ],
            ),
            SectionLabel(tr('Mời bạn bè dùng ứng dụng', 'Invite friends')),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_inviteText, style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(tr('Sao chép lời mời', 'Copy invitation')),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        'Liên kết sẽ mở được khi bản web đã được triển khai lên Firebase Hosting.',
                        'The link will work once the web app is deployed to Firebase Hosting.',
                      ),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (incoming.isNotEmpty) ...[
              SectionLabel(tr('Lời mời kết bạn', 'Friend requests')),
              SettingsCard(
                children: [
                  for (final f in incoming)
                    PersonTile(
                      key: ValueKey('inv_${f.otherUid(me)}'),
                      uid: f.otherUid(me),
                      trailing: FriendActionButton(
                        uid: f.otherUid(me),
                        friendships: all,
                        compact: true,
                      ),
                    ),
                ],
              ),
            ],
            SuggestedPeople(
              key: const ValueKey('invite_suggested'),
              friendships: all,
            ),
            SectionLabel(tr('Theo dõi', 'Following')),
            SettingsCard(
              children: [
                SettingsTile(
                  icon: Icons.star_border,
                  title: tr('Người yêu thích', 'Favorite people'),
                  subtitle: tr(
                    'Ưu tiên xem bài của những người bạn quan tâm',
                    'Prioritize posts from people you care about',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  ),
                ),
              ],
            ),
          ]);
        },
      ),
    );
  }
}
