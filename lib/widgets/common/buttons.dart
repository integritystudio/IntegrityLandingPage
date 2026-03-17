import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

// =============================================================================
// Button State Mixin & Wrapper
// =============================================================================

/// Mixin providing common button state management for hover, focus, and disabled states.
///
/// Use this mixin on StatefulWidget State classes that need button-like behavior.
/// It provides:
/// - `isHovered`: Whether the mouse is over the widget
/// - `isFocused`: Whether the widget has keyboard focus
/// - `isDisabled`: Abstract getter (implement based on widget props)
/// - `cursor`: Mouse cursor based on disabled state
///
/// Usage:
/// ```dart
/// class _MyButtonState extends State<MyButton> with HoverableButtonMixin {
///   @override
///   bool get isDisabled => widget.onPressed == null;
///
///   @override
///   Widget build(BuildContext context) {
///     return buildHoverableButton(
///       onTap: widget.onPressed,
///       child: Container(...),
///     );
///   }
/// }
/// ```
mixin HoverableButtonMixin<T extends StatefulWidget> on State<T> {
  bool _isHovered = false;
  bool _isFocused = false;

  /// Whether the button is currently hovered
  bool get isHovered => _isHovered;

  /// Whether the button currently has focus
  bool get isFocused => _isFocused;

  /// Whether the button is disabled (implement in subclass)
  bool get isDisabled;

  /// Mouse cursor based on disabled state
  MouseCursor get cursor =>
      isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click;

  /// Handle hover state change
  void setHovered(bool hovered) {
    if (_isHovered != hovered) {
      setState(() => _isHovered = hovered);
    }
  }

  /// Handle focus state change
  void setFocused(bool focused) {
    if (_isFocused != focused) {
      setState(() => _isFocused = focused);
    }
  }

  /// Build the hoverable button wrapper with common behavior.
  ///
  /// This wraps the child with:
  /// - Semantics for accessibility
  /// - Focus handling for keyboard navigation
  /// - MouseRegion for hover effects
  /// - GestureDetector for tap handling
  Widget buildHoverableButton({
    required Widget child,
    VoidCallback? onTap,
    String? semanticLabel,
    bool excludeSemantics = false,
  }) {
    Widget result = Focus(
      onFocusChange: setFocused,
      child: MouseRegion(
        cursor: cursor,
        onEnter: (_) => setHovered(true),
        onExit: (_) => setHovered(false),
        child: GestureDetector(
          onTap: isDisabled ? null : onTap,
          child: child,
        ),
      ),
    );

    if (!excludeSemantics && semanticLabel != null) {
      result = Semantics(
        button: true,
        enabled: !isDisabled,
        label: semanticLabel,
        child: result,
      );
    }

    return result;
  }
}

/// Configuration for button content (text, icon, loading state)
class ButtonContent {
  final String text;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final Color textColor;
  final Color? iconColor;

  const ButtonContent({
    required this.text,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.textColor = Colors.white,
    this.iconColor,
  });

  /// Build the button's inner content (text, icon, loading indicator)
  Widget build() {
    return Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        else
          Flexible(
            child: Text(
              text,
              style: AppTypography.buttonText.copyWith(color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (icon != null && !isLoading) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(
            icon,
            size: 20,
            color: iconColor ?? textColor,
          ),
        ],
      ],
    );
  }
}

/// Standard button padding
const EdgeInsets kButtonPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.xl,
  vertical: AppSpacing.md,
);

/// Hover lift transform for elevated buttons
Matrix4 hoverLiftTransform(bool isHovered, bool isDisabled) {
  return isHovered && !isDisabled
      ? Matrix4.translationValues(0.0, -2.0, 0.0)
      : Matrix4.identity();
}

// =============================================================================
// Button Implementations
// =============================================================================

/// Base class for action buttons (AnimatedGradientBorderButton, GradientButton, OutlineButton)
abstract class BaseActionButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final String? semanticLabel;
  final bool fullWidth;

  const BaseActionButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.semanticLabel,
    this.fullWidth = false,
  });
}

