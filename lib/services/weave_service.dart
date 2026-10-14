import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../models/weave_activity.dart';
import '../models/weave_poll.dart';
import 'l10n.dart';

/// weave_activities/{id}                -> WeaveActivity
/// weave_activities/{id}/members/{uid}  -> WeaveMember
class WeaveService {
  WeaveService._();

  static final _col =
  FirebaseFirestore.instance.collection('weave_activities');

  static CollectionReference<Map<String, dynamic>> _members(String id) =>
      _col.doc(id).collection('members');

  static String get me {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('msgNotSignedIn');
    return uid;
  }

  // ---------------------------------------------------------------- create

  /// Host = người đang đăng nhập. Người được mời có RSVP = pending.
  static Future<WeaveActivity> create({
    required String groupId,
    required String title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    List<String> inviteeIds = const [],
  }) async {
    final host = me;
    final ref = _col.doc();
    final memberIds = <String>{host, ...inviteeIds}.toList();

    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      ref,
      WeaveActivity(
        id: ref.id,
        groupId: groupId,
        hostId: host,
        title: title.trim(),
        description: (description ?? '').trim().isEmpty
            ? null
            : description!.trim(),
        status: WeaveStatus.planning,
        startAt: startAt,
        endAt: endAt,
        memberIds: memberIds,
        createdAt: DateTime.now(),
      ).toMap(),
    );
    for (final uid in memberIds) {
      final isHost = uid == host;
      batch.set(
        _members(ref.id).doc(uid),
        WeaveMember(
          userId: uid,
          role: isHost ? WeaveRole.host : WeaveRole.member,
          rsvp: isHost ? RsvpStatus.going : RsvpStatus.pending,
          joinedAt: DateTime.now(),
        ).toMap(),
      );
    }
    await batch.commit();
    return WeaveActivity.fromDoc(await ref.get());
  }

  // ------------------------------------------------------------------ read

  static Stream<WeaveActivity?> watchOne(String id) => _col
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? WeaveActivity.fromDoc(d) : null);

  /// Sắp xếp phía client để khỏi tạo composite index.
  static Stream<List<WeaveActivity>> watchGroup(String groupId) => _col
      .where('groupId', isEqualTo: groupId)
      .where('memberIds', arrayContains: me)
      .snapshots()
      .map(_sorted);

  static Stream<List<WeaveActivity>> watchMine() =>
      _col.where('memberIds', arrayContains: me).snapshots().map(_sorted);

  static List<WeaveActivity> _sorted(
      QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(WeaveActivity.fromDoc).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Stream<List<WeaveMember>> watchMembers(String activityId) =>
      _members(activityId).snapshots().map((s) {
        final list = s.docs.map(WeaveMember.fromDoc).toList()
          ..sort((a, b) {
            if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
            return a.joinedAt.compareTo(b.joinedAt);
          });
        return list;
      });

  // ---------------------------------------------------------------- update

  static Future<void> updateRsvp(String activityId, RsvpStatus status) =>
      _members(activityId).doc(me).update({'rsvp': status.name});

  static Future<void> start(String activityId) =>
      _col.doc(activityId).update({
        'status': WeaveStatus.active.name,
        'startAt': FieldValue.serverTimestamp(),
      });

  /// Cloud Function lắng nghe status = ended để tạo nhật ký.
  static Future<void> end(String activityId) => _col.doc(activityId).update({
    'status': WeaveStatus.ended.name,
    'endAt': FieldValue.serverTimestamp(),
  });

  /// Gọi bởi weave_poll_service khi chốt poll.
  static Future<void> lockPlace(String activityId, WeavePlace place) =>
      _col.doc(activityId).update({'lockedPlace': place.toMap()});

  static Future<void> lockDate(String activityId, DateTime date) =>
      _col.doc(activityId).update({'lockedDate': Timestamp.fromDate(date)});

  static Future<void> invite(String activityId, List<String> userIds) async {
    if (userIds.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_col.doc(activityId),
        {'memberIds': FieldValue.arrayUnion(userIds)});
    for (final uid in userIds) {
      batch.set(
        _members(activityId).doc(uid),
        WeaveMember(
          userId: uid,
          role: WeaveRole.member,
          rsvp: RsvpStatus.pending,
          joinedAt: DateTime.now(),
        ).toMap(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  static Future<void> leave(String activityId) async {
    final uid = me;
    final doc = await _col.doc(activityId).get();
    if (!doc.exists) return;
    if (WeaveActivity.fromDoc(doc).hostId == uid) {
      throw Exception(tr(
        'Chủ hoạt động không thể rời. Hãy kết thúc hoạt động.',
        'The host cannot leave. End the activity instead.',
      ));
    }
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_col.doc(activityId), {
      'memberIds': FieldValue.arrayRemove([uid])
    });
    batch.delete(_members(activityId).doc(uid));
    await batch.commit();
  }

  static Future<void> delete(String activityId) =>
      _col.doc(activityId).delete();

  // -------------------------------------------------------------- profiles

  static final Map<String, UserProfile> _profiles = {};
  static final Map<String, Future<UserProfile?>> _profileFutures = {};

  static UserProfile? cachedProfile(String uid) => _profiles[uid];

  static Future<UserProfile?> profileOf(String uid) {
    final existing = _profileFutures[uid];
    if (existing != null) return existing;
    final f = _fetchProfile(uid);
    _profileFutures[uid] = f;
    return f;
  }

  static Future<UserProfile?> _fetchProfile(String uid) async {
    try {
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final p = UserProfile.fromMap(uid, doc.data()!);
      _profiles[uid] = p;
      return p;
    } catch (_) {
      _profileFutures.remove(uid);
      return null;
    }
  }

  // ----------------------------------------------------------------- polls

  static CollectionReference<Map<String, dynamic>> _polls(String aid) =>
      _col.doc(aid).collection('polls');

  static CollectionReference<Map<String, dynamic>> _votes(
      String aid, String pid) =>
      _polls(aid).doc(pid).collection('votes');

  static Future<void> createPoll(
      String activityId, {
        required PollKind kind,
        required String question,
        required List<WeavePollOption> options,
        bool multi = false,
        DateTime? closesAt,
      }) {
    final ref = _polls(activityId).doc();
    return ref.set(WeavePoll(
      id: ref.id,
      kind: kind,
      question: question.trim(),
      options: options,
      multi: multi,
      closesAt: closesAt,
      createdBy: me,
      createdAt: DateTime.now(),
    ).toMap());
  }

  static Stream<List<WeavePoll>> watchPolls(String activityId) =>
      _polls(activityId).snapshots().map((s) {
        final list = s.docs.map(WeavePoll.fromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  static Stream<List<WeaveVote>> watchVotes(String activityId, String pollId) =>
      _votes(activityId, pollId)
          .snapshots()
          .map((s) => s.docs.map(WeaveVote.fromDoc).toList());

  /// Ghi đè phiếu của tôi. Danh sách rỗng = bỏ phiếu.
  static Future<void> vote(
      String activityId, String pollId, List<String> optionIds) =>
      _votes(activityId, pollId).doc(me).set({
        'optionIds': optionIds,
        'at': FieldValue.serverTimestamp(),
      });

  /// Chủ hoạt động chốt poll: lưu người thắng và khóa địa điểm/ngày cho hoạt động.
  static Future<void> closePoll(String activityId, WeavePoll poll) async {
    final snap = await _votes(activityId, poll.id).get();
    final winner =
    weaveLeader(poll, snap.docs.map(WeaveVote.fromDoc).toList());

    final batch = FirebaseFirestore.instance.batch();
    batch.update(_polls(activityId).doc(poll.id),
        {'closed': true, 'winnerOptionId': winner});

    if (winner != null) {
      final o = poll.options.firstWhere((o) => o.id == winner);
      if (poll.kind == PollKind.place) {
        batch.update(_col.doc(activityId), {
          'lockedPlace': WeavePlace(
              name: o.label, address: o.address, lat: o.lat, lng: o.lng)
              .toMap(),
        });
      } else if (o.date != null) {
        batch.update(_col.doc(activityId),
            {'lockedDate': Timestamp.fromDate(o.date!)});
      }
    }
    await batch.commit();
  }

  static Future<void> deletePoll(String activityId, String pollId) =>
      _polls(activityId).doc(pollId).delete();
}