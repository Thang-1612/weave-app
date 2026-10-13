import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/account_service.dart';
import '../services/l10n.dart';
import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import 'auth_widgets.dart';

/// Mở bảng chuyển tài khoản. [onSwitched] được gọi sau khi chuyển thành công.
Future<void> showAccountSwitcher(
    BuildContext context,
    VoidCallback onSwitched,
    ) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AccountSwitcherSheet(onSwitched: onSwitched),
  );
}

/// Phần đầu gradient dùng chung cho bảng và hộp thoại
class _GradientHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _GradientHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  Widget _circle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.fromRGBO(255, 255, 255, opacity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: const BoxDecoration(gradient: AppColors.gradient),
      child: Stack(
        children: [
          Positioned(top: -50, right: -40, child: _circle(130, 0.12)),
          Positioned(bottom: -60, left: -40, child: _circle(150, 0.10)),
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.2),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 30, color: AppColors.brand),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color.fromRGBO(255, 255, 255, 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSwitcherSheet extends StatefulWidget {
  final VoidCallback onSwitched;

  const _AccountSwitcherSheet({required this.onSwitched});

  @override
  State<_AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<_AccountSwitcherSheet> {
  List<String> _accounts = [];
  Map<String, String> _names = {};
  bool _loaded = false;

  String? get _current =>
      FirebaseAuth.instance.currentUser?.email?.toLowerCase();

  String? _nameFor(String email) {
    if (email == _current) {
      return nameOf(FirebaseAuth.instance.currentUser) ?? _names[email];
    }
    return _names[email];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AccountService.load();
    final names = await AccountService.loadNames();
    if (mounted) {
      setState(() {
        _accounts = list;
        _names = names;
        _loaded = true;
      });
    }
  }

  Future<void> _remove(String email) async {
    await AccountService.remove(email);
    await _load();
  }

  Future<void> _openSignIn({String? email}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _SignInDialog(email: email),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(); // đóng bảng chuyển tài khoản
      widget.onSwitched();
    }
  }

  Future<void> _logout() async {
    final email = _current ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.logout, color: AppColors.danger, size: 32),
        title: Text(tr('Đăng xuất?', 'Log out?')),
        content: Text(
          tr(
            'Bạn có chắc muốn đăng xuất khỏi tài khoản $email không?',
            'Are you sure you want to log out of $email?',
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Đăng xuất', 'Log out')),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (mounted) Navigator.of(context).pop(); // đóng bảng trước khi đăng xuất
      UserPrefs.instance.bind(null);
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final accounts = [..._accounts];
    if (current != null && !accounts.contains(current)) {
      accounts.insert(0, current);
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GradientHeader(
            icon: Icons.switch_account_outlined,
            title: tr('Tài khoản', 'Accounts'),
            subtitle: current == null
                ? tr(
              'Chuyển đổi hoặc thêm tài khoản',
              'Switch or add an account',
            )
                : (nameOf(FirebaseAuth.instance.currentUser) ?? current),
          ),
          if (!_loaded)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final email in accounts) _buildTile(email, current),
                ],
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.soft,
              child: Icon(Icons.add, color: AppColors.brand),
            ),
            title: Text(tr('Thêm tài khoản khác', 'Add another account')),
            onTap: () => _openSignIn(),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFEE2E2),
              child: Icon(Icons.logout, color: AppColors.danger),
            ),
            title: Text(
              tr('Đăng xuất', 'Log out'),
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: _logout,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTile(String email, String? current) {
    final isCurrent = email == current;
    final name = _nameFor(email);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCurrent ? AppColors.brand : AppColors.soft,
        child: Text(
          initialOf(name ?? email),
          style: TextStyle(
            color: isCurrent ? Colors.white : AppColors.brand,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(name ?? email, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        name != null
            ? email
            : (isCurrent
            ? tr('Đang sử dụng', 'In use')
            : tr('Nhấn để chuyển', 'Tap to switch')),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isCurrent
          ? const Icon(Icons.check_circle, color: AppColors.brand)
          : IconButton(
        icon: const Icon(Icons.close),
        tooltip: tr('Xóa khỏi danh sách', 'Remove from list'),
        onPressed: () => _remove(email),
      ),
      onTap: isCurrent ? null : () => _openSignIn(email: email),
    );
  }
}

/// Hộp thoại:
/// - [email] != null: nhập mật khẩu để chuyển sang tài khoản đã lưu.
/// - [email] == null: thêm tài khoản (đăng nhập) hoặc tạo tài khoản mới.
class _SignInDialog extends StatefulWidget {
  final String? email;

  const _SignInDialog({this.email});

  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
  late final TextEditingController _email =
  TextEditingController(text: widget.email ?? '');
  final _ho = TextEditingController();
  final _ten = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscure = true;
  bool _register = false; // true = đang ở chế độ tạo tài khoản mới

  bool get _isAdd => widget.email == null;

  void _toggleRegister() {
    setState(() {
      _register = !_register;
      _error = null;
      _confirm.clear();
    });
  }

  Future<void> _submit() async {
    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = tr(
        'Vui lòng nhập đủ thông tin',
        'Please fill in all fields',
      ));
      return;
    }
    if (_register) {
      if (_ho.text.trim().isEmpty || _ten.text.trim().isEmpty) {
        setState(() => _error = tr(
          'Vui lòng nhập họ và tên',
          'Please enter your family and given name',
        ));
        return;
      }
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        setState(() => _error = tr(
          'Email không đúng định dạng',
          'Invalid email format',
        ));
        return;
      }
      if (_password.text.length < 6) {
        setState(() => _error = tr(
          'Mật khẩu phải có ít nhất 6 ký tự',
          'Password must be at least 6 characters',
        ));
        return;
      }
      if (_password.text != _confirm.text) {
        setState(() => _error = tr(
          'Mật khẩu xác nhận không khớp',
          'Passwords do not match',
        ));
        return;
      }
    }

    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final auth = FirebaseAuth.instance;
      String? name;
      if (_register) {
        // Tạo xong, Firebase tự đăng nhập vào tài khoản mới
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: _password.text,
        );
        name = '${_ho.text.trim()} ${_ten.text.trim()}';
        try {
          await cred.user?.updateDisplayName(name);
          await cred.user?.reload();
        } catch (_) {}
      } else {
        // Nếu đăng nhập thất bại, tài khoản hiện tại vẫn được giữ nguyên
        final cred = await auth.signInWithEmailAndPassword(
          email: email,
          password: _password.text,
        );
        name = cred.user?.displayName;
      }
      await AccountService.add(email, name: name);
      if (mounted) Navigator.of(context).pop(true);
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
      case 'email-already-in-use':
        return tr('Email này đã được đăng ký', 'This email is already registered');
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
        return tr('Thao tác thất bại ($code)', 'Action failed ($code)');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _ho.dispose();
    _ten.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    final IconData icon;
    final String actionLabel;
    if (!_isAdd) {
      title = tr('Chuyển tài khoản', 'Switch account');
      subtitle = tr('Nhập mật khẩu để tiếp tục', 'Enter your password to continue');
      icon = Icons.switch_account_outlined;
      actionLabel = tr('Chuyển', 'Switch');
    } else if (_register) {
      title = tr('Tạo tài khoản mới', 'Create new account');
      subtitle = tr(
        'Tham gia cộng đồng ngay hôm nay',
        'Join the community today',
      );
      icon = Icons.person_add_alt_1;
      actionLabel = tr('Tạo tài khoản', 'Create account');
    } else {
      title = tr('Thêm tài khoản', 'Add account');
      subtitle = tr(
        'Đăng nhập tài khoản có sẵn',
        'Log in to an existing account',
      );
      icon = Icons.person_add_alt_1;
      actionLabel = tr('Thêm', 'Add');
    }

    final passwordSuffix = IconButton(
      icon: Icon(
        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
      onPressed: () => setState(() => _obscure = !_obscure),
    );

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GradientHeader(icon: icon, title: title, subtitle: subtitle),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_register) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ho,
                              textCapitalization: TextCapitalization.words,
                              decoration: authInputDecoration(
                                tr('Họ', 'Family name'),
                                Icons.badge_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _ten,
                              textCapitalization: TextCapitalization.words,
                              decoration: authInputDecoration(
                                tr('Tên', 'Given name'),
                                Icons.person_outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_isAdd)
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                        authInputDecoration('Email', Icons.email_outlined),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.soft,
                              child: Text(
                                initialOf(widget.email!),
                                style: const TextStyle(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.email!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      autofocus: !_isAdd,
                      onSubmitted: (_) {
                        if (!_register) _submit();
                      },
                      decoration: authInputDecoration(
                        tr('Mật khẩu', 'Password'),
                        Icons.lock_outline,
                        suffix: passwordSuffix,
                      ),
                    ),
                    if (_register) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirm,
                        obscureText: _obscure,
                        onSubmitted: (_) => _submit(),
                        decoration: authInputDecoration(
                          tr('Xác nhận mật khẩu', 'Confirm password'),
                          Icons.lock_reset_outlined,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      AuthErrorBox(message: _error!),
                    ],
                    const SizedBox(height: 20),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: AppColors.brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          actionLabel,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    if (_isAdd) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : _toggleRegister,
                        child: Text(
                          _register
                              ? tr(
                            'Đã có tài khoản? Đăng nhập để thêm',
                            'Already have an account? Log in to add it',
                          )
                              : tr(
                            'Chưa có tài khoản? Tạo tài khoản mới',
                            'No account yet? Create one',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(tr('Hủy', 'Cancel')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}