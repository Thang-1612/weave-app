import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/weave_responsive_shell.dart';

/// Static UI demo only. Replace callbacks/body with real Weave screens/services
/// when integrating into the app.
class ResponsiveHomeDemo extends StatefulWidget {
  const ResponsiveHomeDemo({super.key});

  @override
  State<ResponsiveHomeDemo> createState() => _ResponsiveHomeDemoState();
}

class _ResponsiveHomeDemoState extends State<ResponsiveHomeDemo> {
  int _selected = 0;

  static const _destinations = [
    WeaveDestination(
      label: 'Trang chủ',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    WeaveDestination(
      label: 'Khám phá',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
    ),
    WeaveDestination(
      label: 'Bạn bè',
      icon: Icons.people_outline,
      selectedIcon: Icons.people_rounded,
    ),
    WeaveDestination(
      label: 'Tin nhắn',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_rounded,
    ),
    WeaveDestination(
      label: 'Ký ức',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return WeaveResponsiveShell(
      title: _destinations[_selected].label,
      destinations: _destinations,
      selectedIndex: _selected,
      onDestinationSelected: (index) => setState(() => _selected = index),
      onCreate: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo: mở màn hình tạo nội dung')),
        );
      },
      actions: [
        IconButton(
          tooltip: 'Tìm kiếm',
          onPressed: () {},
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
      secondaryPanel: const _RightColumn(),
      body: _DemoHomeContent(selectedIndex: _selected),
    );
  }
}

class _DemoHomeContent extends StatelessWidget {
  const _DemoHomeContent({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    // Panel phụ bên phải chỉ có ở desktop đủ rộng; nếu bị ẩn thì cùng nội dung
    // đó được xếp xuống dưới. Không viết hai bản logic.
    final panelVisible = WeaveLayout.of(context).secondaryPanelVisible;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedIndex == 0 ? 'Chào bạn 👋' : 'Khám phá Weave',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: WeaveSpacing.sm),
          Text(
            'Nơi những khoảnh khắc nhỏ trở thành ký ức chung.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: WeaveSpacing.xl),
          _CreatePrompt(),
          const SizedBox(height: WeaveSpacing.xl),
          const _FeedColumn(),
          if (!panelVisible) ...const [
            SizedBox(height: WeaveSpacing.lg),
            _RightColumn(),
          ],
        ],
      ),
    );
  }
}

class _CreatePrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WeaveSpacing.lg),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.soft,
              child: Icon(Icons.edit_outlined, color: AppColors.brand),
            ),
            const SizedBox(width: WeaveSpacing.md),
            const Expanded(
              child: Text(
                'Bạn muốn lưu giữ khoảnh khắc nào?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            // Hành động chính nổi bật đã nằm ở nút "Tạo khoảnh khắc"/FAB,
            // nên nút này dùng kiểu viền để màn hình chỉ có một nút tím.
            OutlinedButton(
              onPressed: () {},
              child: const Text('Tạo bài'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedColumn extends StatelessWidget {
  const _FeedColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _FeedCard(
          icon: Icons.groups_rounded,
          label: 'HÀNH TRÌNH',
          title: 'Một ngày cuối tuần cùng bạn bè',
          description:
          'Tập hợp ảnh, khoảnh khắc và câu chuyện vào cùng một nơi.',
          color: AppColors.teal,
        ),
        SizedBox(height: WeaveSpacing.lg),
        _FeedCard(
          icon: Icons.auto_awesome_rounded,
          label: 'KÝ ỨC',
          title: 'Những điều đáng nhớ',
          description:
          'Xem lại những khoảnh khắc và câu chuyện bạn đã lưu.',
          color: AppColors.brand,
        ),
      ],
    );
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(WeaveSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Sắp diễn ra',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: WeaveSpacing.lg),
                _MiniRow(
                  icon: Icons.coffee_outlined,
                  title: 'Cà phê cuối tuần',
                  subtitle: 'Thứ Bảy · 4 thành viên',
                ),
                Divider(height: WeaveSpacing.xl),
                _MiniRow(
                  icon: Icons.photo_library_outlined,
                  title: 'Album chuyến đi',
                  subtitle: '3 khoảnh khắc mới',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: WeaveSpacing.lg),
        Card(
          color: AppColors.soft,
          child: const Padding(
            padding: EdgeInsets.all(WeaveSpacing.lg),
            child: Row(
              children: [
                Icon(Icons.favorite_outline, color: AppColors.brand, size: 28),
                SizedBox(width: WeaveSpacing.md),
                Expanded(
                  child: Text(
                    'Kết nối với người quan trọng, theo cách của bạn.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.icon,
    required this.label,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WeaveSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(WeaveRadius.control),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: WeaveSpacing.md),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: WeaveSpacing.lg),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: WeaveSpacing.sm),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: WeaveSpacing.lg),
            const Row(
              children: [
                Icon(Icons.favorite_border, size: 20, color: AppColors.textSecondary),
                SizedBox(width: WeaveSpacing.lg),
                Icon(Icons.mode_comment_outlined, size: 20, color: AppColors.textSecondary),
                SizedBox(width: WeaveSpacing.lg),
                Icon(Icons.share_outlined, size: 20, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(WeaveSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(WeaveRadius.control),
          ),
          child: Icon(icon, color: AppColors.brand),
        ),
        const SizedBox(width: WeaveSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: WeaveSpacing.xs),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
