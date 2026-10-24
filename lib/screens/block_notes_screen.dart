import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/l10n.dart';
import '../services/social_extras_service.dart';
import '../theme/app_theme.dart';
import '../widgets/text_prompt.dart';
import '../widgets/weave_error_view.dart';

/// Hiện từng khối của bài, mỗi khối có ghi chú riêng của người xem.
class BlockNotesScreen extends StatefulWidget {
  final Post post;
  const BlockNotesScreen({super.key, required this.post});

  @override
  State<BlockNotesScreen> createState() => _BlockNotesScreenState();
}

class _BlockNotesScreenState extends State<BlockNotesScreen> {
  // Tạo stream một lần (không tạo lại mỗi lần build). Nút Thử lại gán stream mới.
  late Stream<List<BlockNote>> _stream = BlockNoteService.watch(widget.post);

  Widget _blockView(Map<String, dynamic> b) {
    switch (b['type']) {
      case 'text':
        return Text(
          b['text'] as String? ?? '',
          style: const TextStyle(height: 1.4),
        );
      case 'image':
        try {
          final bytes = base64Decode(b['data'] as String? ?? '');
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {
          return const SizedBox.shrink();
        }
      case 'link':
        final title = b['title'] as String? ?? '';
        final url = b['url'] as String? ?? '';
        return Row(
          children: [
            const Icon(Icons.link, color: AppColors.brand, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title.isNotEmpty ? title : url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _addNote(BuildContext context, int index) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await showTextPrompt(
      context,
      title: tr('Ghi chú cho khối này', 'Note on this block'),
      hint: tr(
        'Bạn muốn hỏi hoặc góp ý gì ở đây?',
        'What would you like to ask or suggest here?',
      ),
      action: tr('Gửi', 'Send'),
      maxLen: 300,
    );
    if (text == null) return;
    try {
      await BlockNoteService.add(widget.post, index, text);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final me = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = post.authorId == me;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Ghi chú theo khối', 'Block notes'))),
      body: StreamBuilder<List<BlockNote>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('BlockNotesScreen stream error: ${snap.error}');
            return WeaveErrorView(
              message: tr(
                'Không tải được ghi chú.',
                'Could not load the notes.',
              ),
              onRetry: () => setState(
                    () => _stream = BlockNoteService.watch(widget.post),
              ),
            );
          }
          final notes = snap.data ?? const <BlockNote>[];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: post.blocks.length,
                itemBuilder: (context, i) {
                  final mine = notes.where((n) => n.blockIndex == i).toList();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _blockView(post.blocks[i]),
                        for (final n in mine)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                            decoration: BoxDecoration(
                              color: AppColors.soft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${n.authorName} · ${extrasAgo(n.createdAt)}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(n.text),
                                    ],
                                  ),
                                ),
                                if (n.authorId == me || isOwner)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: tr('Xóa ghi chú', 'Remove note'),
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () =>
                                        BlockNoteService.delete(post, n.id),
                                  ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _addNote(context, i),
                            icon: const Icon(
                              Icons.add_comment_outlined,
                              size: 16,
                            ),
                            label: Text(
                              tr('Ghi chú', 'Add note'),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.brand,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.only(top: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}