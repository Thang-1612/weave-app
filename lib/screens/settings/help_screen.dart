import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/l10n.dart';
import '../../services/user_prefs.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_widgets.dart';

class _Faq {
  final String qVi;
  final String aVi;
  final String qEn;
  final String aEn;

  const _Faq(this.qVi, this.aVi, this.qEn, this.aEn);
}

const _faqs = [
  _Faq(
    'Làm sao để đăng bài?',
    'Bấm nút + ở giữa thanh dưới. Bạn có thể ghép chữ, ảnh, liên kết và icon, kéo biểu tượng ⋮⋮ để đổi thứ tự rồi bấm Đăng.',
    'How do I publish a post?',
    'Tap the + button in the middle of the bottom bar. Combine text, images, links and icons, drag the ⋮⋮ handle to reorder, then tap Post.',
  ),
  _Faq(
    'Quên chọn chủ đề thì sao?',
    'Để chip "Tự động": ứng dụng đọc chữ, liên kết và ảnh để chọn chủ đề phù hợp. Nếu chưa chắc, ứng dụng sẽ hỏi bạn. Bạn luôn đổi lại được ở ⋯ → Đổi chủ đề.',
    'What if I forget to pick a topic?',
    'Leave the "Auto" chip selected: the app reads the text, links and images to choose a topic. If unsure, it asks you. You can change it later in ⋯ → Change topic.',
  ),
  _Faq(
    'Thả cảm xúc như thế nào?',
    'Bấm Thích để thả 👍. Trên máy tính, rê chuột vào nút Thích để mở khay cảm xúc. Trên điện thoại, chạm giữ. Bấm nút ＋ trong khay để chọn bất kỳ icon nào từ bàn phím.',
    'How do I react?',
    'Tap Like for 👍. On a computer, hover over Like to open the reaction tray. On a phone, press and hold. Tap ＋ in the tray to pick any emoji from your keyboard.',
  ),
  _Faq(
    'Gọi trợ lý AI như thế nào?',
    'Trong phần bình luận, gõ @AI cùng câu hỏi của bạn. Trợ lý AI sẽ trả lời trong chuỗi phản hồi và có thể xem cả ảnh của bài viết.',
    'How do I call the AI assistant?',
    'In the comments, type @AI followed by your question. The assistant replies in the thread and can also look at the post image.',
  ),
  _Faq(
    'Khác nhau giữa chặn, tắt tiếng và ẩn bài?',
    'Ẩn bài chỉ ẩn một bài. Tắt tiếng ẩn mọi bài của một người nhưng vẫn là bạn bè. Chặn ẩn bài và bình luận của họ và hủy kết bạn.',
    'What is the difference between block, mute and hide?',
    'Hide removes a single post. Mute hides all posts from a person but you stay friends. Block hides their posts and comments and removes the friendship.',
  ),
  _Faq(
    'Bài đã lưu nằm ở đâu?',
    'Bấm biểu tượng đánh dấu dưới bài viết. Xem lại ở menu ba gạch → Đã lưu, hoặc Cài đặt và hoạt động → Đã lưu.',
    'Where are my saved posts?',
    'Tap the bookmark icon under a post. Find them in the menu → Saved, or Settings and activity → Saved.',
  ),
  _Faq(
    'Tôi không muốn nhận một số loại thông báo',
    'Vào Cài đặt và hoạt động → Thông báo để bật hoặc tắt từng loại.',
    'I do not want some notifications',
    'Go to Settings and activity → Notifications to turn each type on or off.',
  ),
  _Faq(
    'Làm sao để người lạ không gửi lời mời kết bạn?',
    'Vào Quyền riêng tư và tắt "Cho phép nhận lời mời kết bạn". Bạn cũng có thể tắt "Cho phép người khác tìm thấy tôi".',
    'How do I stop strangers from sending friend requests?',
    'Go to Privacy and turn off "Allow friend requests". You can also turn off "Let others find me".',
  ),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _feedback(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => const _FeedbackDialog(),
    );
    if (sent == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('Đã gửi phản hồi. Cảm ơn bạn!', 'Feedback sent. Thank you!'),
          ),
        ),
      );
    }
  }

  void _policy(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserPrefs.instance,
      builder: (context, _) {
        final en = UserPrefs.instance.language == 'en';
        return SettingsScaffold(
          title: tr('Trợ giúp', 'Help'),
          body: settingsList([
            SectionLabel(
              tr('Câu hỏi thường gặp', 'Frequently asked questions'),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _faqs.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Theme(
                      // Bỏ đường kẻ mặc định của ExpansionTile
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Text(
                          en ? _faqs[i].qEn : _faqs[i].qVi,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          14,
                        ),
                        expandedAlignment: Alignment.centerLeft,
                        children: [
                          Text(
                            en ? _faqs[i].aEn : _faqs[i].aVi,
                            style: const TextStyle(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SectionLabel(tr('Liên hệ', 'Contact')),
            SettingsCard(
              children: [
                SettingsTile(
                  icon: Icons.feedback_outlined,
                  title: tr(
                    'Gửi phản hồi hoặc báo lỗi',
                    'Send feedback or report a bug',
                  ),
                  subtitle: tr(
                    'Cho chúng tôi biết điều gì cần cải thiện',
                    'Tell us what needs improving',
                  ),
                  onTap: () => _feedback(context),
                ),
              ],
            ),
            SectionLabel(tr('Điều khoản', 'Legal')),
            SettingsCard(
              children: [
                SettingsTile(
                  icon: Icons.description_outlined,
                  title: tr('Điều khoản sử dụng', 'Terms of use'),
                  onTap: () => _policy(
                    context,
                    tr('Điều khoản sử dụng', 'Terms of use'),
                    tr(
                      '[BẢN NHÁP: cần thay bằng điều khoản chính thức trước khi phát hành]\n\nKhi dùng ứng dụng, bạn đồng ý không đăng nội dung vi phạm pháp luật, quấy rối hoặc xâm phạm quyền của người khác. Chúng tôi có thể gỡ nội dung vi phạm và khóa tài khoản vi phạm nhiều lần.',
                      '[DRAFT: replace with official terms before release]\n\nBy using the app you agree not to post unlawful content, harass others or infringe their rights. We may remove violating content and suspend repeat offenders.',
                    ),
                  ),
                ),
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: tr('Chính sách quyền riêng tư', 'Privacy policy'),
                  onTap: () => _policy(
                    context,
                    tr('Chính sách quyền riêng tư', 'Privacy policy'),
                    tr(
                      '[BẢN NHÁP: cần thay bằng chính sách chính thức trước khi phát hành]\n\nỨng dụng lưu hồ sơ, bài viết, bình luận và cài đặt của bạn trên Firebase. Khi bạn dùng tính năng AI, nội dung liên quan được gửi tới dịch vụ AI để tạo câu trả lời. Bạn có thể tải dữ liệu của mình trong mục Quyền riêng tư.',
                      '[DRAFT: replace with the official policy before release]\n\nThe app stores your profile, posts, comments and settings on Firebase. When you use AI features, the related content is sent to the AI service to generate a reply. You can download your data in the Privacy section.',
                    ),
                  ),
                ),
              ],
            ),
          ]),
        );
      },
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _text = TextEditingController();
  String _type = 'bug';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _text.text.trim();
    if (message.length < 10) {
      setState(
        () => _error = tr(
          'Vui lòng mô tả ít nhất 10 ký tự',
          'Please write at least 10 characters',
        ),
      );
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': uid,
        'type': _type,
        'message': message,
        'language': UserPrefs.instance.language,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = {
      'bug': tr('Báo lỗi', 'Bug'),
      'idea': tr('Góp ý', 'Idea'),
      'other': tr('Khác', 'Other'),
    };
    return AlertDialog(
      title: Text(tr('Gửi phản hồi', 'Send feedback')),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final e in types.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _type == e.key,
                      onSelected: (_) => setState(() => _type = e.key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Dùng kiểu ô nhập mặc định của theme (viền + nền trắng).
              TextField(
                controller: _text,
                maxLines: 5,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: tr(
                    'Mô tả vấn đề hoặc ý tưởng của bạn...',
                    'Describe your problem or idea...',
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: Text(tr('Hủy', 'Cancel')),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr('Gửi', 'Send')),
        ),
      ],
    );
  }
}
