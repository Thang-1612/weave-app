import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Nhóm riêng: groups/{id} gồm name, ownerId, memberIds[].
class GroupInfo {
  final String id;
  final String name;
  final String ownerId;
  final List<String> memberIds;

  const GroupInfo({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
  });

  factory GroupInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return GroupInfo(
      id: doc.id,
      name: d['name'] as String? ?? '',
      ownerId: d['ownerId'] as String? ?? '',
      memberIds: List<String>.from(d['memberIds'] as List? ?? const []),
    );
  }
}

class GroupService {
  GroupService._();

  static final _col = FirebaseFirestore.instance.collection('groups');

  /// Bộ nhớ tạm id -> tên nhóm, để giao diện hiện tên mà không phải tải lại.
  static final Map<String, String> _names = {};

  static String? nameOf(String? id) => id == null ? null : _names[id];

  static String get _me {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('msgNotSignedIn');
    return uid;
  }

  /// Các nhóm tôi đang tham gia.
  static Future<List<GroupInfo>> listMine() async {
    final q = await _col.where('memberIds', arrayContains: _me).get();
    final groups = q.docs.map(GroupInfo.fromDoc).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final g in groups) {
      _names[g.id] = g.name;
    }
    return groups;
  }

  static Future<GroupInfo> create(String name) async {
    final me = _me;
    final ref = _col.doc();
    final clean = name.trim();
    await ref.set({
      'name': clean,
      'ownerId': me,
      'memberIds': [me],
      'createdAt': FieldValue.serverTimestamp(),
    });
    _names[ref.id] = clean;
    return GroupInfo(id: ref.id, name: clean, ownerId: me, memberIds: [me]);
  }

  /// Tạo nhóm rồi thêm luôn các thành viên đã chọn (luật Firestore chỉ cho
  /// tạo nhóm với một mình chủ nhóm, nên thêm người ở bước cập nhật sau đó).
  static Future<GroupInfo> createWithMembers(
      String name, List<String> uids) async {
    final g = await create(name);
    final others = uids.where((u) => u != g.ownerId).toSet().toList();
    final added = <String>[];
    for (final u in others) {
      try {
        await _col.doc(g.id).update({
          'memberIds': FieldValue.arrayUnion([u]),
        });
        added.add(u);
      } catch (_) {
        // không phải bạn bè hoặc lỗi mạng: bỏ qua người này
      }
    }
    return GroupInfo(
        id: g.id, name: g.name, ownerId: g.ownerId, memberIds: [g.ownerId, ...added]);
  }

  static Future<void> addMember(String groupId, String uid) =>
      _col.doc(groupId).update({
        'memberIds': FieldValue.arrayUnion([uid]),
      });

  static Future<void> removeMember(String groupId, String uid) =>
      _col.doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([uid]),
      });
}