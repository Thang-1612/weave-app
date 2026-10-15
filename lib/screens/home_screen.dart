import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/space.dart';
import '../services/account_service.dart';
import '../services/interest_service.dart';
import '../services/l10n.dart';
import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/account_switcher.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
import 'friends_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'settings/saved_screen.dart';
import 'settings/settings_hub_screen.dart';
import '../services/usage_service.dart';
import '../services/deep_link.dart';
import '../services/post_service.dart';
import 'comments_screen.dart';
import '../services/friend_post_sync.dart';
import '../widgets/space_menu.dart';
import '../services/trash_service.dart';
import 'settings/trash_screen.dart';
import 'capsules_screen.dart';
import 'thanks_inbox_screen.dart';
import 'recipes_screen.dart';
import 'proposals_screen.dart';
import 'contribution_screen.dart';
import 'chat_list_screen.dart';
import '../widgets/chat_widgets.dart' show ChatUnreadBadge;
import 'my_box_screen.dart';
import 'weave_list_screen.dart';
import 'story_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _page = 0; // 0 trang chủ, 1 bạn bè, 2 thông báo, 3 cá nhân
  Space? _space; // null = tất cả
  bool _favorites = false; // đang xem mục Yêu thích

  @override
  void initState() {
    super.initState();
    // Lưu tài khoản đang dùng để có thể chuyển nhanh sau này
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (email != null) AccountService.add(email, name: user?.displayName);

    UserPrefs.instance.bind(user?.uid);
    UserPrefs.instance.addListener(_onPrefs);
    // Đo thời gian dùng ứng dụng (thống kê, giới hạn, nhắc nghỉ)
    UsageService.instance.start(() => mounted ? context : null);
    // Mở bài viết khi vào từ liên kết dạng /post/<mã> (bản web)
    // Giữ danh sách người xem của bài chỉ-bạn-bè khớp với danh sách bạn bè
    FriendPostSync.start();
    TrashService.purgeExpired(); // dọn bài trong thùng rác quá 30 ngày
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDeepLink());
  }

  @override
  void dispose() {
    UserPrefs.instance.removeListener(_onPrefs);
    UsageService.instance.stop();
    FriendPostSync.stop();
    super.dispose();
  }

  // Cài đặt thay đổi (ngôn ngữ, hạn chế chủ đề...): vẽ lại
  void _onPrefs() {
    if (!mounted) return;
    setState(() {
      final s = _space;
      if (s != null && UserPrefs.instance.isRestricted(s.id)) _space = null;
    });
  }
  /// Mở bài viết khi vào từ liên kết dạng /post/<mã> (bản web).
  Future<void> _openDeepLink() async {
    final id = DeepLink.takePostId();
    if (id == null || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final post = await PostService.getPost(id);
      if (!mounted) return;
      if (post == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              tr('Bài viết không còn tồn tại', 'This post no longer exists'),
            ),
          ),
        );
        return;
      }
      navigator.push(
        MaterialPageRoute(builder: (_) => CommentsScreen(post: post)),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StoryListScreen()),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _openCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreatePostScreen(initialSpaceId: _space?.id),
      ),
    );
  }

  void _openAccountSwitcher() {
    showAccountSwitcher(context, () {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      UserPrefs.instance.bind(user?.uid);
      FriendPostSync.start(); // theo dõi lại cho tài khoản mới
      setState(() {}); // làm mới giao diện theo tài khoản mới
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tr('Đã chuyển sang', 'Switched to')} ${displayNameOf(user)}',
          ),
        ),
      );
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsHubScreen()),
    );
  }

  void _selectAll() {
    setState(() {
      _space = null;
      _favorites = false;
      _page = 0;
    });
    Navigator.of(context).pop(); // đóng menu
  }

  void _selectFavorites() {
    setState(() {
      _space = null;
      _favorites = true;
      _page = 0;
    });
    Navigator.of(context).pop();
  }

  void _selectSpace(Space s) {
    InterestService.track(s.id, 3); // ghi nhận sở thích
    setState(() {
      _space = s;
      _favorites = false;
      _page = 0;
    });
    Navigator.of(context).pop();
  }

  void _pushFromDrawer(Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  String _pageTitle() {
    switch (_page) {
      case 1:
        return tr('Bạn bè', 'Friends');
      case 2:
        return tr('Thông báo', 'Notifications');
      default:
        return tr('Cá nhân', 'Profile');
    }
  }

  PreferredSizeWidget _buildAppBar() {
    if (_page == 0) {
      final String title;
      if (_favorites) {
        title = '⭐ ${tr('Yêu thích', 'Favorites')}';
      } else if (_space == null) {
        title = tr('Tất cả bài đăng', 'All posts');
      } else {
        title = '${_space!.emoji} ${tr(_space!.name, _space!.nameEn ?? _space!.name)}';
      }
      return AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        title: Text(title),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(
            tooltip: tr('Tin nhắn', 'Messages'),
            icon: ChatUnreadBadge(child: const Icon(Icons.chat_bubble_outline)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatListScreen()),
            ),
          ),
        ],
      );
    }
    return AppBar(
      flexibleSpace: const GradientAppBarBackground(),
      title: Text(_pageTitle()),
      automaticallyImplyLeading: false,
      actions: [
        if (_page == 3) ...[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: tr('Cài đặt và hoạt động', 'Settings and activity'),
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.switch_account_outlined),
            tooltip: tr('Chuyển tài khoản', 'Switch account'),
            onPressed: _openAccountSwitcher,
          ),
        ],
      ],
    );
  }

  Widget _buildDrawerHeader() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = nameOf(user);
        final email = user?.email ?? '';

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 24,
            20,
            20,
          ),
          decoration: const BoxDecoration(gradient: AppColors.gradient),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  initialOf(name ?? (email.isEmpty ? '?' : email)),
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name ?? email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (name != null)
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color.fromRGBO(255, 255, 255, 0.85),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    final prefs = UserPrefs.instance;

    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    tr('CHỦ ĐỀ', 'TOPICS'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: Text(tr('Tất cả', 'All')),
                  selected: _space == null && !_favorites,
                  onTap: _selectAll,
                ),
                ListTile(
                  leading: const Icon(Icons.star_border),
                  title: Text(tr('Yêu thích', 'Favorites')),
                  selected: _favorites,
                  onTap: _selectFavorites,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(tr('Thùng rác', 'Trash')),
                  onTap: () => _pushFromDrawer(const TrashScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(tr('Tin nhắn', 'Messages')),
                  onTap: () => _pushFromDrawer(const ChatListScreen()),
                ),
                const Divider(),
                SpaceMenu(
                  selectedSpaceId: _space?.id,
                  favoriteIds: prefs.favoriteSpaces.toSet(),
                  isHidden: prefs.isRestricted,
                  onSpaceSelected: _selectSpace,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bookmark_border),
                  title: Text(tr('Đã lưu', 'Saved')),
                  onTap: () => _pushFromDrawer(const SavedScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(tr('Cài đặt và hoạt động', 'Settings and activity')),
                  onTap: () => _pushFromDrawer(const SettingsHubScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(tr('Lời cảm ơn', 'Thank-yous')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ThanksInboxScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.hourglass_bottom),
                  title: Text(tr('Hộp thời gian', 'Time capsules')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CapsulesScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.call_merge),
                  title: Text(tr('Đề xuất sửa bài', 'Edit proposals')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ProposalsScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: Text(tr('Công thức bảng tin', 'Feed recipes')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RecipesScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inbox_outlined),
                  title: Text(tr('Hộp thư của tôi', 'My box')),
                  onTap: () => _pushFromDrawer(const MyBoxScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.groups),
                  title: const Text('Weave Together'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WeaveListScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: Text(tr('Dấu vết đóng góp', 'Contribution trail')),
                  onTap: () {
                    Navigator.pop(context);
                    final u = FirebaseAuth.instance.currentUser;
                    if (u == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContributionScreen(
                          userId: u.uid,
                          name: u.displayName ?? '',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required IconData activeIcon,
    required int page,
    bool unread = false,
  }) {
    final selected = _page == page;
    Widget iconWidget = Icon(
      selected ? activeIcon : icon,
      size: 28,
      color: selected ? AppColors.brand : Colors.grey.shade600,
    );
    if (unread) {
      iconWidget = UnreadBadge(
        key: ValueKey(FirebaseAuth.instance.currentUser?.uid),
        child: iconWidget,
      );
    }
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _page = page),
        child: SizedBox(height: 56, child: Center(child: iconWidget)),
      ),
    );
  }

  Widget _createButton() {
    return Expanded(
      child: SizedBox(
        height: 56,
        child: Center(
          child: GestureDetector(
            onTap: _openCreate,
            child: Container(
              width: 54,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _page == 0 ? _buildDrawer() : null,
      body: IndexedStack(
        index: _page,
        children: [
          FeedScreen(
            key: ValueKey(uid),
            space: _space,
            favorites: _favorites,
          ),
          // key theo uid để các trang tự làm mới khi đổi tài khoản
          FriendsScreen(key: ValueKey(uid)),
          NotificationsScreen(key: ValueKey(uid)),
          ProfileScreen(key: ValueKey(uid)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              _navItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                page: 0,
              ),
              _navItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                page: 1,
              ),
              _createButton(),
              _navItem(
                icon: Icons.mail_outline,
                activeIcon: Icons.mail,
                page: 2,
                unread: true,
              ),
              _navItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                page: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}