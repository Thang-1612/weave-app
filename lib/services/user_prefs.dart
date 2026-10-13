import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import 'friend_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotifGroup {
  final String key;
  final String vi;
  final String en;
  final String descVi;
  final String descEn;
  final IconData icon;

  const NotifGroup(
      this.key,
      this.vi,
      this.en,
      this.descVi,
      this.descEn,
      this.icon,
      );
}

const notifGroups = [
  NotifGroup(
    'reactions',
    'Cảm xúc',
    'Reactions',
    'Khi ai đó thả cảm xúc vào bài viết hoặc bình luận của bạn',
    'When someone reacts to your posts or comments',
    Icons.favorite_border,
  ),
  NotifGroup(
    'comments',
    'Bình luận',
    'Comments',
    'Khi có người bình luận bài viết của bạn',
    'When someone comments on your posts',
    Icons.chat_bubble_outline,
  ),
  NotifGroup(
    'replies',
    'Trả lời',
    'Replies',
    'Khi có người trả lời bình luận của bạn',
    'When someone replies to your comment',
    Icons.reply,
  ),
  NotifGroup(
    'mentions',
    'Được nhắc đến',
    'Mentions',
    'Khi có người tag bạn bằng @',
    'When someone tags you with @',
    Icons.alternate_email,
  ),
  NotifGroup(
    'friends',
    'Bạn bè',
    'Friends',
    'Lời mời kết bạn và lời mời được chấp nhận',
    'Friend requests and accepted requests',
    Icons.people_outline,
  ),
  NotifGroup(
    'milestones',
    'Mốc tương tác',
    'Milestones',
    'Khi bài viết đạt 10, 20, ..., 100 lượt tương tác',
    'When your post reaches 10, 20, ..., 100 interactions',
    Icons.emoji_events_outlined,
  ),
  NotifGroup(
    'posted',
    'Bài viết của bạn',
    'Your posts',
    'Xác nhận khi bài viết được đăng',
    'Confirmation when your post is published',
    Icons.check_circle_outline,
  ),
];

/// Nhóm cài đặt thông báo tương ứng với một loại thông báo.
String notifGroupOf(String type) {
  switch (type) {
    case 'reaction':
    case 'comment_reaction':
      return 'reactions';
    case 'comment':
      return 'comments';
    case 'reply':
      return 'replies';
    case 'mention':
      return 'mentions';
    case 'friend_request':
    case 'friend_accepted':
      return 'friends';
    case 'milestone':
      return 'milestones';
    case 'post_created':
      return 'posted';
    case 'comment':
    case 'feedback':
      return 'comments';
    default:
      return 'other';
  }
}

/// Cài đặt và tùy chọn của tài khoản đang đăng nhập, đồng bộ theo thời gian thực.
/// Dùng: UserPrefs.instance, và ListenableBuilder để giao diện tự cập nhật.
class UserPrefs extends ChangeNotifier {
  UserPrefs._();
  static final UserPrefs instance = UserPrefs._();

  String? _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blockedSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _savedSub;

  Map<String, dynamic> _settings = {};
  String _localLang = 'vi';

  /// Đọc ngôn ngữ đã lưu trên thiết bị (dùng cho màn hình đăng nhập).
  Future<void> loadLocal() async {
    final p = await SharedPreferences.getInstance();
    _localLang = p.getString('app_language') ?? 'vi';
  }
  Map<String, String> _blocked = {};
  List<String> _saved = [];
  Set<String> _restricted = {};
  Set<String> _favUsers = {};
  Set<String> _favSpaces = {};
  Set<String> _muted = {};
  Set<String> _hidden = {};

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  DocumentReference<Map<String, dynamic>>? get _settingsRef =>
      _userDoc?.collection('private').doc('settings');

  /// Gắn với một tài khoản (gọi khi vào app hoặc khi chuyển tài khoản).
  void bind(String? uid) {
    if (uid == _uid) return;
    _settingsSub?.cancel();
    _blockedSub?.cancel();
    _savedSub?.cancel();
    _uid = uid;
    _settings = {};
    _blocked = {};
    _saved = [];
    _restricted = {};
    _favUsers = {};
    _favSpaces = {};
    _muted = {};
    _hidden = {};

    final user = _userDoc;
    if (user == null) return;

    _settingsSub = user
        .collection('private')
        .doc('settings')
        .snapshots()
        .listen((s) => _applySettings(s.data() ?? {}), onError: (_) {});

    _blockedSub = user.collection('blocked').snapshots().listen((s) {
      _blocked = {
        for (final d in s.docs) d.id: (d.data()['name'] as String? ?? ''),
      };
      notifyListeners();
    }, onError: (_) {});

    _savedSub = user
        .collection('saved')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .listen((s) {
      _saved = s.docs.map((d) => d.id).toList();
      notifyListeners();
    }, onError: (_) {});
  }

