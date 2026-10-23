import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

/// Tên hiển thị (họ + tên) của người dùng, null nếu chưa có.
String? nameOf(User? user) {
  final name = user?.displayName?.trim();
  return (name == null || name.isEmpty) ? null : name;
}

/// Tên hiển thị, nếu chưa có thì dùng email.
String displayNameOf(User? user) {
  return nameOf(user) ?? user?.email ?? msgUser;
}

/// Chữ cái đại diện: với tên là chữ cái đầu của tên gọi (từ cuối),
/// với email là ký tự đầu tiên.
String initialOf(String text) {
  final words = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final w = text.contains('@') ? words.first : words.last;
  return String.fromCharCode(w.runes.first).toUpperCase();
}

/// Lưu danh sách email (và tên hiển thị) các tài khoản đã đăng nhập trên máy này.
/// Không lưu mật khẩu.
class AccountService {
  static const _key = 'saved_accounts';
  static const _namesKey = 'saved_account_names';

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.from(prefs.getStringList(_key) ?? []);
  }

  static Future<Map<String, String>> loadNames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_namesKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> add(String email, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    final value = email.trim().toLowerCase();
    if (value.isEmpty) return;

    final list = List<String>.from(prefs.getStringList(_key) ?? []);
    if (!list.contains(value)) {
      list.add(value);
      await prefs.setStringList(_key, list);
    }

    final n = name?.trim();
    if (n != null && n.isNotEmpty) {
      final names = await loadNames();
      names[value] = n;
      await prefs.setString(_namesKey, jsonEncode(names));
    }
  }

  static Future<void> remove(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final value = email.trim().toLowerCase();

    final list = List<String>.from(prefs.getStringList(_key) ?? []);
    list.remove(value);
    await prefs.setStringList(_key, list);

    final names = await loadNames();
    names.remove(value);
    await prefs.setString(_namesKey, jsonEncode(names));
  }
}
