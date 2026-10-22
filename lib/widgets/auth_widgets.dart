import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'weave_ui.dart';

/// Decoration cho ô nhập ở màn đăng nhập/đăng ký. Viền, nền, bo góc lấy từ
/// inputDecorationTheme trong app_theme.dart.
InputDecoration authInputDecoration(
    String label,
    IconData icon, {
      Widget? suffix,
    }) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
  );
}

/// Khung báo lỗi nhỏ phía trên nút chính.
class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(WeaveSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WeaveRadius.control),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.danger),
          const SizedBox(width: WeaveSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nền gradient toàn màn hình, nội dung căn giữa, tối đa 440 px, cuộn được.
class AuthBackground extends StatelessWidget {
  const AuthBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(WeaveSpacing.xl),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.gradient),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight =
            (constraints.maxHeight - padding.vertical).clamp(0.0, double.infinity);
            return SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Logo + tên app + dòng mô tả, chữ trắng trên nền gradient.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key, required this.subtitle});

  final String subtitle;

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
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.forum_rounded,
              size: 36, color: AppColors.brand),
        ),
        const SizedBox(height: WeaveSpacing.lg),
        const Text(
          'Weave',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: WeaveSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color.fromRGBO(255, 255, 255, 0.85),
          ),
        ),
      ],
    );
  }
}

/// Thẻ trắng chứa form.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WeaveCard(
      padding: const EdgeInsets.all(WeaveSpacing.xl),
      child: child,
    );
  }
}