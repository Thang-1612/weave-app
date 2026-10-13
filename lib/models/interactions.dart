import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/l10n.dart';

class ReactionOption {
  final String emoji;
  final String label; // tiếng Việt
  final String labelEn; // tiếng Anh

  const ReactionOption(this.emoji, this.label, this.labelEn);

  /// Tên theo ngôn ngữ đang dùng
  String get text => tr(label, labelEn);
}

/// Các cảm xúc chính hiện trong khay
const mainReactions = [
  ReactionOption('👍', 'Thích', 'Like'),
  ReactionOption('❤️', 'Yêu thích', 'Love'),
  ReactionOption('😂', 'Haha', 'Haha'),
  ReactionOption('😮', 'Wow', 'Wow'),
  ReactionOption('😢', 'Buồn', 'Sad'),
  ReactionOption('😡', 'Tức giận', 'Angry'),
];

/// Tên của một cảm xúc; icon tự chọn thì gọi chung là "Cảm xúc"
String reactionLabel(String emoji) {
  for (final r in mainReactions) {
    if (r.emoji == emoji) return r.text;
  }
  return tr('Cảm xúc', 'Reaction');
}

String formatTimeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return tr('Vừa xong', 'Just now');
  if (d.inMinutes < 60) {
    return tr('${d.inMinutes} phút trước', '${d.inMinutes} min ago');
  }
  if (d.inHours < 24) {
    return tr('${d.inHours} giờ trước', '${d.inHours} h ago');
  }
  if (d.inDays < 7) {
    return tr('${d.inDays} ngày trước', '${d.inDays} d ago');
  }
  return '${t.day}/${t.month}/${t.year}';
}

// createdAt tạm thời null ngay lúc vừa ghi, trước khi máy chủ xác nhận
DateTime _toDate(Object? ts) => ts is Timestamp ? ts.toDate() : DateTime.now();

/// Người được tag trong bình luận. uid = 'ai' nghĩa là gọi trợ lý AI.
class Mention {
  final String uid;
  final String name;

  const Mention(this.uid, this.name);

  Map<String, dynamic> toMap() => {'uid': uid, 'name': name};
}

class Comment {
  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  /// Mã bình luận gốc nếu đây là câu trả lời; rỗng nếu là bình luận gốc.
  final String parentId;
  final String replyToUid;
  final String replyToName;
  final List<Mention> mentions;
  final int reactions;
  final Map<String, int> reactionSummary;

  /// Bình luận do trợ lý AI viết; requestedBy là người đã gọi AI.
  final bool isAi;
  final String requestedBy;

  const Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.parentId = '',
    this.replyToUid = '',
    this.replyToName = '',
    this.mentions = const [],
    this.reactions = 0,
    this.reactionSummary = const {},
    this.isAi = false,
    this.requestedBy = '',
  });

  bool get isReply => parentId.isNotEmpty;

  factory Comment.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();

    final mentions = <Mention>[];
    final rawMentions = d['mentions'];
    if (rawMentions is List) {
      for (final m in rawMentions) {
        if (m is Map) {
          final uid = m['uid'];
          final name = m['name'];
          if (uid is String && name is String) mentions.add(Mention(uid, name));
        }
      }
    }

    final summary = <String, int>{};
    final rawSummary = d['reactionSummary'];
    if (rawSummary is Map) {
      rawSummary.forEach((k, v) {
        final n = (v as num?)?.toInt() ?? 0;
        if (n > 0) summary[k.toString()] = n;
      });
    }

    return Comment(
      id: doc.id,
      authorId: d['authorId'] as String? ?? '',
      authorName: d['authorName'] as String? ?? tr('Người dùng', 'User'),
      text: d['text'] as String? ?? '',
      createdAt: _toDate(d['createdAt']),
      parentId: d['parentId'] as String? ?? '',
      replyToUid: d['replyToUid'] as String? ?? '',
      replyToName: d['replyToName'] as String? ?? '',
      mentions: mentions,
      reactions: (d['reactions'] as num?)?.toInt() ?? 0,
      reactionSummary: summary,
      isAi: d['isAi'] as bool? ?? false,
      requestedBy: d['requestedBy'] as String? ?? '',
    );
  }
}

class AppNotification {
  final String id;
  final String type;
  final String fromUserId;
  final String fromName;
  final String postId;
  final String preview;
  final String emoji;
  final int count;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.fromUserId,
    required this.fromName,
    required this.postId,
    required this.preview,
    required this.emoji,
    required this.count,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final d = doc.data();
    return AppNotification(
      id: doc.id,
      type: d['type'] as String? ?? '',
      fromUserId: d['fromUserId'] as String? ?? '',
      fromName: d['fromName'] as String? ?? tr('Ai đó', 'Someone'),
      postId: d['postId'] as String? ?? '',
      preview: d['preview'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '',
      count: (d['count'] as num?)?.toInt() ?? 0,
      read: d['read'] as bool? ?? false,
      createdAt: _toDate(d['createdAt']),
    );
  }

  String get icon {
    switch (type) {
      case 'reaction':
      case 'comment_reaction':
        return emoji.isNotEmpty ? emoji : '👍';
      case 'comment':
        return '💬';
      case 'reply':
        return '↩️';
      case 'mention':
        return '@';
      case 'milestone':
        return '🎉';
      case 'post_created':
        return '✅';
      case 'friend_request':
        return '🙋';
      case 'friend_accepted':
        return '🤝';
      case 'feedback':
        return '📝';
      default:
        return '🔔';
    }
  }

  String get message {
    switch (type) {
      case 'reaction':
        return tr(
          '$fromName đã bày tỏ cảm xúc $icon về bài viết của bạn',
          '$fromName reacted $icon to your post',
        );
      case 'comment_reaction':
        return tr(
          '$fromName đã bày tỏ cảm xúc $icon về bình luận của bạn',
          '$fromName reacted $icon to your comment',
        );
      case 'comment':
        return tr(
          '$fromName đã bình luận: "$preview"',
          '$fromName commented: "$preview"',
        );
      case 'reply':
        return tr(
          '$fromName đã trả lời bình luận của bạn: "$preview"',
          '$fromName replied to your comment: "$preview"',
        );
      case 'mention':
        return tr(
          '$fromName đã nhắc đến bạn trong một bình luận: "$preview"',
          '$fromName mentioned you in a comment: "$preview"',
        );
      case 'milestone':
        return tr(
          'Bài viết của bạn đã đạt $count lượt tương tác!',
          'Your post reached $count interactions!',
        );
      case 'post_created':
        return tr(
          'Bài viết của bạn đã được đăng thành công',
          'Your post was published successfully',
        );
      case 'friend_request':
        return tr(
          '$fromName đã gửi cho bạn lời mời kết bạn',
          '$fromName sent you a friend request',
        );
      case 'friend_accepted':
        return tr(
          '$fromName đã chấp nhận lời mời kết bạn của bạn',
          '$fromName accepted your friend request',
        );
      case 'feedback':
        return tr(
          '$fromName đã góp ý về bài viết của bạn',
          '$fromName left feedback on your post',
        );
      default:
        return tr('Bạn có thông báo mới', 'You have a new notification');
    }
  }
}