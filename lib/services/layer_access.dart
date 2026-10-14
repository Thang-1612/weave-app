import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/weave_layer.dart';

/// Quyền xem của MỘT người xem đối với các lớp của MỘT tác giả.
///
/// Đây chỉ để giao diện biết nên hiện/ẩn gì và tránh gọi thừa.
/// Nguồn sự thật vẫn là firestore.rules.
class LayerAccess {
  final String viewerId;
  final String authorId;
  final bool isFriend;
  final bool isCloseFriend;
  final Set<String> groupIds;

  const LayerAccess({
    required this.viewerId,
    required this.authorId,
    this.isFriend = false,
    this.isCloseFriend = false,
    this.groupIds = const <String>{},
  });

  bool get isAuthor => viewerId == authorId;

  bool canView(String audienceType, String? groupId) {
    if (isAuthor) return true;
    switch (audienceType) {
      case LayerAudience.kPublic:
        return true;
      case LayerAudience.kFriends:
        return isFriend || isCloseFriend;
      case LayerAudience.kClose:
        return isCloseFriend;
      case LayerAudience.kGroup:
        return groupId != null && groupIds.contains(groupId);
      default: // 'me' và mọi giá trị lạ
        return false;
    }
  }

  bool canViewMeta(LayerMeta m) => canView(m.audienceType, m.groupId);

  /// Nạp quyền của người xem.
  ///
  /// [isFriend]: hàm kiểm tra bạn bè, truyền từ FriendService của bạn
  /// (mình chưa thấy file đó nên không đoán).
  static Future<LayerAccess> load({
    required String viewerId,
    required String authorId,
    required Future<bool> Function(String authorId) isFriend,
  }) async {
    if (viewerId == authorId) {
      return LayerAccess(viewerId: viewerId, authorId: authorId);
    }
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      isFriend(authorId),
      // Danh sách bạn thân của tác giả: users/{authorId}/closeFriends/{viewerId}
      db
          .collection('users')
          .doc(authorId)
          .collection('closeFriends')
          .doc(viewerId)
          .get()
          .then((s) => s.exists)
          .catchError((_) => false),
      // Các nhóm người xem đang tham gia: groups/{id}.memberIds
      db
          .collection('groups')
          .where('memberIds', arrayContains: viewerId)
          .get()
          .then((q) => q.docs.map((d) => d.id).toSet())
          .catchError((_) => <String>{}),
    ]);
    return LayerAccess(
      viewerId: viewerId,
      authorId: authorId,
      isFriend: results[0] as bool,
      isCloseFriend: results[1] as bool,
      groupIds: results[2] as Set<String>,
    );
  }
}