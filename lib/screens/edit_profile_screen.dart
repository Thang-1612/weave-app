import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/l10n.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile? profile;
  final String fallbackName;

  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.fallbackName,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ho;
  late final TextEditingController _ten;
  late final TextEditingController _bio;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pho = widget.profile?.ho ?? '';
    final pten = widget.profile?.ten ?? '';
    final hasParts = pho.isNotEmpty || pten.isNotEmpty;
    _ho = TextEditingController(
      text: hasParts ? pho : hoOf(widget.fallbackName),
    );
    _ten = TextEditingController(
      text: hasParts ? pten : tenOf(widget.fallbackName),
    );
    _bio = TextEditingController(text: widget.profile?.bio ?? '');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await UserService.saveProfile(
        ho: _ho.text,
        ten: _ten.text,
        bio: _bio.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Đã cập nhật hồ sơ', 'Profile updated'))),
      );
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('${tr('Không lưu được', 'Could not save')}: $e')),
      );
    }
  }

  @override
  void dispose() {
    _ho.dispose();
    _ten.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Chỉnh sửa hồ sơ', 'Edit profile')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ho,
                            textCapitalization: TextCapitalization.words,
                            decoration: authInputDecoration(
                              tr('Họ', 'Family name'),
                              Icons.badge_outlined,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? tr('Nhập họ', 'Required')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _ten,
                            textCapitalization: TextCapitalization.words,
                            decoration: authInputDecoration(
                              tr('Tên', 'Given name'),
                              Icons.person_outline,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? tr('Nhập tên', 'Required')
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _bio,
                      maxLines: 3,
                      maxLength: 150,
                      decoration: authInputDecoration(
                        tr('Giới thiệu bản thân', 'About you'),
                        Icons.edit_note_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_saving)
                      const Center(child: CircularProgressIndicator())
                    else
                      FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: AppColors.brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          tr('Lưu thay đổi', 'Save changes'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}