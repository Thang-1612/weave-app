import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n.dart';

String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  if (m < 1) return tr('dưới 1 phút', 'under 1 min');
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return tr('$m phút', '$m min');
  final mm = r.toString().padLeft(2, '0');
  return tr('$h giờ $mm phút', '${h}h ${mm}m');
}

/// Đo thời gian dùng ứng dụng trên thiết bị này, nhắc nghỉ và giới hạn mỗi ngày.
class UsageService with WidgetsBindingObserver {
  UsageService._();
  static final UsageService instance = UsageService._();

  static const _tick = Duration(seconds: 30);

  Timer? _timer;
  bool _started = false;
  BuildContext? Function()? _ctx;

  int _limitMin = 0;
  int _breakMin = 0;
  String? _loadedFor;
  DateTime? _snoozeUntil;
  String? _disabledDay;
  int _session = 0;
  bool _dialogOpen = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static String _dayKey(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// Bắt đầu đo. [contextProvider] trả về context để hiện hộp thoại nhắc.
  void start(BuildContext? Function() contextProvider) {
    _ctx = contextProvider;
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
    _ctx = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _pause();
    }
  }

  void _resume() {
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) => _onTick());
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    _session = 0; // rời ứng dụng thì tính lại phiên dùng liên tục
  }

  // --------------------------- Cài đặt ---------------------------------

  Future<void> _loadSettings() async {
    final uid = _uid;
    if (uid == null || _loadedFor == uid) return;
    final p = await SharedPreferences.getInstance();
    _limitMin = p.getInt('usage_limit_$uid') ?? 0;
    _breakMin = p.getInt('usage_break_$uid') ?? 0;
    _loadedFor = uid;
  }

  Future<int> dailyLimitMinutes() async {
    await _loadSettings();
    return _limitMin;
  }

  Future<int> breakEveryMinutes() async {
    await _loadSettings();
    return _breakMin;
  }

  Future<void> setDailyLimit(int minutes) async {
    final uid = _uid;
    if (uid == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt('usage_limit_$uid', minutes);
    _limitMin = minutes;
    _loadedFor = uid;
    _snoozeUntil = null;
    _disabledDay = null;
  }

  Future<void> setBreakEvery(int minutes) async {
    final uid = _uid;
    if (uid == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt('usage_break_$uid', minutes);
    _breakMin = minutes;
    _loadedFor = uid;
    _session = 0;
  }

  // --------------------------- Thống kê ---------------------------------

  Future<int> secondsOn(DateTime day) async {
    final uid = _uid;
    if (uid == null) return 0;
    final p = await SharedPreferences.getInstance();
    return p.getInt('usage_${uid}_${_dayKey(day)}') ?? 0;
  }

  /// Số giây dùng mỗi ngày trong [days] ngày gần nhất, ngày cũ nhất đứng trước.
  Future<List<int>> lastDays(int days) async {
    final now = DateTime.now();
    return [
      for (var i = days - 1; i >= 0; i--)
        await secondsOn(now.subtract(Duration(days: i))),
    ];
  }

  // ------------------------- Nhắc và giới hạn ----------------------------

  Future<void> _onTick() async {
    final uid = _uid;
    if (uid == null) return;
    await _loadSettings();

    final p = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final key = 'usage_${uid}_${_dayKey(today)}';
    final total = (p.getInt(key) ?? 0) + _tick.inSeconds;
    await p.setInt(key, total);
    _session += _tick.inSeconds;

    if (_dialogOpen) return;

    if (_limitMin > 0 &&
        total >= _limitMin * 60 &&
        _disabledDay != _dayKey(today)) {
      final snooze = _snoozeUntil;
      if (snooze == null || DateTime.now().isAfter(snooze)) {
        await _promptLimit(total, _limitMin);
        return;
      }
    }

    if (_breakMin > 0 && _session >= _breakMin * 60) {
      _session = 0;
      await _promptBreak();
    }
  }

  Future<void> _promptLimit(int total, int limit) async {
    final ctx = _ctx?.call();
    if (ctx == null || !ctx.mounted) return;
    _dialogOpen = true;
    final choice = await showDialog<String>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.timer_outlined, size: 32),
        title: Text(tr('Đã đến giới hạn thời gian', 'Daily limit reached')),
        content: Text(
          tr(
            'Hôm nay bạn đã dùng ${formatDuration(total)}, đạt giới hạn $limit phút bạn đã đặt. Nghỉ ngơi một chút nhé!',
            'Today you used ${formatDuration(total)}, reaching the $limit-minute limit you set. Time for a break!',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop('off'),
            child: Text(tr('Tắt giới hạn hôm nay', 'Turn off for today')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop('snooze'),
            child: Text(tr('Nhắc lại sau 15 phút', 'Remind me in 15 min')),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (choice == 'off') {
      _disabledDay = _dayKey(DateTime.now());
    } else {
      _snoozeUntil = DateTime.now().add(const Duration(minutes: 15));
    }
  }

  Future<void> _promptBreak() async {
    final ctx = _ctx?.call();
    if (ctx == null || !ctx.mounted) return;
    _dialogOpen = true;
    await showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.self_improvement, size: 32),
        title: Text(tr('Nghỉ giải lao nhé', 'Time for a break')),
        content: Text(
          tr(
            'Bạn đã dùng ứng dụng liên tục $_breakMin phút. Đứng dậy, uống nước và nhìn ra xa một chút.',
            'You have been using the app for $_breakMin minutes. Stand up, drink some water and look into the distance.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(c).pop(),
            child: Text(tr('Đã hiểu', 'Got it')),
          ),
        ],
      ),
    );
    _dialogOpen = false;
  }
}