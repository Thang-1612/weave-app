import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
import '../services/account_service.dart';
import '../services/friend_service.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/friend_button.dart';
import '../widgets/post_card.dart';
import 'edit_profile_screen.dart';

/// Từ chiều rộng này trở lên, hồ sơ chia hai cột: giới thiệu bên trái,
/// bài viết bên phải. Dưới mức này: một cột như cũ.
const double _kProfileTwoColumnBreakpoint = 800;

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: WeaveSpacing.xs),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  /// null = tài khoản đang đăng nhập
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final String _uid =
      widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  late final Stream<UserProfile?> _profileStream =
  UserService.watchProfile(_uid);
  late final Stream<List<Post>> _postsStream = PostService.watchUserPosts(_uid);
  late final Stream<List<Friendship>> _friendsStream =
  FriendService.watchMine();

  StreamSubscription<User?>? _sub;
  String? _synced;

  bool get _isMe => _uid == FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (_isMe) {
      // Tạo/bổ sung hồ sơ khi đăng nhập, và khi tên tài khoản thay đổi
      _sub = FirebaseAuth.instance.userChanges().listen((u) {
        if (u == null) return;
        final key = '${u.uid}|${u.displayName}';
        if (key == _synced) return;
        _synced = key;
        UserService.ensureProfile(u).catchError((_) {});
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Bài ghim lên đầu (ghim sau hiện trước), còn lại giữ thứ tự mới nhất trước.
  List<Post> _ordered(List<Post> posts) {
    final pinned = posts.where((p) => p.isPinned).toList()
      ..sort((a, b) => b.pinnedAt!.compareTo(a.pinnedAt!));
    final rest = posts.where((p) => !p.isPinned);
    return [...pinned, ...rest];
  }

  // ---------------------------------------------------------------------
  // Phần giới thiệu: avatar, tên, email, bio, số liệu và nút hành động.
  // Dùng chung cho cả hai bố cục.
  // ---------------------------------------------------------------------
  Widget _buildIntro(
      BuildContext context, {
        required UserProfile? profile,
        required String title,
        required String name,
        required String email,
        required String bio,
        required int postCount,
        required int interactions,
      }) {
    return Column(
      children: [
        // Avatar gradient là điểm nhấn của trang hồ sơ.
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.gradient,
          ),
          child: Text(
            initialOf(title),
            style: const TextStyle(
              fontSize: 40,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: WeaveSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (name.isNotEmpty && email.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: WeaveSpacing.xs),
            child: Text(
              email,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WeaveSpacing.lg,
              WeaveSpacing.md,
              WeaveSpacing.lg,
              0,
            ),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.4, color: AppColors.textPrimary),
            ),
          ),
        const SizedBox(height: WeaveSpacing.xl),
        StreamBuilder<List<Friendship>>(
          stream: _friendsStream,
          builder: (context, friendsSnap) {
            final friendships = friendsSnap.data ?? const <Friendship>[];
            final friendCount = friendships.where((f) => f.accepted).length;

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat('$postCount', tr('Bài viết', 'Posts')),
                    // Số bạn bè của người khác được giữ riêng tư
                    _Stat(
                      _isMe ? '$friendCount' : '—',
                      tr('Bạn bè', 'Friends'),
                    ),
                    _Stat(
                      '$interactions',
                      tr('Tương tác', 'Interactions'),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    WeaveSpacing.lg,
                    WeaveSpacing.lg,
                    WeaveSpacing.lg,
                    0,
                  ),
                  child: _isMe
                      ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(
                              profile: profile,
                              fallbackName: name,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        tr('Chỉnh sửa hồ sơ', 'Edit profile'),
                      ),
                    ),
                  )
                      : FriendActionButton(
                    uid: _uid,
                    friendships: friendships,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Nội dung phần bài viết (trạng thái tải / lỗi / rỗng / danh sách).
  List<Widget> _buildPostWidgets(
      AsyncSnapshot<List<Post>> postsSnap,
      List<Post> posts,
      ) {
    if (postsSnap.hasError) {
      return [
        Padding(
          padding: const EdgeInsets.all(WeaveSpacing.xl),
          child: Text(
            '${tr('Không tải được bài viết.', 'Could not load posts.')}\n${postsSnap.error}',
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    if (!postsSnap.hasData) {
      return const [
        Padding(
          padding: EdgeInsets.all(WeaveSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (posts.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(WeaveSpacing.xl),
          child: Center(
            child: Text(
              tr('Chưa có bài viết nào', 'No posts yet'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ];
    }
    return [
      for (final p in _ordered(posts))
        PostCard(
          post: p,
          openProfileOnTap: false,
          showPinnedTag: true,
        ),
    ];
  }

  Widget _postsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WeaveSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.grid_view_rounded,
            size: 20,
            color: AppColors.brand,
          ),
          const SizedBox(width: WeaveSpacing.sm),
          Text(
            tr('Bài viết', 'Posts'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, profileSnap) {
        return StreamBuilder<List<Post>>(
          stream: _postsStream,
          builder: (context, postsSnap) {
            final profile = profileSnap.data;
            final posts = postsSnap.data ?? const <Post>[];
            final authUser = _isMe ? FirebaseAuth.instance.currentUser : null;

            final profileName = profile?.name ?? '';
            final name =
            profileName.isNotEmpty ? profileName : (nameOf(authUser) ?? '');
            final email = authUser?.email ?? '';
            final title = name.isNotEmpty
                ? name
                : (email.isNotEmpty ? email : tr('Người dùng', 'User'));
            final bio = profile?.bio ?? '';
            final interactions =
            posts.fold<int>(0, (sum, p) => sum + p.reactions + p.comments);

            Widget intro() => _buildIntro(
              context,
              profile: profile,
              title: title,
              name: name,
              email: email,
              bio: bio,
              postCount: posts.length,
              interactions: interactions,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns =
                    constraints.maxWidth >= _kProfileTwoColumnBreakpoint;

                if (twoColumns) {
                  // Rộng: giới thiệu (card cố định 320) | bài viết cuộn riêng.
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Padding(
                        padding: const EdgeInsets.all(WeaveSpacing.xl),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 320,
                              child: SingleChildScrollView(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: WeaveSpacing.xl,
                                      horizontal: WeaveSpacing.sm,
                                    ),
                                    child: intro(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: WeaveSpacing.md),
                            Expanded(
                              child: ListView(
                                children: [
                                  ..._buildPostWidgets(postsSnap, posts),
                                  const SizedBox(height: WeaveSpacing.xl),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Hẹp: một cột, thông tin xếp dọc rồi tới bài viết.
                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        children: [
                          const SizedBox(height: WeaveSpacing.xl),
                          intro(),
                          const SizedBox(height: WeaveSpacing.lg),
                          const Divider(height: 1),
                          _postsHeader(),
                          ..._buildPostWidgets(postsSnap, posts),
                          const SizedBox(height: WeaveSpacing.xl),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}