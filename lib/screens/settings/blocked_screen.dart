import 'package:flutter/material.dart';

import '../../services/account_service.dart';
import '../../services/l10n.dart';
import '../../services/user_prefs.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_widgets.dart';

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  static final _smallButton = OutlinedButton.styleFrom(
    minimumSize: const Size(64, 36),
  );

  Widget _note(String text) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(WeaveRadius.card),
      ),
      child: Text(text, style: const TextStyle(height: 1.4)),
    );
  }

  /// Danh sách một cột, giới hạn bề rộng trên màn rộng.
  Widget _tab(List<Widget> children) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Đã chặn và tắt tiếng', 'Blocked and muted')),
          bottom: TabBar(
            indicatorColor: AppColors.brand,
            labelColor: AppColors.brand,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: tr('Đã chặn', 'Blocked')),
              Tab(text: tr('Đã tắt tiếng', 'Muted')),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: UserPrefs.instance,
          builder: (context, _) {
            final prefs = UserPrefs.instance;
            final blocked = prefs.blocked.entries.toList();
            final muted = prefs.mutedUsers.toList();

            return TabBarView(
              children: [
                _tab([
                  _note(
                    tr(
                      'Bạn sẽ không thấy bài viết và bình luận của người bị chặn, và hai bạn không còn là bạn bè. Việc chặn hiện hoạt động ở phía bạn.',
                      'You will not see posts and comments from blocked people, and you stop being friends. Blocking currently works on your side.',
                    ),
                  ),
                  if (blocked.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          tr('Bạn chưa chặn ai', 'You have not blocked anyone'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  for (final e in blocked)
                    ListTile(
                      key: ValueKey('blk_${e.key}'),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.soft,
                        child: Text(
                          initialOf(e.value.isEmpty ? '?' : e.value),
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        e.value.isEmpty ? tr('Người dùng', 'User') : e.value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: OutlinedButton(
                        style: _smallButton,
                        onPressed: () => prefs.unblock(e.key),
                        child: Text(tr('Bỏ chặn', 'Unblock')),
                      ),
                    ),
                ]),
                _tab([
                  _note(
                    tr(
                      'Người bị tắt tiếng vẫn là bạn bè của bạn, chỉ là bài viết của họ không hiện trong bảng tin.',
                      'Muted people stay your friends; their posts just stop appearing in your feed.',
                    ),
                  ),
                  if (muted.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          tr(
                            'Bạn chưa tắt tiếng ai',
                            'You have not muted anyone',
                          ),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  for (final uid in muted)
                    PersonTile(
                      key: ValueKey('mut_$uid'),
                      uid: uid,
                      trailing: OutlinedButton(
                        style: _smallButton,
                        onPressed: () => prefs.setMuted(uid, false),
                        child: Text(tr('Bỏ tắt tiếng', 'Unmute')),
                      ),
                    ),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}
