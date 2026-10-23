import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;
List<String> _strs(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];
Map<String, DateTime> _tsMap(dynamic v) {
  final r = <String, DateTime>{};
  if (v is Map) {
    v.forEach((k, val) {
      final t = _ts(val);
      if (t != null) r[k.toString()] = t;
    });
  }
  return r;
}

class Chat {
  final String id, type, name, createdBy;
  final List<String> members, admins, mutedBy, pinnedBy, acceptedBy, blockedBy;
  final Map<String, int> unread;
  final Map<String, DateTime> lastRead, typing;
  final String lastText, lastSenderId, lastType;
  final DateTime? lastMessageAt;
  final int disappearAfterSec;

  const Chat({
    required this.id,
    required this.type,
    required this.name,
    required this.createdBy,
    required this.members,
    required this.admins,
    required this.mutedBy,
    required this.pinnedBy,
    required this.acceptedBy,
    required this.blockedBy,
    required this.unread,
    required this.lastRead,
    required this.typing,
    required this.lastText,
    required this.lastSenderId,
    required this.lastType,
    required this.lastMessageAt,
    required this.disappearAfterSec,
  });

  bool get isGroup => type == 'group';
  bool get hasMessages => lastType.isNotEmpty;
  String otherId(String me) =>
      members.firstWhere((m) => m != me, orElse: () => me);
  int unreadFor(String me) => unread[me] ?? 0;

  factory Chat.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final last = m['lastMessage'] is Map
        ? Map<String, dynamic>.from(m['lastMessage'] as Map)
        : <String, dynamic>{};
    final unread = <String, int>{};
    if (m['unread'] is Map) {
      (m['unread'] as Map).forEach(
        (k, v) => unread[k.toString()] = (v as num?)?.toInt() ?? 0,
      );
    }
    return Chat(
      id: d.id,
      type: (m['type'] ?? 'direct').toString(),
      name: (m['name'] ?? '').toString(),
      createdBy: (m['createdBy'] ?? '').toString(),
      members: _strs(m['members']),
      admins: _strs(m['admins']),
      mutedBy: _strs(m['mutedBy']),
      pinnedBy: _strs(m['pinnedBy']),
      acceptedBy: _strs(m['acceptedBy']),
      blockedBy: _strs(m['blockedBy']),
      unread: unread,
      lastRead: _tsMap(m['lastRead']),
      typing: _tsMap(m['typing']),
      lastText: (last['text'] ?? '').toString(),
      lastSenderId: (last['senderId'] ?? '').toString(),
      lastType: (last['type'] ?? '').toString(),
      lastMessageAt: _ts(m['lastMessageAt']),
      disappearAfterSec: (m['disappearAfterSec'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatMessage {
  final String id, senderId, type, text;
  final String? imageB64, postId, postTitle;
  final Map<String, dynamic>? replyTo;
  final Map<String, String> reactions;
  final DateTime createdAt;
  final DateTime? editedAt, expireAt;
  final bool deleted, pending;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.text,
    required this.imageB64,
    required this.postId,
    required this.postTitle,
    required this.replyTo,
    required this.reactions,
    required this.createdAt,
    required this.editedAt,
    required this.expireAt,
    required this.deleted,
    required this.pending,
  });

  factory ChatMessage.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final r = <String, String>{};
    if (m['reactions'] is Map) {
      (m['reactions'] as Map).forEach((k, v) => r[k.toString()] = v.toString());
    }
    return ChatMessage(
      id: d.id,
      senderId: (m['senderId'] ?? '').toString(),
      type: (m['type'] ?? 'text').toString(),
      text: (m['text'] ?? '').toString(),
      imageB64: m['imageB64'] as String?,
      postId: m['postId'] as String?,
      postTitle: m['postTitle'] as String?,
      replyTo: m['replyTo'] is Map
          ? Map<String, dynamic>.from(m['replyTo'] as Map)
          : null,
      reactions: r,
      createdAt: _ts(m['createdAt']) ?? DateTime.now(),
      editedAt: _ts(m['editedAt']),
      expireAt: _ts(m['expireAt']),
      deleted: m['deleted'] == true,
      pending: d.metadata.hasPendingWrites,
    );
  }
}
