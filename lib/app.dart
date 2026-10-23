import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

class SocialApp extends StatelessWidget {
  const SocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    Route<dynamic> entry() =>
        MaterialPageRoute(builder: (_) => const AuthGate());

    return MaterialApp(
      title: 'Weave',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Mọi địa chỉ (ví dụ /post/abc) đều vào AuthGate; phần còn lại do
      // DeepLink và HomeScreen xử lý.
      onGenerateInitialRoutes: (_) => [entry()],
      onGenerateRoute: (_) => entry(),
    );
  }
}
