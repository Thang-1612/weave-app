import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/account_service.dart';
import '../services/l10n.dart';
import '../services/user_prefs.dart';
import '../widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ho = TextEditingController();
  final _ten = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscure = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final email = _email.text.trim();
      final fullName = '${_ho.text.trim()} ${_ten.text.trim()}';

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _password.text,
      );

      // Lưu họ tên vào tài khoản (không làm hỏng việc đăng ký nếu lỗi)
      try {
        await cred.user?.updateDisplayName(fullName);
        await cred.user?.reload();
      } catch (_) {}
      await AccountService.add(email, name: fullName);

      // Đăng ký xong: đóng màn hình này, AuthGate sẽ tự chuyển vào trang chính
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e.code));
    } catch (e) {
      if (mounted) setState(() => _error = '${tr('Lỗi', 'Error')}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(String code) {
    switch (code) {
      case 'email-already-in-use':
        return tr('Email này đã được đăng ký', 'This email is already registered');
      case 'invalid-email':
        return tr('Email không hợp lệ', 'Invalid email address');
      case 'weak-password':
        return tr(
          'Mật khẩu quá yếu (ít nhất 6 ký tự)',
          'Password is too weak (at least 6 characters)',
        );
      case 'operation-not-allowed':
        return tr(
          'Chưa bật đăng nhập Email/Password trong Firebase',
          'Email/Password sign-in is not enabled in Firebase',
        );
      default:
        return tr('Đăng ký thất bại ($code)', 'Sign-up failed ($code)');
    }
  }

  @override
  void dispose() {
    _ho.dispose();
    _ten.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserPrefs.instance,
      builder: (context, _) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.white,
        ),
        body: AuthBackground(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthBrand(
                subtitle: tr(
                  'Tham gia cộng đồng ngay hôm nay',
                  'Join the community today',
                ),
              ),
              const SizedBox(height: 28),
              AuthCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr('Tạo tài khoản', 'Create account'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                              validator: (v) =>
                              (v == null || v.trim().isEmpty)
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
                              validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? tr('Nhập tên', 'Required')
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                        authInputDecoration('Email', Icons.email_outlined),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) {
                            return tr('Vui lòng nhập email', 'Please enter your email');
                          }
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value)) {
                            return tr(
                              'Email không đúng định dạng',
                              'Invalid email format',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: authInputDecoration(
                          tr('Mật khẩu', 'Password'),
                          Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return tr(
                              'Vui lòng nhập mật khẩu',
                              'Please enter a password',
                            );
                          }
                          if (v.length < 6) {
                            return tr(
                              'Mật khẩu phải có ít nhất 6 ký tự',
                              'Password must be at least 6 characters',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        decoration: authInputDecoration(
                          tr('Xác nhận mật khẩu', 'Confirm password'),
                          Icons.lock_reset_outlined,
                        ),
                        validator: (v) {
                          if (v != _password.text) {
                            return tr(
                              'Mật khẩu xác nhận không khớp',
                              'Passwords do not match',
                            );
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        AuthErrorBox(message: _error!),
                      ],
                      const SizedBox(height: 20),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else
                        FilledButton(
                          onPressed: _register,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: const Color(0xFF4F46E5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            tr('Tạo tài khoản', 'Create account'),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(
                          tr(
                            'Đã có tài khoản? Đăng nhập',
                            'Already have an account? Log in',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}