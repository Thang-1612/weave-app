import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../models/chat_models.dart';

/// Cấu hình chung: chỉnh 1 chỗ cho khớp dự án của bạn (gọi trong main()).
class ChatConfig {
  /// Tên trường chứa tên hiển thị trong users/{uid}
  static String userNameField = 'displayName';

  /// Các trường có thể chứa ảnh đại diện (URL hoặc base64)
  static List<String> avatarFields = ['photoBase64', 'photoUrl', 'avatar'];

  /// Tắt nếu muốn tiết kiệm lượt đọc/ghi (mất chỉ báo "đang soạn tin")
  static bool enableTyping = true;

  /// Mở bài viết khi bấm thẻ bài trong tin nhắn. VD:
  /// ChatConfig.openPost = (ctx, id) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: id)));
  static void Function(BuildContext context, String postId)? openPost;

  /// Nối với Gemini/AI của app. Trả về văn bản. Để null thì ẩn nút AI.
  /// VD: ChatConfig.aiComplete = (prompt) => MyAi.ask(prompt);
  static Future<String> Function(String prompt)? aiComplete;
}

class ChatUser {
  final String uid, name;
  final String? avatar;
  const ChatUser(this.uid, this.name, this.avatar);
}

class ChatService {
  ChatService._();
  static final ChatService I = ChatService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');
  String get me => FirebaseAuth.instance.currentUser!.uid;

  static String directId(String a, String b) {
    final l = [a, b]..sort();
    return l.join('_');
  }

  // ───────────── Người dùng ─────────────
  final Map<String, Future<ChatUser>> _userFuture = {};
  final Map<String, ChatUser> _resolved = {};
  ChatUser? cached(String uid) => _resolved[uid];

  Future<ChatUser> user(String uid) => _userFuture.putIfAbsent(uid, () async {
    try {
      final d = await _db.collection('users').doc(uid).get();
      final m = d.data() ?? {};
      String? av;
      for (final f in ChatConfig.avatarFields) {
        final v = m[f];
        if (v is String && v.isNotEmpty) {
          av = v;
          break;
        }
      }
      final n = (m[ChatConfig.userNameField] ?? m['name'] ?? m['username'] ?? 'Người dùng').toString();
      final u = ChatUser(uid, n, av);
      _resolved[uid] = u;
      return u;
    } catch (_) {
      _userFuture.remove(uid);
      return ChatUser(uid, 'Người dùng', null);
    }
  });

  Future<String> chatName(Chat c) async {
    if (c.isGroup) return c.name.isEmpty ? 'Nhóm chat' : c.name;
    return (await user(c.otherId(me))).name;
  }

  /// Tên hiển thị nếu đã có trong cache; null nếu chưa tải xong.
  /// Dùng trong build() để tránh tạo Future mới mỗi lần vẽ (gây nhấp nháy).
  String? chatNameSync(Chat c) {
    if (c.isGroup) return c.name.isEmpty ? 'Nhóm chat' : c.name;
    return _resolved[c.otherId(me)]?.name;
  }

  /// Tìm theo tiền tố tên (phân biệt hoa/thường).
  Future<List<ChatUser>> searchUsers(String q) async {
    q = q.trim();
    if (q.isEmpty) return [];
    final f = ChatConfig.userNameField;
    final s = await _db
        .collection('users')
        .where(f, isGreaterThanOrEqualTo: q)
        .where(f, isLessThanOrEqualTo: '$q\uf8ff')
        .limit(20)
        .get();
    final r = <ChatUser>[];
    for (final d in s.docs) {
      if (d.id == me) continue;
      r.add(await user(d.id));
    }
    return r;
  }

  // ───────────── Bạn bè ─────────────
  /// Danh sách uid bạn bè hiện tại (lời mời đã được chấp nhận).
  Stream<List<String>> friendIds() => _db
      .collection('friendships')
      .where('users', arrayContains: me)
      .snapshots()
      .map((s) {
    final me = this.me;
    final r = <String>[];
    for (final d in s.docs) {
      final m = d.data();
      if (m['status'] != 'accepted') continue;
      final u = (m['users'] as List? ?? []).map((e) => e.toString());
      r.addAll(u.where((x) => x != me));
    }
    return r;
  });

