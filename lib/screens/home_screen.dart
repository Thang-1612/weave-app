import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/space.dart';
import '../services/account_service.dart';
import '../services/interest_service.dart';
import '../services/l10n.dart';
import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/account_switcher.dart';
import '../widgets/weave_responsive_shell.dart';
import '../widgets/home_side_widgets.dart';
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
    // Giữ danh sách người xem của bài chỉ-bạn-bè khớp với danh sách bạn bè
    FriendPostSync.start();
    TrashService.purgeExpired(); // dọn bài trong thùng rác quá 30 ngày
    // Mở bài viết khi vào từ liên kết dạng /post/<mã> (bản web)
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

  /// Mở bài viết khi vào từ liên kết dạng `/post/<mã>` (bản web).
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

  // Menu chủ đề dùng chung cho Drawer (mobile, tablet) và sidebar (desktop).
  // Trong Drawer thì đóng menu sau khi chọn; trong sidebar thì không.
  void _closeMenu(bool inDrawer) {
    if (inDrawer) Navigator.of(context).pop();
  }

  void _selectAll(bool inDrawer) {
    setState(() {
      _space = null;
      _favorites = false;
      _page = 0;
    });
    _closeMenu(inDrawer);
  }

  void _selectFavorites(bool inDrawer) {
    setState(() {
      _space = null;
      _favorites = true;
      _page = 0;
    });
    _closeMenu(inDrawer);
  }

  void _selectSpace(Space s, bool inDrawer) {
    InterestService.track(s.id, 3); // ghi nhận sở thích
    setState(() {
      _space = s;
      _favorites = false;
      _page = 0;
    });
    _closeMenu(inDrawer);
  }

  void _openFromMenu(Widget page, bool inDrawer) {
    _closeMenu(inDrawer);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  String _homeTitle() {
    if (_favorites) return '⭐ ${tr('Yêu thích', 'Favorites')}';
    final s = _space;
    if (s == null) return tr('Tất cả bài đăng', 'All posts');
    return '${s.emoji} ${tr(s.name, s.nameEn ?? s.name)}';
  }

  String _pageTitle() {
    switch (_page) {
      case 0:
        return _homeTitle();
      case 1:
        return tr('Bạn bè', 'Friends');
      case 2:
        return tr('Thông báo', 'Notifications');
      default:
        return tr('Cá nhân', 'Profile');
    }
  }

  // AppBar phẳng theo theme. Mobile có thêm nút "+" tạo bài vì thanh dưới
  // không còn nút giữa; tablet có nút nổi, desktop có nút ở sidebar.
  PreferredSizeWidget _buildAppBar(BuildContext context, WeaveLayoutInfo info) {
    final createAction = IconButton(
      tooltip: tr('Tạo bài', 'Create post'),
      icon: const Icon(Icons.add_circle_outline_rounded),
      onPressed: _openCreate,
    );

    if (_page == 0) {
      return AppBar(
        title: Text(
          _homeTitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(
            tooltip: tr('Tin nhắn', 'Messages'),
            icon: ChatUnreadBadge(child: const Icon(Icons.chat_bubble_outline)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatListScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Weave Storymaker',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StoryListScreen()),
            ),
          ),
          if (info.isMobile) createAction,
        ],
      );
    }
    return AppBar(
      title: Text(
        _pageTitle(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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
        if (info.isMobile) createAction,
      ],
    );
  }

  // Header menu là điểm nhấn gradient duy nhất của màn hình này.
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
            WeaveSpacing.xl,
            MediaQuery.of(context).padding.top + WeaveSpacing.xl,
            WeaveSpacing.xl,
            WeaveSpacing.lg,
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
              const SizedBox(height: WeaveSpacing.md),
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

  /// Các mục của menu chủ đề. Dùng trong Drawer (inDrawer = true)
  /// và trong sidebar desktop (inDrawer = false): một nguồn, không nhân đôi.
  List<Widget> _menuItems({required bool inDrawer}) {
    final prefs = UserPrefs.instance;

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          WeaveSpacing.lg,
          WeaveSpacing.lg,
          WeaveSpacing.lg,
          WeaveSpacing.xs,
        ),
        child: Text(
          tr('CHỦ ĐỀ', 'TOPICS'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.dashboard_outlined),
        title: Text(tr('Tất cả', 'All')),
        selected: _page == 0 && _space == null && !_favorites,
        onTap: () => _selectAll(inDrawer),
      ),
      ListTile(
        leading: const Icon(Icons.star_border),
        title: Text(tr('Yêu thích', 'Favorites')),
        selected: _page == 0 && _favorites,
        onTap: () => _selectFavorites(inDrawer),
      ),
      ListTile(
        leading: const Icon(Icons.delete_outline),
        title: Text(tr('Thùng rác', 'Trash')),
        onTap: () => _openFromMenu(const TrashScreen(), inDrawer),
      ),
      ListTile(
        leading: const Icon(Icons.chat_bubble_outline),
        title: Text(tr('Tin nhắn', 'Messages')),
        onTap: () => _openFromMenu(const ChatListScreen(), inDrawer),
      ),
      const Divider(),
      SpaceMenu(
        selectedSpaceId: _page == 0 ? _space?.id : null,
        favoriteIds: prefs.favoriteSpaces.toSet(),
        isHidden: prefs.isRestricted,
        onSpaceSelected: (s) => _selectSpace(s, inDrawer),
      ),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.bookmark_border),
        title: Text(tr('Đã lưu', 'Saved')),
        onTap: () => _openFromMenu(const SavedScreen(), inDrawer),
      ),
      ListTile(
        leading: const Icon(Icons.settings_outlined),
        title: Text(tr('Cài đặt và hoạt động', 'Settings and activity')),
        onTap: () => _openFromMenu(const SettingsHubScreen(), inDrawer),
      ),
      ListTile(
        leading: const Icon(Icons.mail_outline),
        title: Text(tr('Lời cảm ơn', 'Thank-yous')),
        onTap: () => _openFromMenu(const ThanksInboxScreen(), inDrawer),
      ),
      ListTile(
        leading: const Icon(Icons.hourglass_bottom),
        title: Text(tr('Hộp thời gian', 'Time capsules')),
        onTap: () => _openFromMenu(const CapsulesScreen(), inDrawer),
      ),
      ListTile(
        leading: const Icon(Icons.call_merge),
        title: Text(tr('Đề xuất sửa bài', 'Edit proposals')),
        onTap: () => _openFromMenu(const ProposalsScreen(), inDrawer),
      ),
      ListTile(
        leading: const Icon(Icons.tune),
        title: Text(tr('Công thức bảng tin', 'Feed recipes')),
        onTap: () => _openFromMenu(const RecipesScreen(), inDrawer),
      ),
      ListTile(
        leading: const Icon(Icons.inbox_outlined),
        title: Text(tr('Hộp thư của tôi', 'My box')),
        onTap: () => _openFromMenu(const MyBoxScreen(), inDrawer),
      ),
      ListTile(
        leading: const Icon(Icons.groups),
        title: const Text('Weave Together'),
        onTap: () => _openFromMenu(const WeaveListScreen(), inDrawer),
      ),
      ListTile(
        leading: const Icon(Icons.emoji_events_outlined),
        title: Text(tr('Dấu vết đóng góp', 'Contribution trail')),
        onTap: () {
          _closeMenu(inDrawer);
          final u = FirebaseAuth.instance.currentUser;
          if (u == null) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ContributionScreen(
                userId: u.uid,
                name: u.displayName ?? '',
              ),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _menuItems(inDrawer: true),
            ),
          ),
        ],
      ),
    );
  }

  // Cùng menu đó nhưng đặt trong sidebar desktop.
  Widget _buildSidebarMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: WeaveSpacing.xl),
        ..._menuItems(inDrawer: false),
      ],
    );
  }

  // Trang chủ: trên tablet/desktop có thêm lời chào + ô tạo bài phía trên
  // bảng tin; mobile chỉ có bảng tin (nút "+" đã nằm trên AppBar).
  Widget _homeTab(String? uid) {
    // Builder để có context nằm dưới shell (đọc được WeaveLayout).
    return Builder(
      builder: (context) {
        final showHeader = !WeaveLayout.of(context).isMobile;
        return LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                if (showHeader)
                  HomeFeedHeader(
                    name: nameOf(FirebaseAuth.instance.currentUser),
                    onCreate: _openCreate,
                    // Cửa sổ thấp thì bỏ lời chào để nhường chỗ cho bảng tin.
                    showGreeting: constraints.maxHeight >= 720,
                  ),
                // Key cố định: đổi cỡ cửa sổ không làm mất vị trí cuộn của feed.
                Expanded(
                  key: const ValueKey('home-feed'),
                  child: FeedScreen(
                    key: ValueKey(uid),
                    space: _space,
                    favorites: _favorites,
                    // Shell đã giới hạn độ rộng cột; không cắt thêm 600 px
                    maxWidth: double.infinity,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Cột phải (desktop rộng, chỉ ở trang chủ): lối tắt tới các màn hình có thật.
  Widget? _buildSecondaryPanel() {
    if (_page != 0) return null;
    return HomeShortcutsPanel(
      title: tr('Lối tắt', 'Shortcuts'),
      shortcuts: [
        HomeShortcut(
          icon: Icons.hourglass_bottom,
          title: tr('Hộp thời gian', 'Time capsules'),
          onTap: () => _openFromMenu(const CapsulesScreen(), false),
        ),
        HomeShortcut(
          icon: Icons.mail_outline,
          title: tr('Lời cảm ơn', 'Thank-yous'),
          onTap: () => _openFromMenu(const ThanksInboxScreen(), false),
        ),
        HomeShortcut(
          icon: Icons.groups,
          title: 'Weave Together',
          onTap: () => _openFromMenu(const WeaveListScreen(), false),
        ),
        HomeShortcut(
          icon: Icons.auto_awesome,
          title: 'Weave Storymaker',
          onTap: () => _openFromMenu(const StoryListScreen(), false),
        ),
      ],
    );
  }

  List<WeaveDestination> _destinations(String? uid) {
    return [
      WeaveDestination(
        label: tr('Trang chủ', 'Home'),
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      WeaveDestination(
        label: tr('Bạn bè', 'Friends'),
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
      ),
      WeaveDestination(
        label: tr('Thông báo', 'Notifications'),
        icon: Icons.mail_outline,
        selectedIcon: Icons.mail,
        // key theo uid để huy hiệu chưa đọc tự làm mới khi đổi tài khoản
        iconWrapper: (icon, selected) => UnreadBadge(
          key: ValueKey('$uid-$selected'),
          child: icon,
        ),
      ),
      WeaveDestination(
        label: tr('Cá nhân', 'Profile'),
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return WeaveResponsiveShell(
      title: _pageTitle(),
      destinations: _destinations(uid),
      selectedIndex: _page,
      onDestinationSelected: (i) => setState(() => _page = i),
      appBarBuilder: _buildAppBar,
      // Mobile, tablet: menu trượt (chỉ ở trang chủ). Desktop: menu nằm trong sidebar.
      drawer: _page == 0 ? _buildDrawer() : null,
      sidebarExtra: _buildSidebarMenu(),
      onCreate: _openCreate,
      createLabel: tr('Tạo bài', 'Create post'),
      sidebarCreateLabel: tr('Tạo bài', 'Create post'),
      // Các màn hình bên trong tự lo phần đệm lề; cột bảng tin hẹp cho dễ đọc.
      contentPadding: EdgeInsets.zero,
      maxContentWidth: _page == 0 ? 880 : 960,
      secondaryPanel: _buildSecondaryPanel(),
      // SizedBox.expand + StackFit.expand: ép trang lấp đầy khung, vì shell
      // bọc body trong Align nên mặc định body chỉ nhận ràng buộc lỏng.
      body: SizedBox.expand(
        child: IndexedStack(
          index: _page,
          sizing: StackFit.expand,
          children: [
            _homeTab(uid),
            // key theo uid để các trang tự làm mới khi đổi tài khoản
            FriendsScreen(key: ValueKey(uid)),
            NotificationsScreen(key: ValueKey(uid)),
            ProfileScreen(key: ValueKey(uid)),
          ],
        ),
      ),
    );
  }
}