import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/l10n.dart';
import '../../services/usage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_widgets.dart';
import '../../widgets/weave_ui.dart';

class TimeManagementScreen extends StatefulWidget {
  const TimeManagementScreen({super.key});

  @override
  State<TimeManagementScreen> createState() => _TimeManagementScreenState();
}

class _TimeManagementScreenState extends State<TimeManagementScreen> {
  final _usage = UsageService.instance;
  Timer? _timer;
  bool _loaded = false;
  int _today = 0;
  List<int> _week = List.filled(7, 0);
  int _limit = 0;
  int _break = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final today = await _usage.secondsOn(DateTime.now());
    final week = await _usage.lastDays(7);
    final limit = await _usage.dailyLimitMinutes();
    final brk = await _usage.breakEveryMinutes();
    if (!mounted) return;
    setState(() {
      _today = today;
      _week = week;
      _limit = limit;
      _break = brk;
      _loaded = true;
    });
  }

  String _weekday(DateTime d) {
    const vi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return tr(vi[d.weekday - 1], en[d.weekday - 1]);
  }

  Widget _chips({
    required List<int> options,
    required int value,
    required ValueChanged<int> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final m in options)
            ChoiceChip(
              label:
              Text(m == 0 ? tr('Tắt', 'Off') : '$m ${tr('phút', 'min')}'),
              selected: value == m,
              onSelected: (_) => onSelected(m),
            ),
        ],
      ),
    );
  }

  Widget _chart() {
    final now = DateTime.now();
    final maxSec = _week.fold<int>(0, (a, b) => a > b ? a : b);
    const maxHeight = 110.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _week[i] >= 60 ? '${_week[i] ~/ 60}' : '',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: maxSec == 0
                        ? 4
                        : (maxHeight * _week[i] / maxSec)
                        .clamp(4.0, maxHeight),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: i == 6 ? AppColors.brand : AppColors.soft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _weekday(now.subtract(Duration(days: 6 - i))),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == 6 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Thẻ tóm tắt hôm nay: phẳng, số lớn màu Brand; chạm giới hạn thì thanh
  /// tiến độ chuyển sang Danger.
  Widget _todayCard(double? progress) {
    final overLimit = progress != null && progress >= 1;
    return Container(
      padding: const EdgeInsets.all(WeaveSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(WeaveRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Hôm nay bạn đã dùng', 'Today you used'),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            formatDuration(_today),
            style: const TextStyle(
              color: AppColors.brand,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.soft,
                color: overLimit ? AppColors.danger : AppColors.brand,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${tr('Giới hạn', 'Limit')}: $_limit ${tr('phút', 'min')}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avg = _week.isEmpty ? 0 : _week.reduce((a, b) => a + b) ~/ 7;
    final progress = _limit > 0
        ? (_today / (_limit * 60)).clamp(0.0, 1.0).toDouble()
        : null;

    return SettingsScaffold(
      title: tr('Quản lý thời gian', 'Time management'),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : settingsList([
        _todayCard(progress),
        SectionLabel(tr('7 ngày gần nhất', 'Last 7 days')),
        SettingsCard(children: [_chart()]),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Text(
            '${tr('Trung bình mỗi ngày', 'Daily average')}: ${formatDuration(avg)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        SectionLabel(tr('Giới hạn mỗi ngày', 'Daily limit')),
        SettingsCard(
          children: [
            _chips(
              options: const [0, 30, 60, 90, 120, 180],
              value: _limit,
              onSelected: (m) async {
                await _usage.setDailyLimit(m);
                _load();
              },
            ),
          ],
        ),
        SectionLabel(tr('Nhắc nghỉ giải lao', 'Break reminders')),
        SettingsCard(
          children: [
            _chips(
              options: const [0, 15, 30, 45, 60],
              value: _break,
              onSelected: (m) async {
                await _usage.setBreakEvery(m);
                _load();
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Text(
            tr(
              'Thời gian chỉ tính khi ứng dụng đang mở trên thiết bị này. Khi đạt giới hạn hoặc đến lúc nghỉ, ứng dụng sẽ hiện một lời nhắc.',
              'Time is counted only while the app is open on this device. When you reach your limit or a break is due, the app shows a reminder.',
            ),
            style: const TextStyle(
                color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      ]),
    );
  }
}