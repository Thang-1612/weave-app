import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Widget dùng chung của Weave (Bước 6).
/// Đặt tại lib/widgets/weave_ui.dart. Chỉ dùng token từ app_theme.dart.
/// Không tạo phiên bản card/nút riêng cho từng màn hình: nếu chỉ khác màu
/// hoặc nội dung thì dùng tham số của các widget dưới đây.

// ---------------------------------------------------------------------------
// WeaveCard
// ---------------------------------------------------------------------------

/// Nền trắng, viền mảnh, bo 16, không đổ bóng.
/// Có [onTap] thì tự có hiệu ứng chạm đúng góc bo.
class WeaveCard extends StatelessWidget {
  const WeaveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(WeaveSpacing.lg),
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Nền khác (ví dụ AppColors.soft cho thẻ được chọn).
  final Color? color;

  /// Viền khác (ví dụ AppColors.brand cho thẻ được chọn).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final card = Material(
      color: color ?? AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WeaveRadius.card),
        side: BorderSide(color: borderColor ?? AppColors.border),
      ),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

// ---------------------------------------------------------------------------
// Nút
// ---------------------------------------------------------------------------

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.loading,
    required this.spinnerColor,
    this.icon,
  });

  final String label;
  final bool loading;
  final Color spinnerColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor),
      );
    }
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: WeaveSpacing.sm),
        Flexible(child: text),
      ],
    );
  }
}

/// Nút chính: màu brand, cao 48 (44 nếu [compact]).
/// Mỗi màn hình chỉ nên có một nút này.
/// [loading] giữ nguyên kích thước nút và chặn bấm lặp.
/// [onPressed] = null thì nút ở trạng thái vô hiệu.
/// [danger] dùng cho hành động nguy hiểm (nhớ kèm hộp thoại xác nhận).
class WeavePrimaryButton extends StatelessWidget {
  const WeavePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.danger = false,
    this.compact = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool danger;
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    // Khi loading vẫn để nút "sáng" (không bị xám) nhưng bấm không làm gì.
    final VoidCallback? effective =
    onPressed == null ? null : (loading ? () {} : onPressed);

    final button = FilledButton(
      onPressed: effective,
      style: FilledButton.styleFrom(
        minimumSize: Size(
          64,
          compact ? WeaveSizes.buttonHeightCompact : WeaveSizes.buttonHeight,
        ),
        backgroundColor: danger ? AppColors.danger : null,
        disabledBackgroundColor:
        danger ? AppColors.danger.withValues(alpha: 0.35) : null,
        disabledForegroundColor: danger ? Colors.white : null,
      ),
      child: _ButtonContent(
        label: label,
        icon: icon,
        loading: loading,
        spinnerColor: Colors.white,
      ),
    );
    return expanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Nút phụ: nền trắng, viền nhẹ. [danger] đổi chữ và viền sang màu Danger.
class WeaveSecondaryButton extends StatelessWidget {
  const WeaveSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.danger = false,
    this.compact = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool danger;
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? effective =
    onPressed == null ? null : (loading ? () {} : onPressed);
    final fg = danger ? AppColors.danger : AppColors.textPrimary;

    final button = OutlinedButton(
      onPressed: effective,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(
          64,
          compact ? WeaveSizes.buttonHeightCompact : WeaveSizes.buttonHeight,
        ),
        foregroundColor: fg,
        backgroundColor: AppColors.surface,
        side: BorderSide(
          color: danger
              ? AppColors.danger.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: _ButtonContent(
        label: label,
        icon: icon,
        loading: loading,
        spinnerColor: fg,
      ),
    );
    return expanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

// ---------------------------------------------------------------------------
// WeaveSectionHeader
// ---------------------------------------------------------------------------

/// Tiêu đề khối, mô tả ngắn, và hành động nếu cần.
/// Truyền [action] (widget tùy ý) hoặc cặp [actionLabel] + [onAction].
class WeaveSectionHeader extends StatelessWidget {
  const WeaveSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget? trailing = action;
    if (trailing == null && actionLabel != null && onAction != null) {
      trailing = TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 36),
          padding: const EdgeInsets.symmetric(horizontal: WeaveSpacing.md),
        ),
        child: Text(actionLabel!),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: WeaveSpacing.xs),
                  Text(subtitle!, style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: WeaveSpacing.sm),
            trailing,
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WeaveAvatar
// ---------------------------------------------------------------------------

/// Avatar tròn, kích thước chuẩn, fallback chữ cái đầu (hoặc icon người)
/// khi thiếu ảnh, đang tải ảnh hoặc ảnh lỗi.
class WeaveAvatar extends StatelessWidget {
  const WeaveAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = md,
    this.onTap,
  });

  static const double sm = 32;
  static const double md = 40;
  static const double lg = 56;
  static const double xl = 96;

  final String? imageUrl;

  /// Dùng để lấy chữ cái đầu khi không có ảnh.
  final String? name;
  final double size;
  final VoidCallback? onTap;

  String get _initials {
    final words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    String first(String w) => String.fromCharCode(w.runes.first);
    final a = first(words.first);
    final b = words.length > 1 ? first(words.last) : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _AvatarFallback(size: size, initials: _initials);
    final url = imageUrl?.trim();

    Widget avatar = SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: (url == null || url.isEmpty)
            ? fallback
            : Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => fallback,
          loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
        ),
      ),
    );

    if (onTap != null) {
      avatar = InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: avatar,
      );
    }

    final label = (name ?? '').trim();
    return label.isEmpty
        ? avatar
        : Semantics(label: label, image: true, child: avatar);
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.size, required this.initials});

  final double size;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppColors.soft,
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, size: size * 0.55, color: AppColors.brand)
          : Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: AppColors.brand,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trạng thái rỗng, đang tải, lỗi
// ---------------------------------------------------------------------------

/// Icon + mô tả + CTA (nếu truyền cả [actionLabel] và [onAction]).
class WeaveEmptyState extends StatelessWidget {
  const WeaveEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(WeaveSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.soft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: AppColors.brand),
              ),
              const SizedBox(height: WeaveSpacing.lg),
              Text(title,
                  style: textTheme.titleMedium, textAlign: TextAlign.center),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: WeaveSpacing.xs),
                Text(message!,
                    style: textTheme.bodySmall, textAlign: TextAlign.center),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: WeaveSpacing.lg),
                WeavePrimaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  compact: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Vòng tải thống nhất, căn giữa, có thể kèm một dòng chú thích.
class WeaveLoadingState extends StatelessWidget {
  const WeaveLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WeaveSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.brand,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: WeaveSpacing.md),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thông báo lỗi dễ hiểu + nút thử lại. Không bao giờ hiển thị lỗi nội bộ.
/// Truyền [error] chỉ để ghi log khi chạy debug.
class WeaveErrorState extends StatelessWidget {
  const WeaveErrorState({
    super.key,
    this.title = 'Đã có lỗi xảy ra',
    this.message = 'Không thể tải dữ liệu. Hãy kiểm tra kết nối và thử lại.',
    this.retryLabel = 'Thử lại',
    this.onRetry,
    this.error,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode && error != null) {
      debugPrint('WeaveErrorState: $error');
    }
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(WeaveSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 28,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: WeaveSpacing.lg),
              Text(title,
                  style: textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: WeaveSpacing.xs),
              Text(message,
                  style: textTheme.bodySmall, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: WeaveSpacing.lg),
                WeaveSecondaryButton(
                  label: retryLabel,
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                  compact: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}