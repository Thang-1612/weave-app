import 'package:flutter/material.dart';

/// Nền gradient + bong bóng + huy hiệu emoji dùng chung cho đăng nhập/đăng ký
class AuthBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const AuthBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF4F46E5), Color(0xFFDB2777)],
        ),
      ),
      child: Stack(
        children: [
          const _Bubble(
              alignment: Alignment(-1.2, -0.95), size: 260, opacity: 0.10),
          const _Bubble(
              alignment: Alignment(1.2, -0.3), size: 180, opacity: 0.08),
          const _Bubble(
              alignment: Alignment(-0.9, 1.1), size: 300, opacity: 0.10),
          const _Bubble(
              alignment: Alignment(1.0, 1.0), size: 140, opacity: 0.12),
          const _EmojiBadge(
              alignment: Alignment(-0.85, -0.7),
              emoji: '📚',
              size: 54,
              angle: -0.2),
          const _EmojiBadge(
              alignment: Alignment(0.88, -0.8),
              emoji: '🍜',
              size: 46,
              angle: 0.25),
          const _EmojiBadge(
              alignment: Alignment(-0.9, 0.6),
              emoji: '✈️',
              size: 48,
              angle: 0.15),
          const _EmojiBadge(
              alignment: Alignment(0.9, 0.75),
              emoji: '🛠',
              size: 52,
              angle: -0.25),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final double opacity;

  const _Bubble({
    required this.alignment,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.fromRGBO(255, 255, 255, opacity),
        ),
      ),
    );
  }
}

class _EmojiBadge extends StatelessWidget {
  final Alignment alignment;
  final String emoji;
  final double size;
  final double angle;

  const _EmojiBadge({
    required this.alignment,
    required this.emoji,
    required this.size,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.18),
            borderRadius: BorderRadius.circular(size * 0.32),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.35),
            ),
          ),
          child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
        ),
      ),
    );
  }
}

/// Logo + tên app + câu giới thiệu phía trên thẻ form
class AuthBrand extends StatelessWidget {
  final String subtitle;

  const AuthBrand({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.2),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.hub_rounded,
            size: 40,
            color: Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Social App',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color.fromRGBO(255, 255, 255, 0.85),
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

/// Thẻ trắng bo tròn chứa form
class AuthCard extends StatelessWidget {
  final Widget child;

  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.18),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Ô thông báo lỗi
class AuthErrorBox extends StatelessWidget {
  final String message;

  const AuthErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFB91C1C)),
      ),
    );
  }
}

/// Kiểu ô nhập chung
InputDecoration authInputDecoration(
    String label,
    IconData icon, {
      Widget? suffix,
    }) {
  OutlineInputBorder border(Color color, [double width = 0]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: width == 0
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: const Color(0xFFF3F4F6),
    border: border(Colors.transparent),
    enabledBorder: border(Colors.transparent),
    focusedBorder: border(const Color(0xFF4F46E5), 1.5),
    errorBorder: border(const Color(0xFFDC2626), 1),
    focusedErrorBorder: border(const Color(0xFFDC2626), 1.5),
  );
}