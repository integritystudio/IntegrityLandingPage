import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/theme.dart';

/// A reusable code display field with clipboard copy functionality.
///
/// Shows code in a monospace font with a copy button that provides
/// visual feedback on successful copy.
class CopyableCodeField extends StatefulWidget {
  /// The code text to display and copy.
  final String code;

  /// Optional label header (e.g., 'API Key').
  final String? label;

  /// Optional custom text style for code (defaults to AppTypography.codeBlock).
  final TextStyle? codeStyle;

  const CopyableCodeField({
    super.key,
    required this.code,
    this.label,
    this.codeStyle,
  });

  @override
  State<CopyableCodeField> createState() => _CopyableCodeFieldState();
}

class _CopyableCodeFieldState extends State<CopyableCodeField> {
  bool _copied = false;

  static const _copyResetDuration = AppTimings.copyFeedback;

  Future<void> _handleCopy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.code));
      if (mounted) setState(() => _copied = true);
      // Fire-and-forget: reset after feedback duration; mounted guard prevents
      // setState on disposed widget
      Future.delayed(_copyResetDuration, () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (_) {
      // Clipboard write failed (e.g., document lost focus on web)
      // Do not show success feedback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('copyable-code-field'),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with label and copy button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (widget.label != null)
                  Flexible(
                    child: Text(
                      widget.label!,
                      style: AppTypography.label
                          .copyWith(color: AppColors.gray400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  key: const ValueKey('copy-button'),
                  onPressed: _handleCopy,
                  icon: Icon(
                    _copied ? LucideIcons.check : LucideIcons.copy,
                    size: AppSpacing.iconSM,
                  ),
                  label: Text(_copied ? 'Copied!' : 'Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor: _copied
                        ? AppColors.success
                        : AppColors.gray400,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          const Divider(
            color: AppColors.borderDefault,
            height: 1,
          ),
          // Code content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectableText(
              widget.code,
              style: widget.codeStyle ?? AppTypography.codeBlock,
            ),
          ),
        ],
      ),
    );
  }
}
