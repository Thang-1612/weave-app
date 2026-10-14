import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'friend_service.dart';
import 'user_prefs.dart';

/// Một điểm trên bản đồ quan hệ.
class ConstellationNode {
  final UserProfile profile;

  /// 1 = bạn trực tiếp, 2 = liên hệ gián tiếp (bạn của bạn).
  final int depth;

  /// Các tag trùng giữa tôi và người này.
  final List<String> sharedTags;

  /// Với depth 2: quen qua ai.
  final String? viaUid;
  final String? viaName;

  /// Với depth 1: tôi đang ẩn mối quan hệ này khỏi bản đồ của người khác.
  final bool hiddenByMe;

  const ConstellationNode({
    required this.profile,
    required this.depth,
    required this.sharedTags,
    this.viaUid,
    this.viaName,
    this.hiddenByMe = false,
  });
}

class _Cached {
  final DateTime at;
  final List<ConstellationNode> nodes;
  _Cached(this.at, this.nodes);
}

class ConstellationService {
  static final _db = FirebaseFirestore.instance;
  static final Map<String, _Cached> _cache = {};
  static const _ttl = Duration(minutes: 5);

  static void invalidate() => _cache.clear();

  /// Dựng danh sách điểm cho bản đồ của [me].
  ///
  /// Độ sâu 2 chỉ lấy những cạnh mà CẢ HAI đầu đều công khai: uid xuất hiện
  /// trong `public/edges` của bạn tôi VÀ bạn tôi cũng xuất hiện trong
  /// `public/edges` của uid đó. Nhờ kiểm tra hai chiều, nếu một bên vừa chuyển
  /// sang ẩn thì cạnh biến mất ngay dù bên kia chưa kịp đồng bộ.
  static Future<List<ConstellationNode>> build(
      UserProfile me,
      List<Friendship> mine, {
        bool force = false,
      }) async {
    final hit = _cache[me.uid];
    if (!force && hit != null && DateTime.now().difference(hit.at) < _ttl) {
      return hit.nodes;
    }

    final myTags = {...me.interests, ...me.goalTags};
    final accepted = mine.where((f) => f.accepted).toList();
    final friendUids = accepted
        .map((f) => f.otherUid(me.uid))
        .where((u) => u.isNotEmpty)
        .toList();

    // ---- Độ sâu 1: bạn trực tiếp ----
    final friendProfiles = await _loadProfiles(friendUids);
    final byUid = {for (final p in friendProfiles) p.uid: p};
    final nodes = <ConstellationNode>[];
    for (final f in accepted) {
      final uid = f.otherUid(me.uid);
      final p = byUid[uid];
      if (p == null || p.name.isEmpty) continue;
      if (UserPrefs.instance.isBlocked(uid)) continue;
      nodes.add(ConstellationNode(
        profile: p,
        depth: 1,
        sharedTags: _common(myTags, p),
        hiddenByMe: f.isHiddenBy(me.uid),
      ));
    }

    // ---- Độ sâu 2: bạn của bạn (cạnh công khai) ----
    final seen = {me.uid, ...friendUids};
    final viaOf = <String, String>{}; // candidate uid -> bạn đưa tới
    final lists = await Future.wait(friendUids.take(25).map((fu) async {
      return MapEntry(fu, await _publicFriends(fu));
    }));
    for (final e in lists) {
      for (final u in e.value) {
        if (!seen.contains(u)) viaOf.putIfAbsent(u, () => e.key);
      }
    }

    final candidates = await _loadProfiles(viaOf.keys.take(60).toList());
    final filtered = candidates
        .where((p) =>
    p.name.isNotEmpty &&
        p.discoverable &&
        !UserPrefs.instance.isBlocked(p.uid))
        .toList()
      ..sort((a, b) => _common(myTags, b).length
          .compareTo(_common(myTags, a).length));

    // Kiểm tra hai chiều cho tối đa 30 ứng viên đầu bảng.
    final top = filtered.take(30).toList();
    final verified = await Future.wait(top.map((p) async {
      final via = viaOf[p.uid]!;
      final back = await _publicFriends(p.uid);
      return back.contains(via) ? p : null;
    }));
    for (final p in verified) {
      if (p == null) continue;
      final via = viaOf[p.uid]!;
      nodes.add(ConstellationNode(
        profile: p,
        depth: 2,
        sharedTags: _common(myTags, p),
        viaUid: via,
        viaName: byUid[via]?.shortName,
      ));
    }

    _cache[me.uid] = _Cached(DateTime.now(), nodes);
    return nodes;
  }

  static Future<List<String>> _publicFriends(String uid) async {
    try {
      final d = await _db.doc('users/$uid/public/edges').get();
      return List<String>.from(d.data()?['friends'] as List? ?? const []);
    } catch (_) {
      return const [];
    }
  }

  static List<String> _common(Set<String> mine, UserProfile p) =>
      {...p.interests, ...p.goalTags}.where(mine.contains).toList();

  static Future<List<UserProfile>> _loadProfiles(List<String> uids) async {
    final out = <UserProfile>[];
    for (var i = 0; i < uids.length; i += 10) {
      final end = i + 10 > uids.length ? uids.length : i + 10;
      final chunk = uids.sublist(i, end); // whereIn tối đa 10 giá trị
      try {
        final snap = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        out.addAll(snap.docs.map((d) => UserProfile.fromMap(d.id, d.data())));
      } catch (_) {}
    }
    return out;
  }
}