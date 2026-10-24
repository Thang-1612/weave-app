import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/space.dart';
import '../services/capsule_service.dart';
import '../services/feed_extras.dart';
import '../services/feed_recipe_service.dart';
import '../services/feed_service.dart';
import '../services/interest_service.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';
import '../widgets/weave_error_view.dart';
import '../widgets/weave_state_views.dart';
import 'recipes_screen.dart';

class FeedScreen extends StatefulWidget {
  final Space? space; // null = tất cả (có đề xuất theo sở thích)
  final SpaceGroup? group; // xem cả một chủ đề lớn
  final bool favorites; // true = bài của người yêu thích

  /// Chiều rộng tối đa của cột bài viết. Mặc định 600 như cũ; HomeScreen
  /// truyền double.infinity vì khung responsive đã tự giới hạn độ rộng.
  final double maxWidth;

  const FeedScreen({
    super.key,
    this.space,
    this.group,
    this.favorites = false,
    this.maxWidth = 600,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  Stream<FeedResult>? _stream;
  // Bài chỉ-bạn-bè được trộn vào bảng tin theo thời gian
  late final Stream<List<Post>> _friendStream = FeedExtras.watchFriendPosts();
  late final Stream<List<Post>> _capsuleStream = CapsuleService.watchOpened();
  int _gen = 0;
  bool _lastPersonalize = UserPrefs.instance.personalizeFeed;

  /// Quỹ thời gian: 0 = thoải mái, 5 hoặc 15 phút.
  int _budgetMin = 0;

  /// Công thức bảng tin của người dùng (chỉ áp dụng cho mục "Tất cả").
  FeedRecipeState _recipes = const FeedRecipeState([], null);

  bool get _plainFeed =>
      widget.space == null && widget.group == null && !widget.favorites;

  @override
  void initState() {
    super.initState();
    UserPrefs.instance.addListener(_onPrefs);
    _setup(sync: true);
    _loadRecipes();
  }

  @override
  void dispose() {
    UserPrefs.instance.removeListener(_onPrefs);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.space?.id != widget.space?.id ||
        oldWidget.group?.id != widget.group?.id ||
        oldWidget.favorites != widget.favorites) {
      _setup(sync: true);
    }
  }

  // Bật/tắt đề xuất theo sở thích thì dựng lại bảng tin
  void _onPrefs() {
    final p = UserPrefs.instance.personalizeFeed;
    if (p != _lastPersonalize) {
      _lastPersonalize = p;
      if (_plainFeed && mounted) {
        _setup(sync: false);
      }
    }
  }

  // ---- Công thức bảng tin ----

  String _spaceKey(FeedRecipe? r) =>
      (r?.spaceIds ?? const <String>[]).join(',');

  /// Công thức đang dùng có giới hạn chủ đề không (khi đó tải riêng các chủ đề đó).
  bool get _recipeHasSpaces =>
      _plainFeed && (_recipes.active?.spaceIds.isNotEmpty ?? false);

  Future<void> _loadRecipes() async {
    try {
      final s = await FeedRecipeService.load();
      if (!mounted) return;
      final changed = _spaceKey(s.active) != _spaceKey(_recipes.active);
      setState(() => _recipes = s);
      if (changed) _setup(sync: false);
    } catch (_) {
      // Không đọc được công thức thì cứ dùng bảng tin mặc định
    }
  }

  Future<void> _pickRecipe(String? id) async {
    final before = _spaceKey(_recipes.active);
    final next = FeedRecipeState(_recipes.items, id);
    setState(() => _recipes = next);
    FeedRecipeService.save(next);
    if (before != _spaceKey(next.active)) _setup(sync: false);
  }

  Future<void> _openRecipeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WeaveRadius.card),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                tr('Công thức bảng tin', 'Feed recipe'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                _recipes.activeId == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: AppColors.brand,
              ),
              title: Text(tr('Mặc định', 'Default')),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickRecipe(null);
              },
            ),
            for (final r in _recipes.items)
              ListTile(
                leading: Icon(
                  _recipes.activeId == r.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: AppColors.brand,
                ),
                title: Text(r.name),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickRecipe(r.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.tune, color: AppColors.brand),
              title: Text(tr('Quản lý công thức...', 'Manage recipes...')),
              onTap: () async {
                Navigator.of(ctx).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecipesScreen()),
                );
                _loadRecipes();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---- Quỹ thời gian ----

  /// Ước lượng số giây để xem một bài (xem, đọc, thả cảm xúc).
  double _estimateSeconds(Post p) {
    var s = 20.0;
    for (final b in p.blocks) {
      switch (b['type']) {
        case 'text':
          final t = (b['text'] as String? ?? '').trim();
          if (t.isNotEmpty) s += t.split(RegExp(r'\s+')).length * 0.35;
          break;
        case 'image':
          s += 8;
          break;
        case 'link':
          s += 6;
          break;
      }
    }
    return s;
  }

  // Chip kiểu Weave: nền trắng + viền mảnh; đang chọn thì nền Soft Indigo,
  // viền và chữ Brand Indigo.
  TextStyle _chipLabel(bool selected) => TextStyle(
    fontSize: 13,
    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    color: selected ? AppColors.brand : AppColors.textPrimary,
  );

  Widget _toolbar() {
    final rec = _recipes.active;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WeaveSpacing.lg,
        WeaveSpacing.xs,
        WeaveSpacing.lg,
        WeaveSpacing.xs,
      ),
      child: Wrap(
        spacing: WeaveSpacing.sm,
        runSpacing: WeaveSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final m in const [0, 5, 15])
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              showCheckmark: false,
              avatar: m == 0
                  ? null
                  : Icon(
                Icons.timer_outlined,
                size: 16,
                color: _budgetMin == m
                    ? AppColors.brand
                    : AppColors.textSecondary,
              ),
              label: Text(
                m == 0 ? tr('Thoải mái', 'Relaxed') : tr('$m phút', '$m min'),
              ),
              labelStyle: _chipLabel(_budgetMin == m),
              selected: _budgetMin == m,
              selectedColor: AppColors.soft,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: _budgetMin == m ? AppColors.brand : AppColors.border,
              ),
              shape: const StadiumBorder(),
              onSelected: (_) => setState(() => _budgetMin = m),
            ),
          if (_plainFeed)
            ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.tune, size: 16, color: AppColors.brand),
              backgroundColor: rec != null ? AppColors.soft : AppColors.surface,
              side: BorderSide(
                color: rec != null ? AppColors.brand : AppColors.border,
              ),
              shape: const StadiumBorder(),
              label: Text(rec?.name ?? tr('Công thức', 'Recipe')),
              labelStyle: _chipLabel(rec != null),
              onPressed: _openRecipeSheet,
            ),
        ],
      ),
    );
  }

  // ---- Luồng dữ liệu ----

  // sync = true: gán trực tiếp (đang trong initState/didUpdateWidget)
  void _assign(Stream<FeedResult>? s, {required bool sync}) {
    if (sync) {
      _stream = s;
    } else if (mounted) {
      setState(() => _stream = s);
    }
  }

  Future<Map<String, double>> _loadAffinity() async {
    final a = await InterestService.loadAffinity();
    // Không ưu tiên các chủ đề đã bị hạn chế
    a.removeWhere((id, _) => UserPrefs.instance.isRestricted(id));
    return a;
  }

  Future<void> _setup({required bool sync}) async {
    final gen = ++_gen;
    final space = widget.space;
    final group = widget.group;

    if (widget.favorites) {
      _assign(
        FeedExtras.watchLatest(150).map((p) => FeedResult(p)),
        sync: sync,
      );
      return;
    }
    if (space != null) {
      _assign(FeedService.watchSpace(space.id), sync: sync);
      return;
    }
    if (group != null) {
      _assign(FeedService.watchGroup(group), sync: sync);
      return;
    }
    // Công thức có chọn chủ đề: chỉ tải các chủ đề đó
    final rec = _recipes.active;
    if (rec != null && rec.spaceIds.isNotEmpty) {
      _assign(FeedService.watchSpaces(rec.spaceIds), sync: sync);
      return;
    }
    if (!UserPrefs.instance.personalizeFeed) {
      _assign(PostService.watchPosts().map((p) => FeedResult(p)), sync: sync);
      return;
    }

    // Mục "Tất cả": đọc sở thích rồi mới dựng bảng tin đề xuất
    _assign(null, sync: sync);
    final affinity = await _loadAffinity();
    if (!mounted || gen != _gen) return;
    _assign(FeedService.watchForYou(affinity), sync: false);
  }

  /// Làm mới đề xuất mà không nhấp nháy màn hình tải.
  Future<void> _refresh() async {
    if (!_plainFeed) return;
    if (_recipeHasSpaces) return;
    if (!UserPrefs.instance.personalizeFeed) return;
    final gen = ++_gen;
    final affinity = await _loadAffinity();
    if (!mounted || gen != _gen) return;
    setState(() => _stream = FeedService.watchForYou(affinity));
  }

  Future<void> _seed(Space space) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FeedService.debugSeed(space.id, 25);
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã tạo 25 bài mẫu')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Không tạo được: $e')));
    }
  }

  /// Chèn bài chỉ-bạn-bè vào danh sách theo thời gian, bỏ qua [lead] bài đầu
  /// (khối ưu tiên theo sở thích).
  List<Post> _mergeFriendPosts(List<Post> base, List<Post> friend, int lead) {
    if (friend.isEmpty) return base;
    final out = [...base];
    final sorted = [...friend]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final fp in sorted) {
      var i = lead.clamp(0, out.length).toInt();
      while (i < out.length && !out[i].createdAt.isBefore(fp.createdAt)) {
        i++;
      }
      out.insert(i, fp);
    }
    return out;
  }

  Widget _stopMarker(String title, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Divider()),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.check_circle_outline, color: AppColors.brand),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(FeedResult result) {
    final names = result.priority
        .map((s) => '${s.emoji} ${tr(s.name, s.nameEn ?? s.name)}')
        .join(', ');
    return Container(
      margin: const EdgeInsets.fromLTRB(
        WeaveSpacing.lg,
        WeaveSpacing.xs,
        WeaveSpacing.lg,
        WeaveSpacing.sm,
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(WeaveRadius.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 20, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${tr('Ưu tiên cho bạn', 'Prioritized for you')}: $names',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: tr('Làm mới gợi ý', 'Refresh suggestions'),
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _refresh,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lọc lại ngay khi cài đặt (chặn, ẩn, hạn chế, yêu thích) thay đổi
    return ListenableBuilder(
      listenable: UserPrefs.instance,
      builder: (context, _) => _buildFeed(),
    );
  }

  Widget _buildFeed() {
    final stream = _stream;
    if (stream == null) {
      return const WeaveLoadingView();
    }
    final prefs = UserPrefs.instance;
    final me = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<FeedResult>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('FeedScreen stream error: ${snapshot.error}');
          return WeaveErrorView(
            message: tr('Không tải được bài viết.', 'Could not load posts.'),
            onRetry: () => _setup(sync: false),
          );
        }
        if (!snapshot.hasData) {
          return const WeaveLoadingView();
        }

        final result = snapshot.data!;
        final space = widget.space;
        final group = widget.group;
        final personalized = result.priority.isNotEmpty && !widget.favorites;
        final showSeed = kDebugMode && space != null;

        return StreamBuilder<List<Post>>(
          stream: _capsuleStream,
          builder: (context, capsuleSnap) {
            return StreamBuilder<List<Post>>(
              stream: _friendStream,
              builder: (context, friendSnap) {
                // Bài công khai
                var posts = widget.favorites
                    ? prefs
                    .filterPosts(result.posts, applyRestrictions: false)
                    .where((p) => prefs.isFavoriteUser(p.authorId))
                    .toList()
                    : prefs.filterPosts(
                  result.posts,
                  applyRestrictions: space == null,
                );

                // Bài chỉ-bạn-bè + hộp thời gian đã mở (bỏ qua lỗi)
                var friendPosts = prefs.filterPosts([
                  ...(friendSnap.data ?? const <Post>[]),
                  ...(capsuleSnap.data ?? const <Post>[]),
                ], applyRestrictions: space == null && !widget.favorites);
                if (widget.favorites) {
                  friendPosts = friendPosts
                      .where((p) => prefs.isFavoriteUser(p.authorId))
                      .toList();
                } else if (space != null) {
                  friendPosts = friendPosts
                      .where((p) => p.spaceId == space.id)
                      .toList();
                } else if (group != null) {
                  final ids = group.childIds.toSet();
                  friendPosts = friendPosts
                      .where((p) => ids.contains(p.spaceId))
                      .toList();
                }

                // Khối đầu ưu tiên giữ nguyên, bài bạn bè/hộp chèn phía sau
                var lead = 0;
                if (personalized) {
                  final ids = result.priority.map((s) => s.id).toSet();
                  while (lead < posts.length &&
                      lead < 20 &&
                      ids.contains(posts[lead].spaceId)) {
                    lead++;
                  }
                }
                posts = _mergeFriendPosts(posts, friendPosts, lead);

                // Bài tự hết hạn: chỉ tác giả còn thấy
                posts = posts
                    .where((p) => !p.isExpired || p.authorId == me)
                    .toList();

                // Công thức bảng tin (chỉ mục "Tất cả")
                final rec = _recipes.active;
                if (rec != null && _plainFeed) {
                  posts = posts.where(rec.matches).toList();
                }

                // Quỹ thời gian: giữ các bài đầu cho đến khi đủ số phút
                var budgetCut = false;
                if (_budgetMin > 0) {
                  var acc = 0.0;
                  final kept = <Post>[];
                  for (final p in posts) {
                    final s = _estimateSeconds(p);
                    if (kept.isNotEmpty && acc + s > _budgetMin * 60) {
                      budgetCut = true;
                      break;
                    }
                    acc += s;
                    kept.add(p);
                  }
                  posts = kept;
                }

                if (posts.isEmpty) {
                  final String title;
                  String? description;
                  if (widget.favorites) {
                    title = tr(
                      'Chưa có bài viết nào từ người yêu thích.',
                      'No posts from favorite people yet.',
                    );
                    description = tr(
                      'Thêm người yêu thích ở Cài đặt và hoạt động, hoặc từ menu ba chấm trên bài viết.',
                      'Add favorites in Settings and activity, or from the ⋯ menu on a post.',
                    );
                  } else if (group != null) {
                    title = tr(
                      'Chưa có bài viết trong ${group.name}.',
                      'No posts in ${group.nameEn ?? group.name} yet.',
                    );
                  } else if (space == null && rec != null) {
                    title = tr(
                      'Không có bài nào khớp công thức "${rec.name}".',
                      'No posts match the recipe "${rec.name}".',
                    );
                    description = tr(
                      'Bấm nút Công thức phía trên để đổi hoặc tắt.',
                      'Tap the Recipe button above to change or turn it off.',
                    );
                  } else if (space == null) {
                    title = tr('Chưa có bài viết nào.', 'No posts yet.');
                    description = tr(
                      'Bấm nút + để đăng bài đầu tiên!',
                      'Tap + to publish the first one!',
                    );
                  } else {
                    title = tr(
                      'Chưa có bài viết trong ${space.name}.',
                      'No posts in ${space.nameEn ?? space.name} yet.',
                    );
                  }
                  return Column(
                    children: [
                      _toolbar(),
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              WeaveEmptyView(
                                icon: Icons.article_outlined,
                                title: title,
                                description: description,
                              ),
                              if (showSeed)
                                TextButton(
                                  onPressed: () => _seed(space),
                                  child: const Text(
                                    '[Dev] Tạo 25 bài mẫu cho chủ đề này',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Mốc "xem hết hôm nay"
                final now = DateTime.now();
                final startOfToday = DateTime(now.year, now.month, now.day);
                var edge = -1;
                for (var k = lead; k < posts.length; k++) {
                  if (posts[k].createdAt.isBefore(startOfToday)) {
                    edge = k;
                    break;
                  }
                }
                final items = <Object>[
                  '__bar__',
                  if (personalized) '__header__',
                  for (var k = 0; k < posts.length; k++) ...[
                    if (k == edge &&
                        k > 0 &&
                        !posts[k - 1].createdAt.isBefore(startOfToday))
                      '__today__',
                    posts[k],
                  ],
                  budgetCut ? '__budget__' : '__end__',
                  if (showSeed) '__seed__',
                ];

                // ListView chiếm toàn bộ chiều rộng (lăn chuột và thanh cuộn
                // hoạt động ở cả hai bên lề trên desktop/web); cột bài viết
                // được giới hạn bằng đệm hai bên thay vì ConstrainedBox.
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final side = ((c.maxWidth - widget.maxWidth) / 2)
                          .clamp(0.0, double.infinity)
                          .toDouble();
                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: side,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final it = items[i];
                          if (it is Post) {
                            return PostCard(
                              key: ValueKey('${it.collection}_${it.id}'),
                              post: it,
                            );
                          }
                          if (it == '__bar__') return _toolbar();
                          if (it == '__header__') return _banner(result);
                          if (it == '__today__') {
                            return _stopMarker(
                              tr(
                                'Bạn đã xem hết bài hôm nay',
                                "You're all caught up for today",
                              ),
                              tr(
                                'Phía dưới là các bài cũ hơn',
                                'Older posts are below',
                              ),
                            );
                          }
                          if (it == '__budget__') {
                            return _stopMarker(
                              tr(
                                'Đã đủ $_budgetMin phút',
                                "That's $_budgetMin minutes",
                              ),
                              tr(
                                'Bạn có thể nghỉ rồi, hoặc chọn thời gian dài hơn ở phía trên',
                                'Time to take a break, or pick a longer session above',
                              ),
                            );
                          }
                          if (it == '__end__') {
                            return _stopMarker(
                              tr(
                                'Bạn đã xem hết rồi',
                                "You've seen everything",
                              ),
                              tr(
                                'Kéo xuống để làm mới, hoặc nghỉ một chút nhé',
                                'Pull down to refresh, or take a break',
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextButton(
                              onPressed: () => _seed(space!),
                              child: const Text('[Dev] Tạo thêm 25 bài mẫu'),
                            ),
                          );
                        },
                      );
                    },
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