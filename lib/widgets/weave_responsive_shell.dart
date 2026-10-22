import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Ba chế độ bố cục theo chiều rộng khả dụng của khung.
enum WeaveLayoutMode { mobile, tablet, desktop }

// Breakpoint ban đầu: cần thử với kích thước cửa sổ thật và chỉnh nếu
// một màn hình cần nhiều không gian hơn.
const double kWeaveTabletBreakpoint = 600;
const double kWeaveDesktopBreakpoint = 1000;

/// Từ chiều rộng này trở lên (chỉ ở desktop) panel phụ bên phải mới hiện.
const double kWeaveSecondaryPanelMinWidth = 1200;
const double kWeaveSidebarWidth = 240;

WeaveLayoutMode layoutForWidth(double width) {
  if (width < kWeaveTabletBreakpoint) return WeaveLayoutMode.mobile;
  if (width < kWeaveDesktopBreakpoint) return WeaveLayoutMode.tablet;
  return WeaveLayoutMode.desktop;
}

/// Tên cũ, giữ để tương thích.
WeaveLayoutMode weaveLayoutForWidth(double width) => layoutForWidth(width);

/// Thông tin bố cục mà khung cung cấp cho mọi widget bên dưới nó.
class WeaveLayoutInfo {
  const WeaveLayoutInfo({
    required this.mode,
    required this.secondaryPanelVisible,
  });

  final WeaveLayoutMode mode;

  /// true khi panel phụ đang hiện bên phải. Nếu false, nội dung của panel
  /// nên được đưa vào luồng chính (ví dụ xếp dưới danh sách).
  final bool secondaryPanelVisible;

  bool get isMobile => mode == WeaveLayoutMode.mobile;
  bool get isTablet => mode == WeaveLayoutMode.tablet;
  bool get isDesktop => mode == WeaveLayoutMode.desktop;
}

/// Đọc bố cục hiện tại: `WeaveLayout.of(context).isDesktop`.
/// Chỉ dùng được bên dưới [WeaveResponsiveShell].
class WeaveLayout extends InheritedWidget {
  const WeaveLayout({super.key, required this.info, required super.child});

  final WeaveLayoutInfo info;

  static WeaveLayoutInfo of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WeaveLayout>();
    assert(scope != null, 'WeaveLayout.of() gọi ngoài WeaveResponsiveShell');
    return scope!.info;
  }

  @override
  bool updateShouldNotify(WeaveLayout oldWidget) =>
      info.mode != oldWidget.info.mode ||
          info.secondaryPanelVisible != oldWidget.info.secondaryPanelVisible;
}

class WeaveDestination {
  const WeaveDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.iconWrapper,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Bọc icon, ví dụ gắn huy hiệu chưa đọc:
  /// `(icon, selected) => UnreadBadge(key: ValueKey('x-$selected'), child: icon)`.
  final Widget Function(Widget icon, bool selected)? iconWrapper;

  Widget buildIcon(bool selected, {double? size, Color? color}) {
    final Widget w = Icon(selected ? selectedIcon : icon, size: size, color: color);
    final wrap = iconWrapper;
    return wrap == null ? w : wrap(w, selected);
  }
}

/// Khung điều hướng responsive. Cùng một body, cùng trạng thái và service;
/// chỉ thay đổi cách trình bày điều hướng theo chiều rộng thực tế của khung.
///
/// - mobile (<600): thanh điều hướng dưới, một cột, nút tạo trên AppBar
/// - tablet (600-999): NavigationRail, FAB tạo mới
/// - desktop (>=1000): sidebar cố định, panel phụ bên phải khi đủ rộng
class WeaveResponsiveShell extends StatelessWidget {
  const WeaveResponsiveShell({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.actions = const [],
    this.appBar,
    this.appBarBuilder,
    this.drawer,
    this.sidebarExtra,
    this.secondaryPanel,
    this.secondaryPanelWidth = 320,
    this.onCreate,
    this.floatingActionButton,
    this.maxContentWidth = WeaveSizes.contentMaxWidth,
    this.contentPadding,
    this.createLabel = 'Tạo mới',
    this.sidebarCreateLabel = 'Tạo khoảnh khắc',
  });

  final String title;
  final List<WeaveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final List<Widget> actions;

  /// Thay AppBar mặc định (ví dụ mỗi trang một AppBar riêng).
  final PreferredSizeWidget? appBar;

  /// Như [appBar] nhưng biết bố cục hiện tại (ví dụ chỉ thêm nút "+" ở mobile).
  /// Được ưu tiên hơn [appBar].
  final PreferredSizeWidget Function(BuildContext context, WeaveLayoutInfo info)?
  appBarBuilder;

  /// Menu trượt, chỉ dùng ở mobile và tablet. Desktop dùng [sidebarExtra].
  final Widget? drawer;

  /// Nội dung thêm dưới các mục điều hướng trong sidebar desktop (cuộn được).
  final Widget? sidebarExtra;

  /// Panel phụ bên phải, chỉ hiện ở desktop đủ rộng. Khi bị ẩn, đọc
  /// `WeaveLayout.of(context).secondaryPanelVisible` để đưa nội dung vào body.
  final Widget? secondaryPanel;
  final double secondaryPanelWidth;

  final VoidCallback? onCreate;
  final Widget? floatingActionButton;
  final double maxContentWidth;

