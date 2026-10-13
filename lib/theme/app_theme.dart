import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const brand = Color(0xFF4F46E5);
  static const teal = Color(0xFF0F766E);
  static const pink = Color(0xFFDB2777);
  static const danger = Color(0xFFDC2626);
  static const background = Color(0xFFF5F6FA);
  static const border = Color(0xFFE5E7EB);
  static const soft = Color(0xFFE0E7FF);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, brand, pink],
  );
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand).copyWith(
    primary: AppColors.brand,
    onPrimary: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Nền gradient cho thanh tiêu đề: AppBar(flexibleSpace: GradientAppBarBackground())
class GradientAppBarBackground extends StatelessWidget {
  const GradientAppBarBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.gradient),
    );
  }
}