import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../services/group_service.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// Tạo nhóm riêng: đặt tên và chọn bạn bè. Trả về nhóm vừa tạo, hoặc null.
Future<GroupInfo?> showCreateGroupSheet(BuildContext context) =>
    showModalBottomSheet<GroupInfo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateGroupSheet(),
    );

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet();

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _name = TextEditingController();
  final Set<String> _picked = {};
  late final Future<List<ChatUser>> _friends = _loadFriends();
  bool _busy = false;

  Future<List<ChatUser>> _loadFriends() async {
    final ids = (await ChatService.I.friendIds().first).toSet().toList();
    final users = await Future.wait(ids.map(ChatService.I.user));
    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final g =
      await GroupService.createWithMembers(_name.text, _picked.toList());
      nav.pop(g);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(tr('Không tạo được nhóm: $e', 'Could not create group: $e'))));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = !_busy && _name.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Tạo nhóm riêng', 'Create a private group'),
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              enabled: !_busy,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr('Tên nhóm', 'Group name'),
                border: const OutlineInputBorder(),
              ),
            ),
            Text(tr('Chọn bạn bè để thêm vào nhóm', 'Choose friends to add'),
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Flexible(
              child: FutureBuilder<List<ChatUser>>(
                future: _friends,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()));
                  }
                  final list = snap.data!;
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                          tr('Bạn chưa có bạn bè nào. Hãy kết bạn trước.',
                              'You have no friends yet. Add friends first.'),
                          style: const TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final u in list)
                        CheckboxListTile(
                          value: _picked.contains(u.uid),
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                            if (v == true) {
                              _picked.add(u.uid);
                            } else {
                              _picked.remove(u.uid);
                            }
                          }),
                          title: Text(u.name.isEmpty ? '…' : u.name),
                          secondary: CircleAvatar(
                            backgroundColor: AppColors.soft,
                            child: Text(
                                u.name.isEmpty
                                    ? '?'
                                    : u.name.characters.first.toUpperCase(),
                                style: const TextStyle(color: AppColors.brand)),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: canCreate ? _create : null,
              child: _busy
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr('Tạo nhóm', 'Create group')),
            ),
          ],
        ),
      ),
    );
  }
}