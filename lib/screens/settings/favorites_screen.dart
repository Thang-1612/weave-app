import 'package:flutter/material.dart';
import '../../models/space.dart';
import '../../models/user_profile.dart';
import '../../services/l10n.dart';
import '../../services/thread_service.dart';
import '../../services/user_prefs.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_widgets.dart';
import '../user_profile_page.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<UserProfile> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final list = await ThreadService.loadFriends();
      if (mounted) setState(() => _friends = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Yêu thích', 'Favorites'),
      body: ListenableBuilder(
        listenable: UserPrefs.instance,
        builder: (context, _) {
          final prefs = UserPrefs.instance;
          final favUsers = prefs.favoriteUsers.toList();
          final candidates = _friends
              .where((f) => !prefs.isFavoriteUser(f.uid))
              .toList();

          return settingsList([
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                tr(
                  'Bài của người yêu thích hiện trong mục ⭐ Yêu thích ở menu. Chủ đề yêu thích được ghim lên đầu danh sách chủ đề.',
                  'Posts from favorite people appear under ⭐ Favorites in the menu. Favorite topics are pinned to the top of the topic list.',
                ),
                style: const TextStyle(color: Colors.grey, height: 1.4),
              ),
            ),
            SectionLabel(tr('Chủ đề yêu thích', 'Favorite topics')),
            SettingsCard(
              children: [
                for (final s in defaultSpaces)
                  SettingsTile.toggle(
                    icon: Icons.star_border,
                    title: '${s.emoji} ${spaceName(s.id, s.name)}',
                    value: prefs.favoriteSpaces.contains(s.id),
                    onChanged: (v) => prefs.setFavoriteSpace(s.id, v),
                  ),
              ],
            ),
            SectionLabel(tr('Người yêu thích', 'Favorite people')),
            if (favUsers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  tr(
                    'Chưa có ai. Thêm từ danh sách bạn bè bên dưới, hoặc từ menu ba chấm trên bài viết.',
                    'Nobody yet. Add from your friends below, or from the ⋯ menu on a post.',
                  ),
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            else
              SettingsCard(
                children: [
                  for (final uid in favUsers)
                    PersonTile(
                      key: ValueKey('fav_$uid'),
                      uid: uid,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              UserProfilePage(userId: uid, title: ''),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: tr('Bỏ yêu thích', 'Remove'),
                        icon: const Icon(Icons.star, color: AppColors.brand),
                        onPressed: () => prefs.setFavoriteUser(uid, false),
                      ),
                    ),
                ],
              ),
            if (candidates.isNotEmpty) ...[
              SectionLabel(tr('Thêm từ bạn bè', 'Add from friends')),
              SettingsCard(
                children: [
                  for (final f in candidates)
                    PersonTile(
                      key: ValueKey('cand_${f.uid}'),
                      uid: f.uid,
                      trailing: IconButton(
                        tooltip: tr('Yêu thích', 'Favorite'),
                        icon: const Icon(Icons.star_border),
                        onPressed: () => prefs.setFavoriteUser(f.uid, true),
                      ),
                    ),
                ],
              ),
            ],
          ]);
        },
      ),
    );
  }
}