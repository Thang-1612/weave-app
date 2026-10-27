import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/l10n.dart';
import '../services/mutual_friends_service.dart';

/// Dòng "N bạn chung" trên hồ sơ của người khác. Không hiện gì nếu không có
/// bạn chung hoặc đang tải, để không làm xô lệch giao diện.
class MutualFriendsRow extends StatefulWidget {
  final String otherUid;
  const MutualFriendsRow({super.key, required this.otherUid});

  @override
  State<MutualFriendsRow> createState() => _MutualFriendsRowState();
}

class _MutualFriendsRowState extends State<MutualFriendsRow> {
  late Future<List<UserProfile>> _future;

  @override
  void initState() {
    super.initState();
    _future = MutualFriendsService.mutualProfiles(widget.otherUid);
  }

  @override
  void didUpdateWidget(covariant MutualFriendsRow old) {
    super.didUpdateWidget(old);
    if (old.otherUid != widget.otherUid) {
      _future = MutualFriendsService.mutualProfiles(widget.otherUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserProfile>>(
      future: _future,
      builder: (context, snap) {
        final list = snap.data;
        if (list == null || list.isEmpty) return const SizedBox.shrink();
        final names = list.take(2).map((p) => p.name).join(', ');
        final rest = list.length - 2;
        final text = rest > 0
            ? tr('$names và $rest bạn chung khác',
            '$names and $rest more mutual friends')
            : tr('Bạn chung: $names', 'Mutual friends: $names');
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.people_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      },
    );
  }
}
