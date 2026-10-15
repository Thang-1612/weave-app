import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/story_models.dart';

/// Cấu trúc Firestore (mỗi document nhỏ hơn 1 MiB, hợp gói Spark):
///   stories/{id}                 thông tin chung + collaboratorIds
///   stories/{id}/sources/{sid}   tư liệu gốc (ảnh base64 đã nén, ghi chú)
///   stories/{id}/blocks/{bid}    từng khối của câu chuyện
class StoryService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('stories');

  static String get uid => FirebaseAuth.instance.currentUser!.uid;

  /// Lưu câu chuyện AI vừa dựng cùng tư liệu gốc. Trả về id câu chuyện.
  static Future<String> createFromDraft({
    required StoryKind kind,
    required StoryDraft draft,
    required List<StorySource> sources,
  }) async {
    final ref = _col.doc();
    final batch = _db.batch();

    batch.set(ref, {
      'ownerId': uid,
      'title': draft.title,
      'kind': kind.name,
      'mood': draft.mood,
      'layout': draft.layout,
      'collaboratorIds': [uid],
      'missing': draft.missing,
      'droppedCount': draft.dropped,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final s in sources) {
      batch.set(ref.collection('sources').doc(s.id), s.toMap());
    }
    for (final b in draft.blocks) {
      batch.set(ref.collection('blocks').doc(), b.toMap());
    }
    await batch.commit();
    return ref.id;
  }

  static Stream<Story?> story(String id) => _col
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Story.fromDoc(d) : null);

  static Stream<List<StoryBlock>> blocks(String id) => _col
      .doc(id)
      .collection('blocks')
      .orderBy('order')
      .snapshots()
      .map((q) => [for (final d in q.docs) StoryBlock.fromMap(d.id, d.data())]);

  static Stream<Map<String, StorySource>> sources(String id) => _col
      .doc(id)
      .collection('sources')
      .snapshots()
      .map((q) => {
    for (final d in q.docs) d.id: StorySource.fromMap(d.id, d.data()),
  });

  /// Câu chuyện của tôi và câu chuyện bạn bè mời tôi cùng sửa.
  /// Sắp xếp phía app để khỏi cần tạo chỉ mục Firestore.
  static Stream<List<Story>> myStories() => _col
      .where('collaboratorIds', arrayContains: uid)
      .snapshots()
      .map((q) {
    final list = [for (final d in q.docs) Story.fromDoc(d)];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  });

  static Future<void> _touch(String storyId) =>
      _col.doc(storyId).update({'updatedAt': FieldValue.serverTimestamp()});

  /// Người dùng sửa một khối: khối không còn là "AI viết" nữa.
  static Future<void> updateBlockText(
      String storyId,
      String blockId,
      String text,
      ) async {
    await _col.doc(storyId).collection('blocks').doc(blockId).update({
      'text': text.trim(),
      'aiGenerated': false,
      'lastEditedBy': uid,
    });
    await _touch(storyId);
  }

  /// Thêm đoạn do người dùng tự viết (không cần nguồn).
  static Future<void> addUserBlock(
      String storyId,
      String text,
      int lastOrder,
      ) async {
    await _col.doc(storyId).collection('blocks').add(StoryBlock(
      id: '',
      type: kBlockNarration,
      text: text.trim(),
      sourceIds: const [],
      aiGenerated: false,
      lastEditedBy: uid,
      order: lastOrder + 1000,
    ).toMap());
    await _touch(storyId);
  }

  static Future<void> deleteBlock(String storyId, String blockId) async {
    await _col.doc(storyId).collection('blocks').doc(blockId).delete();
    await _touch(storyId);
  }

  static Future<void> addCollaborator(String storyId, String friendUid) =>
      _col.doc(storyId).update({
        'collaboratorIds': FieldValue.arrayUnion([friendUid]),
      });

  static Future<void> deleteStory(String storyId) async {
    final ref = _col.doc(storyId);
    for (final sub in ['blocks', 'sources']) {
      final snap = await ref.collection(sub).get();
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await ref.delete();
  }
}

/* Firestore rules (dán vào firestore.rules, trong match /databases/{db}/documents):

match /stories/{sid} {
  function isMember() {
    return request.auth != null &&
      request.auth.uid in get(/databases/$(database)/documents/stories/$(sid)).data.collaboratorIds;
  }
  allow read: if request.auth != null && request.auth.uid in resource.data.collaboratorIds;
  allow create: if request.auth != null
    && request.resource.data.ownerId == request.auth.uid
    && request.auth.uid in request.resource.data.collaboratorIds;
  // Chỉ chủ câu chuyện được đổi danh sách cộng tác và chủ sở hữu.
  allow update: if request.auth != null
    && request.auth.uid in resource.data.collaboratorIds
    && request.resource.data.ownerId == resource.data.ownerId
    && (request.resource.data.collaboratorIds == resource.data.collaboratorIds
        || request.auth.uid == resource.data.ownerId);
  allow delete: if request.auth != null && request.auth.uid == resource.data.ownerId;

  match /blocks/{bid} { allow read, write: if isMember(); }
  match /sources/{sid2} { allow read, write: if isMember(); }
}
*/