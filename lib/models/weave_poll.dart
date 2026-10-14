import 'package:cloud_firestore/cloud_firestore.dart';

enum PollKind { place, date }

class WeavePollOption {
  final String id;
  final String label;
  final String? address;
  final double? lat;
  final double? lng;
  final DateTime? date;

  const WeavePollOption({
    required this.id,
    required this.label,
    this.address,
    this.lat,
    this.lng,
    this.date,
  });

  factory WeavePollOption.fromMap(Map<String, dynamic> m) => WeavePollOption(
    id: m['id'] as String,
    label: m['label'] as String? ?? '',
    address: m['address'] as String?,
    lat: (m['lat'] as num?)?.toDouble(),
    lng: (m['lng'] as num?)?.toDouble(),
    date: (m['date'] as Timestamp?)?.toDate(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'address': address,
    'lat': lat,
    'lng': lng,
    'date': date == null ? null : Timestamp.fromDate(date!),
  };
}

/// weave_activities/{aid}/polls/{pid}
class WeavePoll {
  final String id;
  final PollKind kind;
  final String question;
  final List<WeavePollOption> options;
  final bool multi; // cho chọn nhiều đáp án
  final DateTime? closesAt;
  final bool closed;
  final String? winnerOptionId;
  final String createdBy;
  final DateTime createdAt;

  const WeavePoll({
    required this.id,
    required this.kind,
    required this.question,
    required this.options,
    required this.createdBy,
    required this.createdAt,
    this.multi = false,
    this.closesAt,
    this.closed = false,
    this.winnerOptionId,
  });

  bool get isExpired => closesAt != null && DateTime.now().isAfter(closesAt!);
  bool get isOpen => !closed && !isExpired;

  factory WeavePoll.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return WeavePoll(
      id: doc.id,
      kind: PollKind.values.byName(d['kind'] as String? ?? 'place'),
      question: d['question'] as String? ?? '',
      options: [
        for (final o in (d['options'] as List? ?? const []))
          WeavePollOption.fromMap(Map<String, dynamic>.from(o as Map)),
      ],
      multi: d['multi'] as bool? ?? false,
      closesAt: (d['closesAt'] as Timestamp?)?.toDate(),
      closed: d['closed'] as bool? ?? false,
      winnerOptionId: d['winnerOptionId'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'kind': kind.name,
    'question': question,
    'options': [for (final o in options) o.toMap()],
    'multi': multi,
    'closesAt': closesAt == null ? null : Timestamp.fromDate(closesAt!),
    'closed': closed,
    'winnerOptionId': winnerOptionId,
    'createdBy': createdBy,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

/// weave_activities/{aid}/polls/{pid}/votes/{uid}
class WeaveVote {
  final String userId;
  final List<String> optionIds;
  const WeaveVote({required this.userId, required this.optionIds});

  factory WeaveVote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      WeaveVote(
        userId: doc.id,
        optionIds:
        List<String>.from(doc.data()?['optionIds'] as List? ?? const []),
      );
}

/// optionId -> số phiếu.
Map<String, int> weaveTally(WeavePoll p, List<WeaveVote> votes) {
  final m = {for (final o in p.options) o.id: 0};
  for (final v in votes) {
    for (final id in v.optionIds) {
      if (m.containsKey(id)) m[id] = m[id]! + 1;
    }
  }
  return m;
}

/// Lựa chọn nhiều phiếu nhất (hòa thì lấy cái đứng trước). null nếu chưa ai bầu.
String? weaveLeader(WeavePoll p, List<WeaveVote> votes) {
  final t = weaveTally(p, votes);
  String? best;
  var bestN = 0;
  for (final o in p.options) {
    final n = t[o.id] ?? 0;
    if (n > bestN) {
      best = o.id;
      bestN = n;
    }
  }
  return best;
}