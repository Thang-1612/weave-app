import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/l10n.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';

class _Stats {
  final int posts;
  final bool postsCapped;
  final int living;
  final int updates;
  final int longestLivingDays;
  final int accepted; // đề xuất sửa bài được nhận
  final int answers; // câu trả lời được tác giả chọn làm đáp án
  final int? thanks; // chỉ có khi xem hồ sơ của chính mình
  const _Stats({
    required this.posts,
    required this.postsCapped,
    required this.living,
    required this.updates,
    required this.longestLivingDays,
    required this.accepted,
    required this.answers,
    required this.thanks,
  });
}

/// "Dấu vết đóng góp": đo uy tín bằng việc bạn đã giúp được ai, không phải
/// số người theo dõi.
class ContributionScreen extends StatefulWidget {
  final String userId;
  final String name;
  const ContributionScreen({super.key, required this.userId, this.name = ''});

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  static const _cap = 100;

  late final Future<_Stats> _future = _load();

  bool get _isSelf => FirebaseAuth.instance.currentUser?.uid == widget.userId;

  Future<_Stats> _load() async {
    final db = FirebaseFirestore.instance;
    final col = db.collection('posts');

    final mine =
    await col.where('authorId', isEqualTo: widget.userId).limit(_cap).get();
    final posts = mine.docs.map(Post.fromDoc).toList();

    var living = 0;
    var updates = 0;
    var longest = 0;
    for (final p in posts) {
      updates += p.publicUpdateCount;
      if (p.publicUpdateCount > 0) {
        living++;
        final last = p.lastPublicUpdateAt ?? p.createdAt;
        final days = last.difference(p.createdAt).inDays;
        if (days > longest) longest = days;
      }
    }

    final acceptedAgg = await col
        .where('contributorIds', arrayContains: widget.userId)
        .count()
        .get();

    // Câu trả lời được chọn: lỗi ở đây không được làm hỏng cả màn hình
    var answers = 0;
    try {
      answers = await PostService.acceptedAnswerCount(widget.userId);
    } catch (_) {}

    int? thanks;
    if (_isSelf) {
      try {
        final t = await db
            .collection('users')
            .doc(widget.userId)
            .collection('thanks_inbox')
            .count()
            .get();
        thanks = t.count ?? 0;
      } catch (_) {}
    }

    return _Stats(
      posts: posts.length,
      postsCapped: posts.length >= _cap,
      living: living,
      updates: updates,
      longestLivingDays: longest,
      accepted: acceptedAgg.count ?? 0,
      answers: answers,
      thanks: thanks,
    );
  }

  Widget _card(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.brand,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        title: Text(tr('Dấu vết đóng góp', 'Contribution trail')),
      ),
      body: FutureBuilder<_Stats>(
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
          final s = snap.data!;
          final cards = <Widget>[
            _card('📝', '${s.posts}${s.postsCapped ? '+' : ''}',
                tr('Bài đã đăng', 'Posts published')),
            _card('✅', '${s.answers}',
                tr('Câu trả lời được chọn', 'Answers accepted')),
            _card('🔄', '${s.living}', tr('Bài sống', 'Living posts')),
            _card('⏳', '${s.longestLivingDays}',
                tr('Ngày: bài sống lâu nhất', 'Days: longest living post')),
            _card('📌', '${s.updates}',
                tr('Cập nhật đã đăng', 'Updates posted')),
            _card('🤝', '${s.accepted}',
                tr('Đề xuất được nhận', 'Proposals accepted')),
            if (s.thanks != null)
              _card('💌', '${s.thanks}',
                  tr('Lời cảm ơn nhận được', 'Thank-yous received')),
          ];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        widget.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: cards,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(
                      'Số liệu bài đăng tính trên tối đa $_cap bài công khai gần nhất của tài khoản. Câu trả lời được chọn chỉ tính ở các câu hỏi công khai. Lời cảm ơn là riêng tư nên chỉ chủ tài khoản thấy con số này.',
                      'Post stats are counted over the account\'s latest $_cap public posts at most. Accepted answers only count on public questions. Thank-yous are private, so only the account owner sees that number.',
                    ),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}