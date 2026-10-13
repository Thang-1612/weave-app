import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/capsule_service.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';

class CapsulesScreen extends StatefulWidget {
  const CapsulesScreen({super.key});

  @override
  State<CapsulesScreen> createState() => _CapsulesScreenState();
}

class _CapsulesScreenState extends State<CapsulesScreen> {
  late Future<(List<QueryDocumentSnapshot<Map<String, dynamic>>>, List<Post>)>
  _future = _load();

  Future<(List<QueryDocumentSnapshot<Map<String, dynamic>>>, List<Post>)>
  _load() async {
    final r = await Future.wait([
      CapsuleService.mine(),
      CapsuleService.openedForMe(),
    ]);
    return (
    r[0] as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
    r[1] as List<Post>,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Widget _title(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(s,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
  );

  Widget _lockedTile(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final openAt = (data['openAt'] as Timestamp).toDate();
    final days = openAt.difference(DateTime.now()).inDays;
    return ListTile(
      leading: const Icon(Icons.lock_clock),
      title: Text(
          '${tr('Mở vào', 'Opens on')} ${CapsuleService.fmtDate(openAt)}'),
      subtitle: Text(days > 0
          ? tr('Còn $days ngày', '$days days left')
          : tr('Sắp mở', 'Opening soon')),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          await CapsuleService.delete(d.id);
          _reload();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        title: Text(tr('Hộp thời gian', 'Time capsules')),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText('${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (mine, received) = snap.data!;
          final now = DateTime.now();
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              children: [
                _title(tr('Hộp của tôi', 'My capsules')),
                if (mine.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(tr(
                        'Chưa có hộp nào. Khi soạn bài, chọn "Hẹn giờ mở".',
                        'None yet. When writing a post, choose "Time capsule".')),
                  ),
                for (final d in mine)
                  if ((d.data()['openAt'] as Timestamp).toDate().isAfter(now))
                    _lockedTile(d)
                  else
                    PostCard(
                      key: ValueKey('capsules_${d.id}'),
                      post: Post.fromDoc(d),
                    ),
                _title(tr('Gửi cho tôi', 'Sent to me')),
                if (received.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(tr('Chưa có hộp nào được mở.',
                        'No capsules opened yet.')),
                  ),
                for (final p in received)
                  PostCard(key: ValueKey('capsules_${p.id}'), post: p),
              ],
            ),
          );
        },
      ),
    );
  }
}