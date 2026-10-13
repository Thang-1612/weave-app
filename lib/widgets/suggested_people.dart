import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../screens/user_profile_page.dart';
import '../services/account_service.dart';
import '../services/friend_service.dart';
import '../services/l10n.dart';
import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import 'friend_button.dart';

/// Gợi ý kết bạn: những người chưa có quan hệ gì với bạn.
class SuggestedPeople extends StatefulWidget {
  final List<Friendship> friendships;

  const SuggestedPeople({super.key, required this.friendships});

  @override
  State<SuggestedPeople> createState() => _SuggestedPeopleState();
}

class _SuggestedPeopleState extends State<SuggestedPeople> {
  late final Future<List<UserProfile>> _future = _load();

  Future<List<UserProfile>> _load() async {
    final snap =
    await FirebaseFirestore.instance.collection('users').limit(40).get();
    return snap.docs
        .map((d) => UserProfile.fromMap(d.id, d.data()))
        .where((p) => p.name.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid ?? '';

    return FutureBuilder<List<UserProfile>>(
      future: _future,
      builder: (context, snap) {
        final people = (snap.data ?? const <UserProfile>[])
            .where((p) => p.uid != me)
            .where(
              (p) => p.discoverable && !UserPrefs.instance.isBlocked(p.uid),
        )
            .where(
              (p) =>
          FriendService.statusWith(widget.friendships, me, p.uid) ==
              FriendStatus.none,
        )
            .take(8)
            .toList();
        if (people.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                tr('GỢI Ý KẾT BẠN', 'SUGGESTED FRIENDS'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
            ),
            for (final p in people)
              InkWell(
                key: ValueKey('sg_${p.uid}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          UserProfilePage(userId: p.uid, title: p.name),
                    ),
                  );
                },
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.soft,
                        child: Text(
                          initialOf(p.name),
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                              const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (p.bio.isNotEmpty)
                              Text(
                                p.bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FriendActionButton(
                        uid: p.uid,
                        friendships: widget.friendships,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}