  /// null = padding mặc định theo chế độ (16 / 24 / 32). Truyền
  /// `EdgeInsets.zero` khi các màn hình bên trong tự lo phần đệm lề.
  final EdgeInsetsGeometry? contentPadding;
  final String createLabel;
  final String sidebarCreateLabel;

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder đo đúng không gian của khung này, không phải cả cửa sổ,
    // nên khung đặt trong một panel nhỏ vẫn chọn đúng bố cục.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final mode = layoutForWidth(width);
        final isMobile = mode == WeaveLayoutMode.mobile;
        final isTablet = mode == WeaveLayoutMode.tablet;
        final isDesktop = mode == WeaveLayoutMode.desktop;
        final showPanel = isDesktop &&
            secondaryPanel != null &&
            width >= kWeaveSecondaryPanelMinWidth;
        final pad = isMobile
            ? WeavePagePadding.mobile
            : isDesktop
            ? WeavePagePadding.desktop
            : WeavePagePadding.tablet;

        final info = WeaveLayoutInfo(
          mode: mode,
          secondaryPanelVisible: showPanel,
        );
        final builder = appBarBuilder;
        final PreferredSizeWidget resolvedAppBar = builder != null
            ? builder(context, info)
            : (appBar ??
            _buildAppBar(isMobile: isMobile, isDesktop: isDesktop));

        return WeaveLayout(
          info: info,
          child: Scaffold(
            appBar: resolvedAppBar,
            drawer: isDesktop ? null : drawer,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDesktop) _buildDesktopSidebar(),
                if (isTablet) _buildRail(constraints.maxHeight),
                // Key cố định: khi đổi cỡ cửa sổ, vùng nội dung giữ nguyên
                // state (vị trí cuộn, ô đang nhập...).
                Expanded(
                  key: const ValueKey('weave-content'),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Padding(
                        padding: contentPadding ?? EdgeInsets.all(pad),
                        child: body,
                      ),
                    ),
                  ),
                ),
                if (showPanel)
                  SizedBox(
                    key: const ValueKey('weave-panel'),
                    width: secondaryPanelWidth + pad,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(0, pad, pad, pad),
                      child: secondaryPanel,
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: isMobile
                ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (final d in destinations.take(5))
                  NavigationDestination(
                    icon: d.buildIcon(false),
                    selectedIcon: d.buildIcon(true),
                    label: d.label,
                  ),
              ],
            )
                : null,
            // Mỗi chế độ chỉ có một hành động chính nổi bật:
            // mobile = nút + trên AppBar, tablet = FAB, desktop = nút ở sidebar.
            floatingActionButton: floatingActionButton ??
                (isTablet && onCreate != null
                    ? FloatingActionButton.extended(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: Text(createLabel),
                )
                    : null),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar({required bool isMobile, required bool isDesktop}) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Desktop đã có logo ở sidebar.
          if (!isDesktop) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(WeaveRadius.control),
              ),
              child: const Icon(
                Icons.all_inclusive_rounded,
                color: AppColors.brand,
                size: 20,
              ),
            ),
            const SizedBox(width: WeaveSpacing.sm),
          ],
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: [
        ...actions,
        if (isMobile && onCreate != null)
          IconButton(
            tooltip: createLabel,
            onPressed: onCreate,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        const SizedBox(width: WeaveSpacing.sm),
      ],
    );
  }

  Widget _buildRail(double shellHeight) {
    return NavigationRail(
      key: const ValueKey('weave-rail'),
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      // Cửa sổ thấp: bỏ nhãn để rail không tràn theo chiều dọc.
      labelType: shellHeight < 520
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: d.buildIcon(false),
            selectedIcon: d.buildIcon(true),
            label: Text(d.label),
          ),
      ],
    );
  }

  Widget _buildDesktopSidebar() {
    // Material (không phải Container tô màu) để ListTile trong sidebar vẽ được
    // hiệu ứng chạm và nền mục đang chọn.
    return SizedBox(
      key: const ValueKey('weave-sidebar'),
      width: kWeaveSidebarWidth,
      child: Material(
        color: AppColors.surface,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    WeaveSpacing.xl,
                    WeaveSpacing.lg,
                    WeaveSpacing.lg,
                    WeaveSpacing.xl,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.soft,
                          borderRadius: BorderRadius.circular(WeaveRadius.control),
                        ),
                        child: const Icon(
                          Icons.all_inclusive_rounded,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(width: WeaveSpacing.md),
                      const Text(
                        'Weave',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                // Vùng giữa cuộn được: cửa sổ thấp hay menu dài đều không tràn.
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < destinations.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: WeaveSpacing.md,
                            vertical: WeaveSpacing.xs,
                          ),
                          child: _SidebarItem(
                            destination: destinations[i],
                            selected: selectedIndex == i,
                            onTap: () => onDestinationSelected(i),
                          ),
                        ),
                      ?sidebarExtra,
                    ],
                  ),
                ),
                if (onCreate != null)
                  Padding(
                    padding: const EdgeInsets.all(WeaveSpacing.lg),
                    child: FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add),
                      label: Text(sidebarCreateLabel),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(WeaveSizes.buttonHeight),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final WeaveDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.soft : Colors.transparent,
      borderRadius: BorderRadius.circular(WeaveRadius.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(WeaveRadius.control),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WeaveSpacing.md,
            vertical: WeaveSpacing.md,
          ),
          child: Row(
            children: [
              destination.buildIcon(
                selected,
                size: 22,
                color: selected ? AppColors.brand : AppColors.textSecondary,
              ),
              const SizedBox(width: WeaveSpacing.md),
              Expanded(
                child: Text(
                  destination.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? AppColors.brand : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
