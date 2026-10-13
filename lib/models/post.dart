import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/l10n.dart';

/// Một lựa chọn của bình chọn trong bài.
class PollOption {
  final String id;
  final String text;

  const PollOption(this.id, this.text);
}

class Post {
  final String id;

  /// 'posts' (công khai), 'friend_posts' (bạn bè hoặc chỉ mình tôi)
  /// hoặc 'capsules' (hộp thời gian)
  final String collection;

  /// Đối tượng xem: 'public', 'friends' hoặc 'me'
  final String visibility;
  final String authorId;
  final String authorName;
  final String spaceId;
  final String text; // phần chữ của bài (dùng cho xem trước, thông báo)
  final List<Map<String, dynamic>> blocks; // các khối nội dung
  final int reactions;
  final int comments;
  final Map<String, int> reactionSummary; // emoji -> số người
  final DateTime createdAt;

  /// Rẽ nhánh: id bài gốc và tên tác giả bài gốc (null nếu không phải nhánh)
  final String? forkedFrom;
  final String? forkedFromAuthor;

  /// Bài sống: số bản cập nhật và thời điểm cập nhật gần nhất
  /// (tính cả mục hệ thống tự sinh, chỉ tác giả thấy số này)
  final int updateCount;
  final DateTime? lastUpdateAt;

  /// Bài sống: chỉ tính các cập nhật tác giả tự viết (người khác thấy số này)
  final int publicUpdateCount;
  final DateTime? lastPublicUpdateAt;

  /// Bài tự hết hạn: sau thời điểm này chỉ tác giả còn thấy bài (null = không)
  final DateTime? expiresAt;

  /// Ghim lên đầu hồ sơ: thời điểm ghim (null = không ghim)
  final DateTime? pinnedAt;

  /// Tên những người có đề xuất sửa đã được tác giả nhận
  final List<String> contributors;

  /// Bài hỏi đáp: đăng như một câu hỏi, tác giả chọn bình luận làm đáp án.
  final bool isQuestion;

  /// Id bình luận được chọn làm đáp án (null = chưa chọn).
  final String? acceptedCommentId;

  /// Uid người viết đáp án được chọn, dùng để tính điểm đóng góp
  /// (null hoặc rỗng = chưa chọn, hoặc đáp án của AI, hoặc bài không công khai).
  final String? acceptedAuthorId;

  /// Bình chọn đính kèm bài (rỗng = bài không có bình chọn).
  final List<PollOption> pollOptions;

  /// Cho chọn nhiều đáp án trong bình chọn.
  final bool pollMultiple;

  const Post({
    required this.id,
    this.collection = 'posts',
    this.visibility = 'public',
    required this.authorId,
    required this.authorName,
    required this.spaceId,
    required this.text,
    required this.blocks,
    required this.reactions,
    required this.comments,
    required this.reactionSummary,
    required this.createdAt,
    this.forkedFrom,
    this.forkedFromAuthor,
    this.updateCount = 0,
    this.lastUpdateAt,
    this.publicUpdateCount = 0,
    this.lastPublicUpdateAt,
    this.expiresAt,
    this.pinnedAt,
    this.contributors = const <String>[],
    this.isQuestion = false,
    this.acceptedCommentId,
    this.acceptedAuthorId,
    this.pollOptions = const <PollOption>[],
    this.pollMultiple = false,
  });

  /// Bài không công khai (bạn bè hoặc chỉ mình tôi).
  bool get friendsOnly => collection == 'friend_posts';

  /// Đang được ghim lên đầu hồ sơ.
  bool get isPinned => pinnedAt != null;

  /// Đã quá hạn tự ẩn.
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Câu hỏi đã có đáp án được chọn.
  bool get hasAcceptedAnswer =>
      acceptedCommentId != null && acceptedCommentId!.isNotEmpty;

  /// Bài có bình chọn (cần ít nhất hai lựa chọn).
  bool get hasPoll => pollOptions.length >= 2;