/// Animated gradient border button (AiSDR-inspired design)
///
/// Features:
/// - Rotating gradient border animation (10s cycle)
/// - Smooth hover lift effect
/// - Inner gradient fill
/// - Respects reduced motion preferences
///
/// Usage:
/// ```dart
/// AnimatedGradientBorderButton(
///   text: 'Start Free Trial',
///   onPressed: () => startTrial(),
/// )
/// ```
class AnimatedGradientBorderButton extends BaseActionButton {
  const AnimatedGradientBorderButton({
    super.key,
    required super.text,
    super.onPressed,
    super.icon,
    super.isLoading,
    super.semanticLabel,
    super.fullWidth,
  });

  @override
  State<AnimatedGradientBorderButton> createState() =>
      _AnimatedGradientBorderButtonState();
}

class _AnimatedGradientBorderButtonState
    extends State<AnimatedGradientBorderButton>
    with SingleTickerProviderStateMixin, HoverableButtonMixin {
  late AnimationController _controller;

  @override
  bool get isDisabled => widget.isLoading || widget.onPressed == null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
      _controller.reset();
    // Guard against re-entrant calls on subsequent dependency changes
    // (e.g., theme or MediaQuery updates after initial mount).
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return buildHoverableButton(
      onTap: widget.onPressed,
      semanticLabel: widget.semanticLabel ?? widget.text,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: hoverLiftTransform(isHovered, isDisabled),
        child: AnimatedBuilder(
          animation: reduceMotion
              ? const AlwaysStoppedAnimation(0.0)
              : _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _GradientBorderPainter(
                rotation: reduceMotion ? 0.0 : _controller.value * 2 * math.pi,
                borderRadius: AppSpacing.radiusMD,
                strokeWidth: 2.0,
                gradient: const SweepGradient(
                  colors: [
                    AppColors.blue500,
                    AppColors.indigo500,
                    AppColors.purple500,
                    AppColors.blue500,
                  ],
                ),
              ),
              child: child,
            );
          },
          child: Container(
            width: widget.fullWidth ? double.infinity : null,
            padding: kButtonPadding,
            decoration: BoxDecoration(
              gradient: isDisabled
                  ? AppColors.disabledGradient
                  : AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              boxShadow: isDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: AppColors.shadowBlue,
                        blurRadius: isHovered ? 24 : 16,
                        offset: Offset(0, isHovered ? 6 : 4),
                      ),
                    ],
              border: isFocused
                  ? Border.all(color: AppColors.blue400, width: 2)
                  : null,
            ),
            child: ButtonContent(
              text: widget.text,
              icon: widget.icon,
              isLoading: widget.isLoading,
              fullWidth: widget.fullWidth,
            ).build(),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for rotating gradient border
class _GradientBorderPainter extends CustomPainter {
  final double rotation;
  final double borderRadius;
  final double strokeWidth;
  final Gradient gradient;

