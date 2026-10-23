import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/constellation_service.dart';
import '../services/friend_service.dart';
import '../services/l10n.dart';
import '../services/user_service.dart';
import 'interests_screen.dart';
import 'user_profile_page.dart';

/// Bản đồ quan hệ: tôi ở giữa, vòng 1 là bạn bè, vòng 2 là liên hệ gián tiếp
/// (chỉ hiện khi cả hai bên đồng ý công khai).
class ConstellationScreen extends StatefulWidget {
  const ConstellationScreen({super.key});

  @override
  State<ConstellationScreen> createState() => _ConstellationScreenState();
}

class _ConstellationScreenState extends State<ConstellationScreen> {
  /// Bottom sheet không kéo giãn hết màn hình rộng.
  static const _sheetConstraints = BoxConstraints(maxWidth: 560);

  final _tc = TransformationController();
  bool _loading = true;
  bool _centered = false;
  String? _error;
  UserProfile? _me;
  List<Friendship> _mine = [];
  List<ConstellationNode> _nodes = [];
  String? _filter; // tag đang lọc

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _centered = false;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('msgNotSignedIn');

      // Tự chữa: đồng bộ danh sách cạnh công khai của chính mình.
      try {
        await FriendService.syncPublicEdges();
      } catch (_) {}

      final me = await UserService.watchProfile(uid).first;
      if (me == null) throw Exception('profile');
      final mine = await FriendService.watchMine().first;
      final nodes = await ConstellationService.build(me, mine, force: force);
      if (!mounted) return;
      setState(() {
        _me = me;
        _mine = mine;
        _nodes = nodes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = tr(
          'Không tải được bản đồ. Thử lại nhé.',
          'Could not load the map. Please try again.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _openInterests() async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const InterestsScreen()));
    if (saved == true) {
      ConstellationService.invalidate();
      _load(force: true);
    }
  }

  void _openProfile(UserProfile p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(userId: p.uid, title: p.name),
      ),
    );
  }