  // ───────────── Luồng dữ liệu ─────────────
  Stream<List<Chat>> myChats() => _chats
      .where('members', arrayContains: me)
      .orderBy('lastMessageAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Chat.fromDoc).toList());

  Stream<Chat?> chat(String id) =>
      _chats.doc(id).snapshots().map((d) => d.exists ? Chat.fromDoc(d) : null);

  Stream<List<ChatMessage>> messages(String chatId, int limit) => _chats
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

  /// Tổng tin chưa đọc (bỏ qua chat đã tắt thông báo và tin chờ) cho chấm đỏ.
  Stream<int> totalUnread() => myChats().map((l) {
    var n = 0;
    final me = this.me;
    for (final c in l) {
      if (c.mutedBy.contains(me)) continue;
      if (!c.isGroup && !c.acceptedBy.contains(me)) continue;
      n += c.unreadFor(me);
    }
    return n;
  });

  // ───────────── Tạo chat ─────────────
  Map<String, dynamic> _newChat({
    required String type,
    required List<String> members,
    String name = '',
    List<String> admins = const [],
  }) =>
      <String, dynamic>{
        'type': type,
        'name': name,
        'members': members,
        'admins': admins,
        'createdBy': me,
        'acceptedBy': type == 'group' ? members : [me],
        'mutedBy': [],
        'pinnedBy': [],
        'blockedBy': [],
        'unread': {for (final m in members) m: 0},
        'lastRead': {},
        'typing': {},
        'lastMessage': {'text': '', 'senderId': '', 'type': ''},
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'disappearAfterSec': 0,
      };

  Future<String> ensureDirect(String otherUid) async {
    if (otherUid == me) throw 'Không thể nhắn cho chính mình';
    final id = directId(me, otherUid);
    final ref = _chats.doc(id);
    var exists = false;
    try {
      exists = (await ref.get()).exists;
    } catch (_) {}
    if (!exists) {
      // Bạn bè thì coi như đã chấp nhận, không rơi vào "Tin chờ" của người kia.
      var friend = false;
      try {
        final f = await _db.collection('friendships').doc(id).get();
        friend = f.exists && f.data()?['status'] == 'accepted';
      } catch (_) {}
      final data = _newChat(type: 'direct', members: [me, otherUid]);
      if (friend) data['acceptedBy'] = [me, otherUid];
      await ref.set(data);
    }
    return id;
  }

  Future<String> createGroup(String name, List<String> others) async {
    final members = {me, ...others}.toList();
    final ref = _chats.doc();
    await ref.set(_newChat(type: 'group', members: members, name: name, admins: [me]));
    final c = Chat.fromDoc(await ref.get());
    final n = (await user(me)).name;
    await _send(c, {'text': '$n đã tạo nhóm "$name"'}, 'system', '$n đã tạo nhóm', expire: false);
    return ref.id;
  }

  // ───────────── Gửi tin ─────────────
  String _snippet(ChatMessage m) {
    if (m.deleted) return 'Tin nhắn đã thu hồi';
    if (m.type == 'image') return '📷 Ảnh';
    if (m.type == 'post') return '🔗 ${m.postTitle ?? 'Bài viết'}';
    return m.text.length > 100 ? '${m.text.substring(0, 100)}…' : m.text;
  }

  Map<String, dynamic>? _replyMap(ChatMessage? r) =>
      r == null ? null : {'id': r.id, 'senderId': r.senderId, 'text': _snippet(r)};

  Future<void> _send(Chat chat, Map<String, dynamic> body, String type, String preview,
      {bool expire = true}) async {
    final me = this.me;
    final ref = _chats.doc(chat.id);
    final mref = ref.collection('messages').doc();
    final batch = _db.batch();
    batch.set(mref, <String, dynamic>{
      ...body,
      'senderId': me,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'reactions': <String, dynamic>{},
      'deleted': false,
      if (expire && chat.disappearAfterSec > 0)
        'expireAt': Timestamp.fromDate(
            DateTime.now().add(Duration(seconds: chat.disappearAfterSec))),
    });
    final upd = <String, dynamic>{
      'lastMessage': {'text': preview, 'senderId': me, 'type': type},
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastRead.$me': FieldValue.serverTimestamp(),
      'unread.$me': 0,
      'typing.$me': FieldValue.delete(),
    };
    for (final m in chat.members) {
      if (m != me) upd['unread.$m'] = FieldValue.increment(1);
    }
    if (!chat.isGroup && !chat.acceptedBy.contains(me)) {
      upd['acceptedBy'] = FieldValue.arrayUnion([me]); // trả lời = chấp nhận
    }
    batch.update(ref, upd);
    await batch.commit();
  }

  Future<void> sendText(Chat chat, String text, {ChatMessage? replyTo}) {
    final p = text.length > 80 ? '${text.substring(0, 80)}…' : text;
    return _send(chat, {'text': text, if (replyTo != null) 'replyTo': _replyMap(replyTo)}, 'text', p);
  }

  Future<void> sendImage(Chat chat, Uint8List bytes, {ChatMessage? replyTo}) {
    final b64 = base64Encode(bytes);
    if (b64.length > 700000) throw 'Ảnh quá lớn (tối đa khoảng 500KB)';
    return _send(chat, {'imageB64': b64, 'text': '', if (replyTo != null) 'replyTo': _replyMap(replyTo)},
        'image', '📷 Ảnh');
  }

  Future<void> sendPost(Chat chat, String postId, String title, String snippet) =>
      _send(chat, {'postId': postId, 'postTitle': title, 'text': snippet}, 'post', '🔗 $title');

  Future<void> sendSystem(Chat chat, String text) =>
      _send(chat, {'text': text}, 'system', text, expire: false);

  // ───────────── Sửa / thu hồi / cảm xúc ─────────────
  DocumentReference<Map<String, dynamic>> _msg(String chatId, String id) =>
      _chats.doc(chatId).collection('messages').doc(id);

  Future<void> edit(String chatId, String msgId, String text) =>
      _msg(chatId, msgId).update({'text': text, 'editedAt': FieldValue.serverTimestamp()});

  Future<void> recall(String chatId, String msgId) => _msg(chatId, msgId)
      .update({'deleted': true, 'text': '', 'imageB64': FieldValue.delete()});

  Future<void> react(String chatId, ChatMessage m, String emoji) {
    final cur = m.reactions[me];
    return _msg(chatId, m.id)
        .update({'reactions.$me': cur == emoji ? FieldValue.delete() : emoji});
  }

  // ───────────── Đã đọc / đang soạn ─────────────
  Future<void> markRead(Chat c) => _chats.doc(c.id).update({
    'lastRead.$me': FieldValue.serverTimestamp(),
    'unread.$me': 0,
  }).catchError((_) {});

  DateTime _lastTyping = DateTime(2000);
  void typing(String chatId) {
    final now = DateTime.now();
    if (now.difference(_lastTyping).inSeconds < 3) return;
    _lastTyping = now;
    _chats
        .doc(chatId)
        .update({'typing.$me': FieldValue.serverTimestamp()}).catchError((_) {});
  }

  // ───────────── Cài đặt chat ─────────────
  Future<void> _toggle(Chat c, String field, bool on) => _chats.doc(c.id).update({
    field: on ? FieldValue.arrayUnion([me]) : FieldValue.arrayRemove([me])
  });
  Future<void> setMuted(Chat c, bool on) => _toggle(c, 'mutedBy', on);
  Future<void> setPinned(Chat c, bool on) => _toggle(c, 'pinnedBy', on);
  Future<void> setBlocked(Chat c, bool on) => _toggle(c, 'blockedBy', on);
  Future<void> accept(Chat c) => _toggle(c, 'acceptedBy', true);

  Future<void> rename(Chat c, String name) => _chats.doc(c.id).update({'name': name});

  Future<void> setDisappear(Chat c, int sec) async {
    final n = (await user(me)).name;
    await _chats.doc(c.id).update({'disappearAfterSec': sec});
    await sendSystem(
        c,
        sec == 0
            ? '$n đã tắt tin nhắn tự hủy'
            : '$n đã bật tin nhắn tự hủy sau ${_label(sec)}');
  }

  String _label(int sec) => sec < 3600 ? '${sec ~/ 60} phút' : sec < 86400 ? '${sec ~/ 3600} giờ' : '${sec ~/ 86400} ngày';

  Future<void> addMembers(Chat c, List<String> uids) async {
    await _chats.doc(c.id).update({
      'members': FieldValue.arrayUnion(uids),
      'acceptedBy': FieldValue.arrayUnion(uids),
    });
    final names = <String>[];
    for (final u in uids) {
      names.add((await user(u)).name);
    }
    await sendSystem(c, '${(await user(me)).name} đã thêm ${names.join(', ')}');
  }

  Future<void> leave(Chat c) async {
    final n = (await user(me)).name;
    await sendSystem(c, '$n đã rời nhóm');
    final others = c.members.where((m) => m != me).toList();
    final soleAdmin = c.admins.length == 1 && c.admins.first == me;
    await _chats.doc(c.id).update({
      'members': FieldValue.arrayRemove([me]),
      'admins': soleAdmin && others.isNotEmpty ? [others.first] : FieldValue.arrayRemove([me]),
    });
  }

  /// Dọn tin tự hủy do chính mình gửi (không có Cloud Functions nên làm ở phía app).
  Future<void> cleanupExpired(String chatId) async {
    try {
      final s = await _chats
          .doc(chatId)
          .collection('messages')
          .where('expireAt', isLessThan: Timestamp.now())
          .limit(50)
          .get();
      for (final d in s.docs) {
        if (d.data()['senderId'] == me) await d.reference.delete();
      }
    } catch (_) {}
  }
}