import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'responsive_home_demo.dart';

/// Chạy riêng để xem bố cục responsive, không cần Firebase hay đăng nhập:
///   flutter run -d chrome -t lib/demo/demo_main.dart
/// Rồi kéo thay đổi chiều rộng cửa sổ trình duyệt.
void main() {
  runApp(
    MaterialApp(
      title: 'Weave responsive demo',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const ResponsiveHomeDemo(),
    ),
  );
}
