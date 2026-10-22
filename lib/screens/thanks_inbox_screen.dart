import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../services/social_extras_service.dart';
import '../theme/app_theme.dart';

/// Hộp "Lời cảm ơn": những lời cảm ơn riêng tư người khác gửi cho bài của bạn.
class ThanksInboxScreen extends StatefulWidget {
  const ThanksInboxScreen({super.key});

  @override
  State<ThanksInboxScreen> createState() => _ThanksInboxScreenState();
}

class _ThanksInboxScreenState extends State<ThanksInboxScreen> {
  late Future<List<ThanksItem>> _future = ThanksService.loadMine();

  Future<void> _reload() async {
    setState(() => _future = ThanksService.loadMine());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Lời cảm ơn', 'Thank-yous')),
      ),
      body: FutureBuilder<List<ThanksItem>>(
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
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    'Chưa có lời cảm ơn nào.\nKhi ai đó bấm "Cảm ơn" dưới bài của bạn, lời nhắn sẽ hiện ở đây.',
                    'No thank-yous yet.\nWhen someone taps "Thank" under your post, it shows up here.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final t = items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(WeaveRadius.card),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💌', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t.fromName} · ${extrasAgo(t.createdAt)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (t.note.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(t.note,
                                      style: const TextStyle(height: 1.35)),
                                ],
                                if (t.postPreview.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${tr('Về bài', 'About')}: ${t.postPreview}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: tr('Xóa', 'Remove'),
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () async {
                              await ThanksService.delete(t.id);
                              _reload();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}