import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/account_service.dart';
import '../services/friend_service.dart';
import '../services/l10n.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/friend_button.dart';
import '../widgets/suggested_people.dart';
import '../widgets/weave_error_view.dart';
import '../widgets/weave_state_views.dart';
import 'user_profile_page.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  /// Độ rộng tối đa của cột danh sách (canh giữa trên màn rộng).
  static const double _maxContentWidth = 720;

  // Không để final: nút Thử lại gán stream mới để nạp lại dữ liệu thật.
  Stream<List<Friendship>> _stream = FriendService.watchMine();
  final _search = TextEditingController();
  Timer? _debounce;

  List<UserProfile> _results = [];
  bool _searching = false;
  String? _searchError;

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    try {
      final res = await UserService.searchUsers(q);
      if (!mounted || _search.text.trim() != q) return;
      setState(() {
        _results = res;
        _searching = false;
        _searchError = null;
      });
    } catch (e) {
      debugPrint('FriendsScreen search error: $e');
      if (mounted) {
        setState(() {
          _searching = false;
          _searchError = '$e';
        });
      }
    }
  }

  void _retrySearch() {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    _runSearch(q);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Padding để ListView full chiều rộng nhưng nội dung căn giữa tối đa
  /// [_maxContentWidth] (lăn chuột ở hai lề vẫn cuộn được).
  EdgeInsets _listPadding(double width) => weaveCenteredPadding(
    width,
    maxWidth: _maxContentWidth,
    h: 0,
    top: 0,
    bottom: WeaveSpacing.lg,
  );

  Widget _buildLists(List<Friendship> all, String me, double width) {
    final incoming = all
        .where((f) => !f.accepted && f.requesterId != me)
        .toList();
    final outgoing = all
        .where((f) => !f.accepted && f.requesterId == me)
        .toList();
    final friends = all.where((f) => f.accepted).toList();

    Widget row(String prefix, Friendship f) {
      final uid = f.otherUid(me);
      return _PersonRow(
        key: ValueKey('$prefix$uid'),
        uid: uid,
        trailing: FriendActionButton(uid: uid, friendships: all, compact: true),
      );
    }

    return ListView(
      padding: _listPadding(width),
      children: [
        if (all.isEmpty)
          WeaveEmptyView(
            icon: Icons.people_outline,
            title: tr('Bạn chưa có bạn bè nào.', 'You have no friends yet.'),
            description: tr(
              'Tìm theo tên ở ô phía trên, hoặc chọn từ gợi ý bên dưới.',
              'Search by name above, or pick from the suggestions below.',
            ),
          ),
        if (incoming.isNotEmpty) ...[
          _header(
            tr(
              'LỜI MỜI KẾT BẠN (${incoming.length})',
              'FRIEND REQUESTS (${incoming.length})',
            ),
          ),
          for (final f in incoming) row('in_', f),
        ],
        if (friends.isNotEmpty) ...[
          _header(
            tr('BẠN BÈ (${friends.length})', 'FRIENDS (${friends.length})'),
          ),
          for (final f in friends) row('fr_', f),
        ],
        if (outgoing.isNotEmpty) ...[
          _header(
            tr(
              'LỜI MỜI ĐÃ GỬI (${outgoing.length})',
              'SENT REQUESTS (${outgoing.length})',
            ),
          ),
          for (final f in outgoing) row('out_', f),
        ],
        SuggestedPeople(key: const ValueKey('suggested'), friendships: all),
      ],
    );
  }

  Widget _buildSearch(List<Friendship> friendships, double width) {
    if (_searching) return const WeaveLoadingView();
    if (_searchError != null) {
      return WeaveErrorView(
        message: tr('Không tìm được.', 'Search failed.'),
        onRetry: _retrySearch,
      );
    }
    if (_results.isEmpty) {
      return WeaveEmptyView(
        icon: Icons.search_off,
        title: tr(
          'Không tìm thấy "${_search.text.trim()}"',
          'No results for "${_search.text.trim()}"',
        ),
      );
    }
    return ListView(
      padding: _listPadding(width),
      children: [
        for (final p in _results)
          _PersonRow(
            key: ValueKey('s_${p.uid}'),
            uid: p.uid,
            profile: p,
            trailing: FriendActionButton(
              uid: p.uid,
              friendships: friendships,
              compact: true,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid ?? '';
    final query = _search.text.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          children: [
            // Ô tìm kiếm căn giữa tối đa 720; danh sách bên dưới full chiều rộng.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  // Viền, bo góc 12 và màu focus lấy từ theme (khớp mọi ô nhập khác)
                  child: TextField(
                    controller: _search,
                    onChanged: _onChanged,
                    decoration: InputDecoration(
                      hintText: tr(
                        'Tìm bạn bè theo tên',
                        'Search friends by name',
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                        tooltip: tr('Xóa', 'Clear'),
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _onChanged('');
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Friendship>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    debugPrint('FriendsScreen stream error: ${snap.error}');
                    return WeaveErrorView(
                      message: tr(
                        'Không tải được danh sách bạn bè.',
                        'Could not load your friends.',
                      ),
                      onRetry: () =>
                          setState(() => _stream = FriendService.watchMine()),
                    );
                  }
                  final friendships = snap.data ?? const <Friendship>[];
                  if (query.isNotEmpty) {
                    return _buildSearch(friendships, width);
                  }
                  if (!snap.hasData) {
                    return const WeaveLoadingView();
                  }
                  return _buildLists(friendships, me, width);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Một dòng người dùng: avatar, tên, giới thiệu và nút hành động.
class _PersonRow extends StatefulWidget {
  final String uid;
  final UserProfile? profile; // null = tự tải hồ sơ theo uid
  final Widget trailing;

  const _PersonRow({
    super.key,
    required this.uid,
    this.profile,
    required this.trailing,
  });

  @override
  State<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<_PersonRow> {
  Stream<UserProfile?>? _stream;

  @override
  void initState() {
    super.initState();
    if (widget.profile == null) {
      _stream = UserService.watchProfile(widget.uid);
    }
  }

  Widget _row(BuildContext context, String name, String bio) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserProfilePage(userId: widget.uid, title: name),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.soft,
              child: Text(
                initialOf(name),
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
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (bio.isNotEmpty)
                    Text(
                      bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            widget.trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unknown = tr('Người dùng', 'User');
    final p = widget.profile;
    if (p != null) {
      return _row(context, p.name.isEmpty ? unknown : p.name, p.bio);
    }
    return StreamBuilder<UserProfile?>(
      stream: _stream,
      builder: (context, snap) {
        final name = snap.data?.name ?? '';
        return _row(
          context,
          name.isEmpty ? unknown : name,
          snap.data?.bio ?? '',
        );
      },
    );
  }
}