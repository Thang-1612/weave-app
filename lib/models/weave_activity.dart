import 'package:cloud_firestore/cloud_firestore.dart';

enum WeaveStatus { planning, active, ended }

class WeavePlace {
  final String name;
  final String? address;
  final double? lat;
  final double? lng;

  const WeavePlace({required this.name, this.lat, this.lng, this.address});

  factory WeavePlace.fromMap(Map<String, dynamic> m) => WeavePlace(
    name: m['name'] as String,
    address: m['address'] as String?,
    lat: (m['lat'] as num?)?.toDouble(),
    lng: (m['lng'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'lat': lat,
    'lng': lng,
  };
}

class WeaveActivity {
  final String id;
  final String groupId;
  final String hostId;
  final String title;
  final String? description;
  final String? coverUrl;
  final WeaveStatus status;

  /// Khoảng thời gian dự kiến / thực tế của hoạt động.
  final DateTime? startAt;
  final DateTime? endAt;

  /// Kết quả sau khi chốt poll (null nếu chưa chốt).
  final DateTime? lockedDate;
  final WeavePlace? lockedPlace;

  /// Dùng cho query "hoạt động của tôi" (array-contains).
  final List<String> memberIds;
  final DateTime createdAt;

  const WeaveActivity({
    required this.id,
    required this.groupId,
    required this.hostId,
    required this.title,
    required this.status,
    required this.memberIds,
    required this.createdAt,
    this.description,
    this.coverUrl,
    this.startAt,
    this.endAt,
    this.lockedDate,
    this.lockedPlace,
  });

  bool get isEnded => status == WeaveStatus.ended;
  bool get isActive => status == WeaveStatus.active;

  factory WeaveActivity.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    DateTime? ts(String k) => (d[k] as Timestamp?)?.toDate();
    return WeaveActivity(
      id: doc.id,
      groupId: d['groupId'] as String,
      hostId: d['hostId'] as String,
      title: d['title'] as String,
      description: d['description'] as String?,
      coverUrl: d['coverUrl'] as String?,
      status: WeaveStatus.values.byName(d['status'] as String? ?? 'planning'),
      startAt: ts('startAt'),
      endAt: ts('endAt'),
      lockedDate: ts('lockedDate'),
      lockedPlace: d['lockedPlace'] == null
          ? null
          : WeavePlace.fromMap(
              Map<String, dynamic>.from(d['lockedPlace'] as Map),
            ),
      memberIds: List<String>.from(d['memberIds'] as List? ?? const []),
      // createdAt có thể null trong lúc serverTimestamp chưa được ghi xong
      createdAt: ts('createdAt') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'hostId': hostId,
    'title': title,
    'description': description,
    'coverUrl': coverUrl,
    'status': status.name,
    'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
    'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
    'lockedDate': lockedDate == null ? null : Timestamp.fromDate(lockedDate!),
    'lockedPlace': lockedPlace?.toMap(),
    'memberIds': memberIds,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

// ----------------------------------------------------------- Member
// weave_activities/{id}/members/{uid}

enum WeaveRole { host, member }

/// pending = mới được mời, chưa phản hồi
enum RsvpStatus { pending, going, maybe, no }

class WeaveMember {
  final String userId;
  final WeaveRole role;
  final RsvpStatus rsvp;
  final DateTime joinedAt;

  const WeaveMember({
    required this.userId,
    required this.role,
    required this.rsvp,
    required this.joinedAt,
  });

  bool get isHost => role == WeaveRole.host;

  factory WeaveMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return WeaveMember(
      userId: doc.id,
      role: WeaveRole.values.byName(d['role'] as String? ?? 'member'),
      rsvp: RsvpStatus.values.byName(d['rsvp'] as String? ?? 'pending'),
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'role': role.name,
    'rsvp': rsvp.name,
    'joinedAt': FieldValue.serverTimestamp(),
  };
}
