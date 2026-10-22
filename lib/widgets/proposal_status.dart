import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/l10n.dart';

/// Dòng báo kết quả đề xuất sửa bài, hiện trên bài nhánh của chính bạn khi
/// tác giả bài gốc đã nhận hoặc từ chối. Bấm dấu X để ẩn.
class ProposalStatus extends StatelessWidget {
  final Post post;
  const ProposalStatus({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || post.authorId != uid || post.forkedFrom == null) {
      return const SizedBox.shrink();
    }
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('proposal_results')
        .doc(post.id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null) return const SizedBox.shrink();
        final accepted = data['status'] == 'accepted';
        final by = data['byName'] as String? ?? '';
        final color = accepted ? Colors.green.shade700 : AppColors.textSecondary;
        return Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
          decoration: BoxDecoration(
            color: accepted ? AppColors.successSoft : AppColors.border,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                accepted ? Icons.check_circle_outline : Icons.info_outline,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  accepted
                      ? tr('Đề xuất của bạn đã được $by nhận',
                      'Your proposal was accepted by $by')
                      : tr('Đề xuất của bạn chưa được nhận',
                      'Your proposal was not accepted'),
                  style: TextStyle(fontSize: 12.5, color: color),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 16),
                onPressed: () async {
                  try {
                    await ref.delete();
                  } catch (_) {}
                },
              ),
            ],
          ),
        );
      },
    );
  }
}