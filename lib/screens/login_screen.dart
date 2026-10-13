import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../services/user_prefs.dart';
import '../widgets/auth_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscure = true;

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = tr(
        'Vui lòng nhập email và mật khẩu',
        'Please enter your email and password',
      ));
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
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
      case 'invalid-email':
        return tr('Email không hợp lệ', 'Invalid email address');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return tr('Email hoặc mật khẩu không đúng', 'Incorrect email or password');
      case 'user-disabled':
        return tr(
          'Tài khoản này đã bị vô hiệu hóa',
          'This account has been disabled',
        );
      case 'too-many-requests':
        return tr(
          'Thử quá nhiều lần, vui lòng đợi một lúc',
          'Too many attempts, please wait a moment',
        );
      default:
        return tr('Đăng nhập thất bại ($code)', 'Login failed ($code)');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Widget _languageSwitch() {
    final lang = UserPrefs.instance.language;
    Widget option(String code, String label) {
      final selected = lang == code;
      return TextButton(
        onPressed: () => UserPrefs.instance.setLanguage(code),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
            decoration: selected ? TextDecoration.underline : TextDecoration.none,
            decorationColor: Colors.white,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        option('vi', 'Tiếng Việt'),
        const Text('·', style: TextStyle(color: Color.fromRGBO(255, 255, 255, 0.7))),
        option('en', 'English'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Vẽ lại ngay khi đổi ngôn ngữ
    return ListenableBuilder(
      listenable: UserPrefs.instance,
      builder: (context, _) => Scaffold(
        body: AuthBackground(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthBrand(
                subtitle: tr(
                  'Chia sẻ mọi điều bạn quan tâm',
                  'Share everything you care about',
                ),
              ),
              const SizedBox(height: 28),
              AuthCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('Chào mừng trở lại', 'Welcome back'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                      authInputDecoration('Email', Icons.email_outlined),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      onSubmitted: (_) => _login(),
                      decoration: authInputDecoration(
                        tr('Mật khẩu', 'Password'),
                        Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
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
                        onPressed: _login,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          tr('Đăng nhập', 'Log in'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(tr('hoặc', 'or')),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        tr('Tạo tài khoản mới', 'Create new account'),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _languageSwitch(),
            ],
          ),
        ),
      ),
    );
  }
}