  /// Tham chiếu tới tài liệu của bài viết (đúng collection).
  DocumentReference<Map<String, dynamic>> get ref =>
      FirebaseFirestore.instance.collection(collection).doc(id);

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final ts = d['createdAt'];
    final lu = d['lastUpdateAt'];
    final lpu = d['lastPublicUpdateAt'];
    final ex = d['expiresAt'];
    final pa = d['pinnedAt'];
    final col = doc.reference.parent.id;

    final summary = <String, int>{};
    final rawSummary = d['reactionSummary'];
    if (rawSummary is Map) {
      rawSummary.forEach((k, v) {
        final n = (v as num?)?.toInt() ?? 0;
        if (n > 0) summary[k.toString()] = n;
      });
    }

    final blocks = <Map<String, dynamic>>[];
    final rawBlocks = d['blocks'];
    if (rawBlocks is List) {
      for (final b in rawBlocks) {
        if (b is Map) blocks.add(Map<String, dynamic>.from(b));
      }
    }
    // Bài cũ chưa có khối: coi phần chữ là một khối chữ
    if (blocks.isEmpty && (d['text'] as String? ?? '').trim().isNotEmpty) {
      blocks.add({'type': 'text', 'text': d['text'] as String});
    }

    final contributors = <String>[];
    final rawContrib = d['contributors'];
    if (rawContrib is List) {
      for (final c in rawContrib) {
        contributors.add(c.toString());
      }
    }

    final updateCount = (d['updateCount'] as num?)?.toInt() ?? 0;

    // Chuỗi rỗng và null đều nghĩa là "chưa có đáp án"
    final rawAccepted = d['acceptedCommentId'];
    final accepted =
    (rawAccepted is String && rawAccepted.isNotEmpty) ? rawAccepted : null;
    final rawAcceptedAuthor = d['acceptedAuthorId'];
    final acceptedAuthor =
    (rawAcceptedAuthor is String && rawAcceptedAuthor.isNotEmpty)
        ? rawAcceptedAuthor
        : null;

    final pollOptions = <PollOption>[];
    final rawPoll = d['pollOptions'];
    if (rawPoll is List) {
      for (final o in rawPoll) {
        if (o is Map) {
          final id = o['id'];
          final t = o['text'];
          if (id is String && t is String) pollOptions.add(PollOption(id, t));
        }
      }
    }

    return Post(
      id: doc.id,
      collection: col,
      visibility: col == 'posts'
          ? 'public'
          : (d['visibility'] as String? ?? 'friends'),
      authorId: d['authorId'] as String? ?? '',
      authorName: d['authorName'] as String? ?? msgUser,
      spaceId: d['spaceId'] as String? ?? '',
      text: d['text'] as String? ?? '',
      blocks: blocks,
      reactions: (d['reactions'] as num?)?.toInt() ?? 0,
      comments: (d['comments'] as num?)?.toInt() ?? 0,
      reactionSummary: summary,
      // createdAt tạm thời null ngay lúc vừa đăng, trước khi máy chủ xác nhận
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      forkedFrom: d['forkedFrom'] as String?,
      forkedFromAuthor: d['forkedFromAuthor'] as String?,
      updateCount: updateCount,
      lastUpdateAt: lu is Timestamp ? lu.toDate() : null,
      // Bài cũ chưa có trường công khai: dùng tạm số tổng để không mất khung
      publicUpdateCount:
      (d['publicUpdateCount'] as num?)?.toInt() ?? updateCount,
      lastPublicUpdateAt: lpu is Timestamp
          ? lpu.toDate()
          : (lu is Timestamp ? lu.toDate() : null),
      expiresAt: ex is Timestamp ? ex.toDate() : null,
      pinnedAt: pa is Timestamp ? pa.toDate() : null,
      contributors: contributors,
      isQuestion: d['isQuestion'] == true,
      acceptedCommentId: accepted,
      acceptedAuthorId: acceptedAuthor,
      pollOptions: pollOptions,
      pollMultiple: d['pollMultiple'] == true,
    );
  }
}