  _GradientBorderPainter({
    required this.rotation,
    required this.borderRadius,
    required this.strokeWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );

    // Create rotated gradient
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.width / 2, -size.height / 2);

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

/// Primary gradient button with accessibility support
///
/// Features:
/// - Gradient background (blue to indigo)
/// - Loading state with spinner
/// - Disabled state with gray gradient
/// - Focus indicator for keyboard navigation
/// - Semantic label for screen readers
/// - Hover lift effect
///
/// Usage:
/// ```dart
/// GradientButton(
///   text: 'Start Free Trial',
///   onPressed: () => scrollTo('pricing'),
///   icon: LucideIcons.arrowRight,
/// )
/// ```
class GradientButton extends BaseActionButton {
  const GradientButton({
    super.key,
    required super.text,
    super.onPressed,
    super.icon,
    super.isLoading,
    super.semanticLabel,
    super.fullWidth,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with HoverableButtonMixin {
  @override
  bool get isDisabled => widget.isLoading || widget.onPressed == null;

  @override
  Widget build(BuildContext context) {
    return buildHoverableButton(
      onTap: widget.onPressed,
      semanticLabel: widget.semanticLabel ?? widget.text,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: hoverLiftTransform(isHovered, isDisabled),
        decoration: BoxDecoration(
          gradient: isDisabled
              ? AppColors.disabledGradient
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: AppColors.shadowBlue,
                    blurRadius: isHovered ? 24 : 16,
                    offset: Offset(0, isHovered ? 6 : 4),
                  ),
                ],
          border: isFocused
              ? Border.all(color: AppColors.blue400, width: 2)
              : null,
        ),
        child: Container(
          width: widget.fullWidth ? double.infinity : null,
          padding: kButtonPadding,
          child: ButtonContent(
            text: widget.text,
            icon: widget.icon,
            isLoading: widget.isLoading,
            fullWidth: widget.fullWidth,
          ).build(),
        ),
      ),
    );
  }
}

/// Secondary outline button
///
/// Features:
/// - Transparent background with border
/// - Hover state with blue border
/// - Focus indicator
/// - Semantic accessibility
///
/// Usage:
/// ```dart
/// OutlineButton(
///   text: 'View Demo',
///   onPressed: () => openDemo(),
/// )
/// ```
class OutlineButton extends BaseActionButton {
  const OutlineButton({
    super.key,
    required super.text,
    super.onPressed,
    super.icon,
    super.isLoading,
    super.semanticLabel,
    super.fullWidth,
  });

  @override
  State<OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<OutlineButton>
    with HoverableButtonMixin {
  @override
  bool get isDisabled => widget.isLoading || widget.onPressed == null;

  Color get _textColor => isDisabled ? AppColors.gray500 : AppColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    return buildHoverableButton(
      onTap: widget.onPressed,
      semanticLabel: widget.semanticLabel ?? widget.text,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isHovered && !isDisabled
              ? AppColors.gray800
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(
            color: isFocused
                ? AppColors.blue400
                : isHovered && !isDisabled
                    ? AppColors.blue500
                    : AppColors.gray700,
            width: isFocused ? 2 : 1,
          ),
        ),
        child: Container(
          width: widget.fullWidth ? double.infinity : null,
          padding: kButtonPadding,
          child: ButtonContent(
            text: widget.text,
            icon: widget.icon,
            isLoading: widget.isLoading,
            fullWidth: widget.fullWidth,
            textColor: _textColor,
          ).build(),
        ),
      ),
    );
  }
}

/// Text button for inline actions
///
/// Usage:
/// ```dart
/// AppTextButton(
///   text: 'Learn more',
///   onPressed: () => navigateTo('/docs'),
/// )
/// ```
class AppTextButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool iconLeading;
  final String? semanticLabel;

  const AppTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.iconLeading = false,
    this.semanticLabel,
  });

  @override
  State<AppTextButton> createState() => _AppTextButtonState();
}

class _AppTextButtonState extends State<AppTextButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.semanticLabel ?? widget.text,
      child: MouseRegion(
        cursor: isDisabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null && widget.iconLeading) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color: isDisabled ? AppColors.gray500 : AppColors.textLink,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                widget.text,
                style: AppTypography.link.copyWith(
                  color: isDisabled ? AppColors.gray500 : AppColors.textLink,
                  decoration:
                      _isHovered ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
              if (widget.icon != null && !widget.iconLeading) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  widget.icon,
                  size: 16,
                  color: isDisabled ? AppColors.gray500 : AppColors.textLink,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon button with tooltip
///
/// Usage:
/// ```dart
/// AppIconButton(
///   icon: LucideIcons.menu,
///   onPressed: () => openMenu(),
///   tooltip: 'Open menu',
/// )
/// ```
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      icon: Icon(
        icon,
        size: size,
        color: color ?? AppColors.textSecondary,
      ),
      onPressed: onPressed,
      hoverColor: AppColors.gray700,
      focusColor: AppColors.gray700,
      splashRadius: size,
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