  Future<void> _showSuggestions() async {
    final me = _me;
    if (me == null) return;
    final tags = [...me.interests, ...me.goalTags];
    if (tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Hãy thêm sở thích trước để tìm bạn cùng sở thích.',
              'Add some interests first to find like-minded people.',
            ),
          ),
        ),
      );
      return;
    }
    final exclude = _nodes.map((n) => n.profile.uid).toSet();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: _sheetConstraints,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: FutureBuilder<List<UserProfile>>(
          future: UserService.suggestByInterests(tags, exclude: exclude),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data ?? const <UserProfile>[];
            if (list.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr(
                      'Chưa có ai trùng sở thích với bạn.',
                      'No one shares your interests yet.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final p = list[i];
                final shared = {
                  ...p.interests,
                  ...p.goalTags,
                }.where(tags.contains).toList();
                return ListTile(
                  leading: CircleAvatar(child: Text(_initial(p))),
                  title: Text(p.name),
                  subtitle: Text(shared.join(', ')),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openProfile(p);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showNode(ConstellationNode n) async {
    final me = FirebaseAuth.instance.currentUser?.uid ?? '';
    final other = n.profile.uid;
    Friendship? f;
    for (final x in _mine) {
      if (x.users.contains(other) && x.users.contains(me)) f = x;
    }
    var changed = false;
    var mePublic = f != null && f.isPublicBy(me);
    final otherPublic = f != null && f.isPublicBy(other);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: _sheetConstraints,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 24, child: Text(_initial(n.profile))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.profile.name,
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                        if (n.depth == 2 && n.viaName != null)
                          Text(
                            tr(
                              'Quen qua ${n.viaName}',
                              'Connected through ${n.viaName}',
                            ),
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (n.profile.bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(n.profile.bio),
              ],
              const SizedBox(height: 12),
              Text(
                tr('Điểm chung', 'In common'),
                style: Theme.of(ctx).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              n.sharedTags.isEmpty
                  ? Text(tr('Chưa có thẻ nào trùng.', 'No shared tags yet.'))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final t in n.sharedTags) Chip(label: Text(t)),
                      ],
                    ),
              if (n.depth == 1) ...[
                const Divider(height: 28),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    tr(
                      'Hiện mối quan hệ này trên bản đồ của bạn bè',
                      'Show this connection on friends\' maps',
                    ),
                  ),
                  subtitle: Text(
                    mePublic && !otherPublic
                        ? tr(
                            'Bạn đã bật. Chỉ hiện khi người kia cũng bật.',
                            'You turned it on. It shows only once they do too.',
                          )
                        : tr(
                            'Chỉ hiện khi cả hai cùng bật.',
                            'Shown only when both of you turn it on.',
                          ),
                  ),
                  value: mePublic,
                  onChanged: f == null
                      ? null
                      : (v) async {
                          setSheet(() => mePublic = v);
                          try {
                            await FriendService.setVisibility(
                              other,
                              v ? EdgeVisibility.public : EdgeVisibility.hidden,
                            );
                            changed = true;
                          } catch (_) {
                            setSheet(() => mePublic = !v);
                          }
                        },
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openProfile(n.profile);
                  },
                  child: Text(tr('Xem trang cá nhân', 'View profile')),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (changed) {
      ConstellationService.invalidate();
      _load(force: true);
    }
  }

  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Bản đồ kết nối', 'Connection map')),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search_outlined),
            tooltip: tr(
              'Gợi ý bạn cùng sở thích',
              'People with shared interests',
            ),
            onPressed: _me == null ? null : _showSuggestions,
          ),
          IconButton(
            icon: const Icon(Icons.sell_outlined),
            tooltip: tr('Sở thích & mục tiêu', 'Interests & goals'),
            onPressed: _openInterests,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: tr('Tải lại', 'Reload'),
            onPressed: _loading ? null : () => _load(force: true),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _load(force: true),
                child: Text(tr('Thử lại', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }
    final me = _me!;
    if (_nodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(
                  'Bản đồ của bạn còn trống. Hãy kết bạn và thêm sở thích để các điểm xuất hiện.',
                  'Your map is empty. Add friends and interests to see it fill up.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _openInterests,
                child: Text(tr('Thêm sở thích', 'Add interests')),
              ),
            ],
          ),
        ),
      );
    }

    final layout = _computeLayout(_nodes);
    final myTags = [...me.interests, ...me.goalTags];
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (myTags.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tr('Tất cả', 'All')),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final t in myTags)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t),
                      selected: _filter == t,
                      onSelected: (s) => setState(() => _filter = s ? t : null),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, c) {
              _centerOnce(layout, c.biggest);
              return ClipRect(
                child: InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  minScale: 0.3,
                  maxScale: 2.5,
                  boundaryMargin: const EdgeInsets.all(240),
                  child: SizedBox(
                    width: layout.size.width,
                    height: layout.size.height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _EdgePainter(
                              center: layout.center,
                              pos: layout.pos,
                              nodes: _nodes,
                              filter: _filter,
                              strong: scheme.primary,
                              soft: scheme.outline,
                            ),
                          ),
                        ),
                        _bubble(
                          pos: layout.center,
                          radius: 34,
                          label: tr('Tôi', 'Me'),
                          letter: _initial(me),
                          color: scheme.primary,
                          onColor: scheme.onPrimary,
                        ),
                        for (final n in _nodes)
                          _nodeWidget(n, layout.pos[n.profile.uid], scheme),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _nodeWidget(ConstellationNode n, Offset? pos, ColorScheme scheme) {
    if (pos == null) return const SizedBox.shrink();
    final matches = _filter == null || n.sharedTags.contains(_filter);
    final first = n.depth == 1;
    return Opacity(
      opacity: matches ? (first && n.hiddenByMe ? 0.75 : 1) : 0.2,
      child: _bubble(
        pos: pos,
        radius: first ? 26 : 20,
        label: n.profile.shortName,
        letter: _initial(n.profile),
        color: first
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        onColor: first ? scheme.onSecondaryContainer : scheme.onSurface,
        locked: first && n.hiddenByMe,
        badge: n.sharedTags.length,
        onTap: () => _showNode(n),
      ),
    );
  }

  Widget _bubble({
    required Offset pos,
    required double radius,
    required String label,
    required String letter,
    required Color color,
    required Color onColor,
    bool locked = false,
    int badge = 0,
    VoidCallback? onTap,
  }) {
    const w = 92.0;
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: pos.dx - w / 2,
      top: pos.dy - radius,
      width: w,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: radius,
                  backgroundColor: color,
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: onColor,
                      fontWeight: FontWeight.w600,
                      fontSize: radius * 0.8,
                    ),
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: scheme.tertiary,
                      child: Text(
                        '$badge',
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.onTertiary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (locked)
                  const Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Icon(Icons.lock_outline, size: 12),
                  ),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _centerOnce(_Layout l, Size view) {
    if (_centered) return;
    _centered = true;
    final s = math
        .min(
          1.0,
          math.min(view.width / l.size.width, view.height / l.size.height) *
              1.6,
        )
        .clamp(0.45, 1.0)
        .toDouble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tc.value =
          Matrix4.translationValues(
            view.width / 2 - s * l.center.dx,
            view.height / 2 - s * l.center.dy,
            0,
          ) *
          Matrix4.diagonal3Values(s, s, 1);
    });
  }
}

