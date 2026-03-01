import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/theme.dart';

/// Alert variant types.
enum AlertVariant { success, error, warning, info }

/// Reusable alert/message component for displaying success, error, warning,
/// and info messages.
///
/// Provides consistent styling and accessibility features across the application.
///
/// Usage:
/// ```dart
/// Alert(
///   variant: AlertVariant.success,
///   message: 'Your form was submitted successfully!',
/// )
///
/// Alert(
///   variant: AlertVariant.error,
///   message: 'There was an error processing your request.',
///   onDismiss: () => setState(() => showAlert = false),
/// )
/// ```
class Alert extends StatelessWidget {
  /// The type/variant of alert to display.
  final AlertVariant variant;

  /// The message content to display.
  final String message;

  /// Optional title for the alert.
  final String? title;

  /// Optional callback when the alert is dismissed.
  final VoidCallback? onDismiss;

  /// Whether the alert is dismissible.
  final bool dismissible;

  /// Optional icon override.
  final IconData? icon;

  const Alert({
    super.key,
    required this.variant,
    required this.message,
    this.title,
    this.onDismiss,
    this.dismissible = false,
    this.icon,
  });

  /// Factory constructor for success alert.
  factory Alert.success({
    required String message,
    String? title,
    VoidCallback? onDismiss,
    bool dismissible = false,
  }) =>
      Alert(
        variant: AlertVariant.success,
        message: message,
        title: title,
        onDismiss: onDismiss,
        dismissible: dismissible,
      );

  /// Factory constructor for error alert.
  factory Alert.error({
    required String message,
    String? title,
    VoidCallback? onDismiss,
    bool dismissible = false,
  }) =>
      Alert(
        variant: AlertVariant.error,
        message: message,
        title: title,
        onDismiss: onDismiss,
        dismissible: dismissible,
      );

  /// Factory constructor for warning alert.
  factory Alert.warning({
    required String message,
    String? title,
    VoidCallback? onDismiss,
    bool dismissible = false,
  }) =>
      Alert(
        variant: AlertVariant.warning,
        message: message,
        title: title,
        onDismiss: onDismiss,
        dismissible: dismissible,
      );

  /// Factory constructor for info alert.
  factory Alert.info({
    required String message,
    String? title,
    VoidCallback? onDismiss,
    bool dismissible = false,
  }) =>
      Alert(
        variant: AlertVariant.info,
        message: message,
        title: title,
        onDismiss: onDismiss,
        dismissible: dismissible,
      );

  Color get _backgroundColor => switch (variant) {
        AlertVariant.success => AppColors.success.withValues(alpha: 0.1),
        AlertVariant.error => AppColors.error.withValues(alpha: 0.1),
        AlertVariant.warning => AppColors.warning.withValues(alpha: 0.1),
        AlertVariant.info => AppColors.info.withValues(alpha: 0.1),
      };

  Color get _borderColor => switch (variant) {
        AlertVariant.success => AppColors.success.withValues(alpha: 0.3),
        AlertVariant.error => AppColors.error.withValues(alpha: 0.3),
        AlertVariant.warning => AppColors.warning.withValues(alpha: 0.3),
        AlertVariant.info => AppColors.info.withValues(alpha: 0.3),
      };

  Color get _iconColor => switch (variant) {
        AlertVariant.success => AppColors.success,
        AlertVariant.error => AppColors.error,
        AlertVariant.warning => AppColors.warning,
        AlertVariant.info => AppColors.info,
      };

  Color get _textColor => switch (variant) {
        AlertVariant.success => AppColors.successLight,
        AlertVariant.error => AppColors.errorLight,
        AlertVariant.warning => AppColors.warningLight,
        AlertVariant.info => AppColors.blue400,
      };

  IconData get _defaultIcon => switch (variant) {
        AlertVariant.success => LucideIcons.checkCircle,
        AlertVariant.error => LucideIcons.alertCircle,
        AlertVariant.warning => LucideIcons.alertTriangle,
        AlertVariant.info => LucideIcons.info,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          crossAxisAlignment:
              title != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Icon(
              icon ?? _defaultIcon,
              color: _iconColor,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: AppTypography.bodyMD.copyWith(
                        color: _textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(
                    message,
                    style: AppTypography.bodySM.copyWith(
                      color: _textColor,
                    ),
                  ),
                ],
              ),
            ),
            if (dismissible && onDismiss != null)
              IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                color: _iconColor,
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Animated alert that can slide in/out.
class AnimatedAlert extends StatefulWidget {
  final AlertVariant variant;
  final String message;
  final String? title;
  final VoidCallback? onDismiss;
  final bool dismissible;
  final Duration? autoDismissDuration;

  const AnimatedAlert({
    super.key,
    required this.variant,
    required this.message,
    this.title,
    this.onDismiss,
    this.dismissible = false,
    this.autoDismissDuration,
  });

  @override
  State<AnimatedAlert> createState() => _AnimatedAlertState();
}

class _AnimatedAlertState extends State<AnimatedAlert>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    if (widget.autoDismissDuration != null) {
      _autoDismissTimer = Timer(widget.autoDismissDuration!, _dismiss);
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Alert(
          variant: widget.variant,
          message: widget.message,
          title: widget.title,
          onDismiss: _dismiss,
          dismissible: widget.dismissible,
        ),
      ),
    );
  }
}
