import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../services/analytics.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/status_icon.dart';
import '../widgets/navigation/shared_app_bar.dart';
import '../widgets/sections/footer_section.dart';

/// Failure page shown when a contact form submission fails.
class RequestFailurePage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;

  const RequestFailurePage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
  });

  @override
  State<RequestFailurePage> createState() => _RequestFailurePageState();
}

class _RequestFailurePageState extends State<RequestFailurePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('request_failure');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: SelectionArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SharedAppBar.subPage(onBack: widget.onBack),
            const SliverToBoxAdapter(child: _FailureHeroSection()),
            SliverToBoxAdapter(
              child: FooterSection(
                onCookieSettings: widget.onShowCookieSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureHeroSection extends StatelessWidget {
  const _FailureHeroSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: isMobile ? 48 : 80,
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
              const StatusIcon.warning(),
              const SizedBox(height: AppSpacing.xl),

              // Heading
              Text(
                'Something Went Wrong',
                style: (isMobile
                        ? AppTypography.headingLG
                        : AppTypography.headingXL)
                    .copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // Message
              Text(
                'We couldn\'t send your message. This might be a temporary issue. Please try again or contact us directly.',
                style: AppTypography.bodyLG.copyWith(color: AppColors.gray300),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Alternative contact options
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
                      'Alternative ways to reach us',
                      style: AppTypography.headingSM.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildContactOption(
                      icon: LucideIcons.mail,
                      label: 'Email us directly',
                      value: CompanyInfo.email,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildContactOption(
                      icon: LucideIcons.refreshCw,
                      label: 'Try submitting again',
                      value: 'The form may work now',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Buttons
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  OutlineButton(
                    text: 'Back to Home',
                    onPressed: () => context.go('/'),
                  ),
                  GradientButton(
                    text: 'Try Again',
                    onPressed: () => context.go('/contact'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.blue400,
          size: 20,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              Text(
                value,
                style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