String _initial(UserProfile p) {
  final n = p.shortName;
  if (n.isEmpty) return '?';
  return String.fromCharCode(n.runes.first).toUpperCase();
}

// -------------------------------------------------------------------------
// Bố cục: vòng tròn đồng tâm
// -------------------------------------------------------------------------

class _Layout {
  final Map<String, Offset> pos;
  final Size size;
  final Offset center;
  _Layout(this.pos, this.size, this.center);
}

_Layout _computeLayout(List<ConstellationNode> nodes) {
  final first = nodes.where((n) => n.depth == 1).toList()
    ..sort((a, b) {
      // Gom những người có cùng tag đầu tiên lại gần nhau thành cụm.
      final ka = a.sharedTags.isEmpty ? '~' : a.sharedTags.first;
      final kb = b.sharedTags.isEmpty ? '~' : b.sharedTags.first;
      final c = ka.compareTo(kb);
      return c != 0 ? c : a.profile.name.compareTo(b.profile.name);
    });
  final second = nodes.where((n) => n.depth == 2).toList();

  final r1 = math.max(170.0, first.length * 64 / (2 * math.pi));
  final r2 = r1 + 190;
  final outer = (second.isEmpty ? r1 : r2) + 100;
  final center = Offset(outer, outer);

  final pos = <String, Offset>{};
  final angleOf = <String, double>{};
  for (var i = 0; i < first.length; i++) {
    final a = -math.pi / 2 + 2 * math.pi * i / first.length;
    final uid = first[i].profile.uid;
    angleOf[uid] = a;
    pos[uid] = center + Offset(math.cos(a), math.sin(a)) * r1;
  }

  final groups = <String, List<ConstellationNode>>{};
  for (final n in second) {
    groups.putIfAbsent(n.viaUid ?? '', () => []).add(n);
  }
  groups.forEach((via, list) {
    final base = angleOf[via] ?? 0.0;
    for (var k = 0; k < list.length; k++) {
      final a = base + (k - (list.length - 1) / 2) * 0.32;
      final r = r2 + (k.isOdd ? 34 : 0);
      pos[list[k].profile.uid] = center + Offset(math.cos(a), math.sin(a)) * r;
    }
  });

  return _Layout(pos, Size(outer * 2, outer * 2), center);
}

class _EdgePainter extends CustomPainter {
  final Offset center;
  final Map<String, Offset> pos;
  final List<ConstellationNode> nodes;
  final String? filter;
  final Color strong;
  final Color soft;

  _EdgePainter({
    required this.center,
    required this.pos,
    required this.nodes,
    required this.filter,
    required this.strong,
    required this.soft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final n in nodes) {
      final to = pos[n.profile.uid];
      if (to == null) continue;
      final from = n.depth == 1 ? center : (pos[n.viaUid] ?? center);
      final match = filter == null || n.sharedTags.contains(filter);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = n.depth == 1
            ? 1.5 + math.min(n.sharedTags.length, 4) * 0.6
            : 1
        ..color = (n.depth == 1 ? strong : soft).withValues(
          alpha: match ? (n.depth == 1 ? 0.55 : 0.4) : 0.1,
        );
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.filter != filter ||
      old.nodes != nodes ||
      old.pos != pos ||
      old.strong != strong ||
      old.soft != soft;
}
