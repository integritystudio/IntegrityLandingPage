import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/status_icon.dart';
import '../widgets/navigation/sub_page_shell.dart';

/// Status icon type for result pages.
enum StatusIconType { success, warning }

/// Configuration for a status result item (success or failure).
class StatusResultItem {
  final IconData icon;
  final String label;
  final String value;

  const StatusResultItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// Configuration for status result page actions.
class StatusResultAction {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;

  const StatusResultAction({
    required this.text,
    required this.onPressed,
    this.isPrimary = false,
  });
}

/// Generic status result page for success/failure states.
///
/// Used for contact form submissions, request status, and other outcome pages.
class StatusResultPage extends StatelessWidget {
  final String analyticsPageName;
  final StatusIconType statusType;
  final String heading;
  final String message;
  final String sectionTitle;
  final List<StatusResultItem> items;
  final List<StatusResultAction> actions;
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;

  const StatusResultPage({
    super.key,
    required this.analyticsPageName,
    required this.statusType,
    required this.heading,
    required this.message,
    required this.sectionTitle,
    required this.items,
    required this.actions,
    this.onBack,
    this.onShowCookieSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SubPageShell(
      onBack: onBack,
      onShowCookieSettings: onShowCookieSettings,
      analyticsPageName: analyticsPageName,
      slivers: [
        SliverToBoxAdapter(
          child: _ResultHeroSection(
            statusType: statusType,
            heading: heading,
            message: message,
            sectionTitle: sectionTitle,
            items: items,
            actions: actions,
          ),
        ),
      ],
    );
  }
}

class _ResultHeroSection extends StatelessWidget {
  final StatusIconType statusType;
  final String heading;
  final String message;
  final String sectionTitle;
  final List<StatusResultItem> items;
  final List<StatusResultAction> actions;

  const _ResultHeroSection({
    required this.statusType,
    required this.heading,
    required this.message,
    required this.sectionTitle,
    required this.items,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: AppSpacing.sectionPadding(context),
      ),
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusIcon(),
              const SizedBox(height: AppSpacing.xl),

              // Heading
              Text(
                heading,
                style: (isMobile
                        ? AppTypography.headingLG
                        : AppTypography.headingXL)
                    .copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // Message
              Text(
                message,
                style: AppTypography.bodyLG.copyWith(color: AppColors.gray300),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Details section
              Container(
                padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.gray800,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  border: Border.all(color: AppColors.gray700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sectionTitle,
                      style: AppTypography.headingSM.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...items.asMap().entries.expand((entry) => [
                      if (entry.key > 0) const SizedBox(height: AppSpacing.sm),
                      _buildResultItem(entry.value),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Actions
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: actions
                    .map((action) => action.isPrimary
                        ? GradientButton(
                            text: action.text,
                            onPressed: action.onPressed,
                          )
                        : OutlineButton(
                            text: action.text,
                            onPressed: action.onPressed,
                          ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    return switch (statusType) {
      StatusIconType.success => const StatusIcon.success(),
      StatusIconType.warning => const StatusIcon.warning(),
    };
  }

  Widget _buildResultItem(StatusResultItem item) {
    return Row(
      children: [
        Icon(
          item.icon,
          color: AppColors.blue400,
          size: 20,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              Text(
                item.value,
                style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
