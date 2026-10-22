import 'package:flutter/widgets.dart';
import 'app_theme.dart';

/// Mọi ngưỡng responsive của Weave nằm ở đây. Sửa một chỗ, cả app đổi theo.
class Breakpoints {
  Breakpoints._();
  static const double tablet = 600; // từ đây: NavigationRail
  static const double desktop = 1000; // từ đây: sidebar đầy đủ
  static const double widePanel = 1200; // từ đây: mở panel phụ. Đang giữ 1200 = hành vi cũ; thử 1360 sau khi đo
}

enum ScreenSize { mobile, tablet, desktop }

ScreenSize screenSizeOf(double width) {
  if (width >= Breakpoints.desktop) return ScreenSize.desktop;
  if (width >= Breakpoints.tablet) return ScreenSize.tablet;
  return ScreenSize.mobile;
}

/// Padding trang theo kích thước. Dùng: pagePaddingOf(constraints.maxWidth)
double pagePaddingOf(double width) {
  switch (screenSizeOf(width)) {
    case ScreenSize.mobile:
      return WeavePagePadding.mobile;
    case ScreenSize.tablet:
      return WeavePagePadding.tablet;
    case ScreenSize.desktop:
      return WeavePagePadding.desktop;
  }
}

extension ScreenSizeContext on BuildContext {
  /// Chiều rộng cửa sổ. Ưu tiên LayoutBuilder khi bố cục phụ thuộc vùng chứa.
  ScreenSize get screenSize => screenSizeOf(MediaQuery.sizeOf(this).width);
}