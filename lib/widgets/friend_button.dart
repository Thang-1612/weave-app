import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/friend_service.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// Nút thay đổi theo trạng thái quan hệ với một người dùng:
/// Kết bạn / Hủy lời mời / Chấp nhận + Từ chối / Bạn bè.
class FriendActionButton extends StatefulWidget {
  final String uid;
  final List<Friendship> friendships;
  final bool compact;

  const FriendActionButton({
    super.key,
    required this.uid,
    required this.friendships,
    this.compact = false,
  });

  @override
  State<FriendActionButton> createState() => _FriendActionButtonState();
}

class _FriendActionButtonState extends State<FriendActionButton> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${tr('Không thực hiện được', 'Could not complete')}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmUnfriend() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(tr('Hủy kết bạn?', 'Unfriend?')),
        content: Text(
          tr(
            'Hai bạn sẽ không còn là bạn bè của nhau.',
            'You will no longer be friends with each other.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Giữ lại', 'Keep')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Hủy kết bạn', 'Unfriend')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _run(() => FriendService.remove(widget.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (widget.uid.isEmpty || widget.uid == me) return const SizedBox.shrink();

    if (_busy) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final density = widget.compact
        ? VisualDensity.compact
        : VisualDensity.standard;
    final status = FriendService.statusWith(widget.friendships, me, widget.uid);

    switch (status) {
      case FriendStatus.none:
        return FilledButton.icon(
          onPressed: () => _run(() => FriendService.sendRequest(widget.uid)),
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: Text(tr('Kết bạn', 'Add friend')),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            visualDensity: density,
          ),
        );

      case FriendStatus.outgoing:
        return OutlinedButton(
          onPressed: () => _run(() => FriendService.remove(widget.uid)),
          style: OutlinedButton.styleFrom(visualDensity: density),
          child: Text(tr('Hủy lời mời', 'Cancel request')),
        );

      case FriendStatus.incoming:
        if (widget.compact) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filled(
                tooltip: tr('Chấp nhận', 'Accept'),
                onPressed: () => _run(() => FriendService.accept(widget.uid)),
                icon: const Icon(Icons.check),
                style: IconButton.styleFrom(backgroundColor: AppColors.brand),
              ),
              IconButton.outlined(
                tooltip: tr('Từ chối', 'Decline'),
                onPressed: () => _run(() => FriendService.remove(widget.uid)),
                icon: const Icon(Icons.close),
              ),
            ],
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => _run(() => FriendService.accept(widget.uid)),
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              child: Text(tr('Chấp nhận', 'Accept')),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _run(() => FriendService.remove(widget.uid)),
              child: Text(tr('Từ chối', 'Decline')),
            ),
          ],
        );

      case FriendStatus.friends:
        return OutlinedButton.icon(
          onPressed: _confirmUnfriend,
          icon: const Icon(Icons.check, size: 18),
          label: Text(tr('Bạn bè', 'Friends')),
          style: OutlinedButton.styleFrom(visualDensity: density),
        );
    }
  }
}
