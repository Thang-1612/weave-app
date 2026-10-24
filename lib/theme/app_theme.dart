import 'package:flutter/material.dart';

/// Weave design system (Bước 1).
/// Một nguồn duy nhất cho màu, khoảng cách, bo góc, kích thước và typography.
/// Mọi layout responsive đều dùng các token này, không hard-code số lẻ.

class AppColors {
  AppColors._();

  // Bảng màu chính thức
  static const brand = Color(
    0xFF4F46E5,
  ); // Brand Indigo: nút chính, mục chọn, liên kết
  static const background = Color(0xFFF7F7FB); // Nền toàn ứng dụng
  static const surface = Color(0xFFFFFFFF); // Card, menu, thanh điều hướng
  static const textPrimary = Color(0xFF202235); // Tiêu đề, nội dung chính
  static const textSecondary = Color(0xFF6B7280); // Mô tả, thời gian, metadata
  static const border = Color(0xFFE6E7EF); // Viền card, phân cách
  static const soft = Color(0xFFEEF2FF); // Nền mục được chọn, chip nhẹ
  static const teal = Color(0xFF0F766E); // Thành công, điểm nhấn phụ
  static const danger = Color(0xFFDC2626); // Xóa, lỗi, hành động nguy hiểm
  /// Màu chữ/icon đặt trên nền brand.
  static const Color onBrand = Colors.white;

  // [MỚI] Token màu trạng thái: bản đậm dùng cho chữ/icon, bản Soft dùng làm nền chip, banner.
  static const warning = Color(0xFFB45309); // Cảnh báo, chờ xử lý
  static const warningSoft = Color(0xFFFEF3C7);
  static const successSoft = Color(0xFFCCFBF1);
  static const dangerSoft = Color(0xFFFEE2E2);
  static const warningBorder = Color(0xFFFDE68A);
  static const brandTint = Color(0xFFC7D2FE); // thanh chon, nhan nhe
  static const borderStrong = Color(0xFFD1D5DB); // dam hon border

  /// Chỉ giữ để tương thích code cũ và để dùng trong gradient điểm nhấn.
  /// Không dùng làm màu giao diện thông thường.
  static const pink = Color(0xFFDB2777);

  /// Gradient chỉ dành cho điểm nhấn nhỏ (logo, huy hiệu, banner đặc biệt).
  /// Không dùng cho AppBar, nút thường hay tiêu đề.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, brand, pink],
  );
}

/// Thang khoảng cách: 4, 8, 12, 16, 24, 32.
class WeaveSpacing {
  WeaveSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class WeaveRadius {
  WeaveRadius._();
  static const double card = 16; // card
  static const double control = 12; // nút, input, mục menu
  static const double pill = 999;

  // Tên cũ, giữ để tương thích.
  static const double sm = 8;
  static const double md = control;
  static const double lg = card;
}

class WeaveSizes {
  WeaveSizes._();
  static const double buttonHeight = 48; // nút chính 44–48
  static const double buttonHeightCompact = 44;
  static const double contentMaxWidth = 1440;
}

/// Padding trang: mobile 12–16, desktop 24–32.
class WeavePagePadding {
  WeavePagePadding._();
  static const double mobile = WeaveSpacing.lg; // 16
  static const double tablet = WeaveSpacing.xl; // 24
  static const double desktop = WeaveSpacing.xxl; // 32
}

/// Căn giữa nội dung tối đa [maxWidth], nhưng ListView vẫn chiếm full chiều
/// rộng khung chứa. Nhờ vậy lăn chuột ở hai lề trên desktop vẫn cuộn được
/// (khác với bọc ListView trong ConstrainedBox).
///
/// Dùng: ListView(padding: weaveCenteredPadding(constraints.maxWidth), ...)
EdgeInsets weaveCenteredPadding(
  double width, {
  double maxWidth = 600,
  double h = WeavePagePadding.mobile,
  double top = WeaveSpacing.lg,
  double bottom = WeaveSpacing.lg,
}) {
  final extra = width > maxWidth ? (width - maxWidth) / 2 : 0.0;
  final side = extra + h;
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.brand,
        onPrimary: Colors.white,
        primaryContainer: AppColors.soft,
        onPrimaryContainer: AppColors.brand,
        secondary: AppColors.teal,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        error: AppColors.danger,
        onError: Colors.white,
        outline: AppColors.border,
        outlineVariant: AppColors.border,
      );

  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(WeaveRadius.control),
  );
  const buttonMin = Size(64, WeaveSizes.buttonHeight);
  const buttonPadding = EdgeInsets.symmetric(horizontal: WeaveSpacing.xl);
  const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(WeaveRadius.control),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    listTileTheme: const ListTileThemeData(
      selectedColor: AppColors.brand,
      selectedTileColor: AppColors.soft,
    ),

    // Typography: tiêu đề trang 24–30, nội dung 14–16, metadata 12–13.
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.25,
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textPrimary),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: AppColors.border)),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WeaveRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    // Hộp thoại, bottom sheet, chip: nền trắng, bo 16, không bị tô tím của M3.
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WeaveRadius.card),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WeaveRadius.card),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.soft,
      checkmarkColor: AppColors.brand,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      secondaryLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.brand,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WeaveRadius.control),
      ),
    ),

    // Nút: cao 48, bo 12. Chỉ FilledButton là nút nổi bật (một hành động chính/màn hình).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        minimumSize: buttonMin,
        padding: buttonPadding,
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: buttonMin,
        padding: buttonPadding,
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: buttonMin,
        padding: buttonPadding,
        shape: controlShape,
        side: const BorderSide(color: AppColors.border),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        minimumSize: const Size(64, WeaveSizes.buttonHeightCompact),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WeaveRadius.card),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: WeaveSpacing.lg,
        vertical: WeaveSpacing.md,
      ),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      border: inputBorder(AppColors.border),
      enabledBorder: inputBorder(AppColors.border),
      focusedBorder: inputBorder(AppColors.brand, 1.5),
      errorBorder: inputBorder(AppColors.danger),
      focusedErrorBorder: inputBorder(AppColors.danger, 1.5),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: controlShape,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.soft,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.brand : AppColors.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.brand : AppColors.textSecondary,
        );
      }),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.soft,
      selectedIconTheme: IconThemeData(color: AppColors.brand),
      unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.brand,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