  void _applySettings(Map<String, dynamic> data) {
    _settings = data;
    Set<String> set(String key) => {
      for (final v in (data[key] as List? ?? const []))
        if (v is String) v,
    };
    _restricted = set('restrictedSpaces');
    _favUsers = set('favoriteUsers');
    _favSpaces = set('favoriteSpaces');
    _muted = set('mutedUsers');
    _hidden = set('hiddenPostIds');
    notifyListeners();
  }

  // ----------------------------- Đọc ----------------------------------

  String get language => _settings['language'] as String? ?? _localLang;
  bool get personalizeFeed => _settings['personalizeFeed'] as bool? ?? true;

  Set<String> get restrictedSpaces => _restricted;
  Set<String> get favoriteUsers => _favUsers;
  Set<String> get favoriteSpaces => _favSpaces;
  Set<String> get mutedUsers => _muted;
  Map<String, String> get blocked => _blocked;
  List<String> get savedIds => _saved;

  bool isSaved(String postId) => _saved.contains(postId);
  bool isBlocked(String uid) => _blocked.containsKey(uid);
  bool isHiddenAuthor(String uid) => isBlocked(uid) || _muted.contains(uid);
  bool isRestricted(String spaceId) => _restricted.contains(spaceId);
  bool isFavoriteUser(String uid) => _favUsers.contains(uid);

  bool notifAll() {
    final n = _settings['notif'];
    return !(n is Map && n['all'] == false);
  }

  bool notifGroupOn(String group) {
    final n = _settings['notif'];
    return !(n is Map && n[group] == false);
  }

  /// Loại thông báo này có đang được bật không.
  bool notifEnabled(String type) =>
      notifAll() && notifGroupOn(notifGroupOf(type));

  /// Bỏ bài của người bị chặn hoặc tắt tiếng, bài đã ẩn, và (tùy chọn)
  /// bài thuộc chủ đề bị hạn chế.
  List<Post> filterPosts(List<Post> posts, {bool applyRestrictions = true}) {
    return posts.where((p) {
      if (isHiddenAuthor(p.authorId)) return false;
      if (_hidden.contains(p.id)) return false;
      if (applyRestrictions && _restricted.contains(p.spaceId)) return false;
      return true;
    }).toList();
  }

  // ----------------------------- Ghi ----------------------------------

  Future<void> _merge(Map<String, dynamic> data) async {
    final ref = _settingsRef;
    if (ref == null) return;
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> _array(String key, String value, bool add) {
    return _merge({
      key: add
          ? FieldValue.arrayUnion([value])
          : FieldValue.arrayRemove([value]),
    });
  }

  Future<void> setLanguage(String code) async {
    _localLang = code;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('app_language', code);
    await _merge({'language': code});
  }
  Future<void> setPersonalize(bool on) => _merge({'personalizeFeed': on});
  Future<void> setNotif(String group, bool on) =>
      _merge({'notif': {group: on}});

  Future<void> setRestricted(String spaceId, bool on) =>
      _array('restrictedSpaces', spaceId, on);
  Future<void> setFavoriteUser(String uid, bool on) =>
      _array('favoriteUsers', uid, on);
  Future<void> setFavoriteSpace(String id, bool on) =>
      _array('favoriteSpaces', id, on);
  Future<void> setMuted(String uid, bool on) => _array('mutedUsers', uid, on);
  Future<void> hidePost(String postId) => _array('hiddenPostIds', postId, true);
  Future<void> unhidePost(String postId) =>
      _array('hiddenPostIds', postId, false);

  Future<void> toggleSaved(Post post) async {
    final user = _userDoc;
    if (user == null) return;
    final ref = user.collection('saved').doc(post.id);
    if (isSaved(post.id)) {
      await ref.delete();
    } else {
      await ref.set({
        'postId': post.id,
        'spaceId': post.spaceId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Chặn: ẩn bài và bình luận của họ, hủy kết bạn, bỏ khỏi yêu thích.
  Future<void> block(String uid, String name) async {
    final user = _userDoc;
    if (user == null) return;
    await user.collection('blocked').doc(uid).set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await FriendService.remove(uid);
    } catch (_) {}
    try {
      await setFavoriteUser(uid, false);
    } catch (_) {}
  }

  Future<void> unblock(String uid) async {
    await _userDoc?.collection('blocked').doc(uid).delete();
  }

  /// Xóa dữ liệu sở thích dùng để đề xuất bài viết.
  Future<void> resetInterests() async {
    await _userDoc?.collection('private').doc('interests').delete();
  }
}