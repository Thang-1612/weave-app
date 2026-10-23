import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post.dart';
import 'l10n.dart';
import 'post_service.dart';
import 'social_extras_service.dart';
import 'version_service.dart';

class Proposal {
  final String id; // = id bài nhánh
  final String fromUserId;
  final String fromName;
  final String forkId;
  final String originalId;
  final String note;
  final DateTime createdAt;
  const Proposal({
    required this.id,
    required this.fromUserId,
    required this.fromName,
    required this.forkId,
    required this.originalId,
    required this.note,
    required this.createdAt,
  });
}

/// Đề xuất sửa bài gốc: người rẽ nhánh gửi bài nhánh của mình cho tác giả
/// bài gốc. Tác giả xem so sánh rồi nhận hoặc từ chối, và người gửi nhận được
/// kết quả ngay trên bài nhánh của họ. Nếu bài gốc là của chính mình thì
/// gộp thẳng nhánh vào bài gốc.
class ProposalService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _db.collection('users').doc(uid).collection('proposals_inbox');

  static CollectionReference<Map<String, dynamic>> _results(String uid) =>
      _db.collection('users').doc(uid).collection('proposal_results');

  static String _myName(User me) {
    final n = me.displayName?.trim() ?? '';
    return n.isNotEmpty ? n : (me.email ?? tr('Người dùng', 'User'));
  }

  static Future<void> send(Post fork, String note) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);
    final originalId = fork.forkedFrom;
    if (originalId == null ||
        fork.authorId != me.uid ||
        fork.collection != 'posts') {
      throw Exception(
        tr(
          'Không gửi được đề xuất cho bài này',
          'Cannot send a proposal for this post',
        ),
      );
    }
    final original = await PostService.getPost(originalId);
    if (original == null) {
      throw Exception(
        tr('Bài gốc không còn tồn tại', 'The original post is gone'),
      );
    }
    if (original.authorId == me.uid) {
      throw Exception(
        tr('Bài gốc là của chính bạn', 'The original is your own post'),
      );
    }
    await _inbox(original.authorId).doc(fork.id).set({
      'fromUserId': me.uid,
      'fromName': _myName(me),
      'forkId': fork.id,
      'originalId': originalId,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Gửi lại thì xóa kết quả cũ để trạng thái bắt đầu lại
    try {
      await _results(me.uid).doc(fork.id).delete();
    } catch (_) {}
  }

  /// Bài nhánh và bài gốc cùng của một người: gộp thẳng nhánh vào bài gốc.
  /// Bản cũ của bài gốc được lưu vào lịch sử phiên bản nên khôi phục được.
  static Future<void> mergeIntoOriginal(Post fork) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);
    final originalId = fork.forkedFrom;
    if (originalId == null || fork.authorId != me.uid) {
      throw Exception(tr('Không gộp được bài này', 'Cannot merge this post'));
    }
    final original = await PostService.getPost(originalId);
    if (original == null) {
      throw Exception(
        tr('Bài gốc không còn tồn tại', 'The original post is gone'),
      );
    }
    if (original.authorId != me.uid) {
      throw Exception(
        tr('Bài gốc không phải của bạn', 'The original is not your post'),
      );
    }
    await VersionService.snapshot(
      original,
      tr(
        'Trước khi gộp một nhánh của chính bạn',
        'Before merging one of your own forks',
      ),
    );
    await original.ref.update({'blocks': fork.blocks, 'text': fork.text});
    // Mục tự sinh: chỉ tác giả thấy
    await LivePostService.addSystemUpdate(
      original,
      tr(
        'Nội dung được cập nhật từ một nhánh của tác giả',
        'Content updated from one of the author\'s own forks',
      ),
      'merge',
    );
  }

  static Future<List<Proposal>> loadMine() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final s = await _inbox(uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return s.docs.map((d) {
      final m = d.data();
      final ts = m['createdAt'];
      return Proposal(
        id: d.id,
        fromUserId: m['fromUserId'] as String? ?? '',
        fromName: m['fromName'] as String? ?? '',
        forkId: m['forkId'] as String? ?? '',
        originalId: m['originalId'] as String? ?? '',
        note: m['note'] as String? ?? '',
        createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      );
    }).toList();
  }

  /// Báo kết quả cho người gửi. Lỗi ở bước này không chặn việc nhận hoặc từ chối.
  static Future<void> _writeResult(Proposal p, String status) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || p.fromUserId.isEmpty) return;
    try {
      await _results(p.fromUserId).doc(p.forkId).set({
        'status': status, // accepted hoặc declined
        'byUserId': me.uid,
        'byName': _myName(me),
        'originalId': p.originalId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<void> decline(Proposal p) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _writeResult(p, 'declined');
    await _inbox(uid).doc(p.id).delete();
  }

  /// Nhận đề xuất: lưu phiên bản cũ của bài gốc, thay nội dung bằng bản đề
  /// xuất, ghi người đóng góp, thêm một dòng (chỉ tác giả thấy) vào dòng thời
  /// gian bài sống và báo kết quả cho người gửi.
  static Future<void> accept(Proposal p) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception(msgNotSignedIn);
    final fork = await PostService.getPost(p.forkId);
    final original = await PostService.getPost(p.originalId);
    if (fork == null || original == null) {
      throw Exception(
        tr(
          'Bài nhánh hoặc bài gốc không còn tồn tại',
          'The fork or the original post no longer exists',
        ),
      );
    }
    if (original.authorId != me.uid) {
      throw Exception(
        tr(
          'Chỉ tác giả bài gốc mới nhận được đề xuất',
          'Only the original author can accept a proposal',
        ),
      );
    }

    // Giữ lại bản trước khi bị ghi đè để có thể khôi phục
    await VersionService.snapshot(
      original,
      tr(
        'Trước khi nhận đề xuất của ${p.fromName}',
        'Before accepting the proposal from ${p.fromName}',
      ),
    );

    await original.ref.update({
      'blocks': fork.blocks,
      'text': fork.text,
      'contributors': FieldValue.arrayUnion([p.fromName]),
      'contributorIds': FieldValue.arrayUnion([p.fromUserId]),
    });
    await LivePostService.addSystemUpdate(
      original,
      tr(
        'Nội dung được cập nhật theo đề xuất của ${p.fromName}',
        'Content updated from a proposal by ${p.fromName}',
      ),
      'proposal',
    );
    await _writeResult(p, 'accepted');
    await _inbox(me.uid).doc(p.id).delete();
  }
}
