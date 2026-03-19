import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/theme.dart';
import '../common/alert.dart';
import '../common/buttons.dart';
import '../common/cards.dart';
import '../common/copyable_code_field.dart';

/// Modal dialog for displaying the one-time API key after provisioning.
///
/// Shows the API key with a copy button and non-dismissible warning.
/// User must explicitly confirm before closing the modal.
class ApiKeyModal extends StatelessWidget {
  /// The API key to display.
  final String apiKey;

  const ApiKeyModal({
    super.key,
    required this.apiKey,
  });

  /// Show the API key modal dialog.
  ///
  /// The modal is not dismissible by tapping the barrier or pressing escape.
  /// User must tap the confirm button to close.
  static Future<void> show(
    BuildContext context, {
    required String apiKey,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => ApiKeyModal(apiKey: apiKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        key: const ValueKey('api-key-modal'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: GlassCard(
            tier: GlassCardTier.primary,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          LucideIcons.key,
                          color: AppColors.blue400,
                          size: AppSpacing.iconMD,
                        ),
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Your API Key',
                      style: AppTypography.headingSM,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Warning — non-dismissible
                Alert(
                  variant: AlertVariant.warning,
                  title: 'Save this key now',
                  message:
                      'This key will not be shown again. Copy it before closing.',
                  dismissible: false,
                ),
                const SizedBox(height: AppSpacing.md),
                // Key display
                CopyableCodeField(
                  key: const ValueKey('api-key-field'),
                  code: apiKey,
                  label: 'API Key',
                ),
                const SizedBox(height: AppSpacing.lg),
                // Confirm button — full width
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    key: const ValueKey('api-key-confirm-button'),
                    text: "I've copied my API key",
                    icon: LucideIcons.check,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
