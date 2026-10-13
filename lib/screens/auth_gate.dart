import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/expired_cleanup.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user != null) {
          // Dọn bài hết hạn của chính mình (chạy ngầm, một lần mỗi đăng nhập)
          ExpiredCleanup.runOnce(user.uid);
        }
        return user != null ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}