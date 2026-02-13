import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';

/// Security page displaying security practices and commitments.
class SecurityPage extends StatelessWidget {
  final VoidCallback? onBack;

  const SecurityPage({
    super.key,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: AppColors.gray900,
            floating: true,
            pinned: true,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: onBack ?? () => context.go('/'),
            ),
            title: Text(
              SecurityContent.pageTitle,
              style: AppTypography.headingSM.copyWith(color: Colors.white),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: TextButton(
                  onPressed: onBack ?? () => context.go('/'),
                  child: Text(
                    'Back to Home',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.blue400,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Hero Section
          SliverToBoxAdapter(
            child: _HeroSection(isMobile: isMobile),
          ),

          // Content
          SliverToBoxAdapter(
            child: SectionContainer(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: const _SecurityContent(),
              ),
            ),
          ),

          // Footer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      SecurityContent.lastUpdated,
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${CompanyInfo.name} LLC',
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final bool isMobile;

  const _HeroSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.gray900,
            AppColors.gray800.withValues(alpha: 0.5),
            AppColors.gray900,
          ],
        ),
      ),
      child: SectionContainer(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? AppSpacing.xxl : AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badge
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.blue500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: AppColors.blue500.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.shieldCheck,
                    size: 16,
                    color: AppColors.blue400,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    SecurityContent.badge,
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.blue400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Headline
            Text(
              SecurityContent.pageTitle,
              style: isMobile
                  ? AppTypography.headingLG.copyWith(fontSize: 32)
                  : AppTypography.headingXL,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Subheadline
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                SecurityContent.subtitle,
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityContent extends StatelessWidget {
  const _SecurityContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overview Stats
        _SecurityCard(
          icon: LucideIcons.lock,
          title: SecurityContent.commitmentTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SecurityContent.commitmentDescription,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardCount = SecurityContent.stats.length;
                  final spacing = AppSpacing.md;
                  final cardWidth = (constraints.maxWidth - spacing * (cardCount - 1)) / cardCount;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: SecurityContent.stats
                        .map((stat) => SizedBox(
                              width: cardWidth.clamp(140, double.infinity),
                              child: _StatCard(
                                value: stat.value,
                                label: stat.label,
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),

        // Authentication Security
        _SecurityCard(
          icon: LucideIcons.user,
          title: SecurityContent.authTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SecurityContent.authDescription,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...SecurityContent.authFeatures
                  .map((f) => _ChecklistItem(title: f.title, desc: f.desc)),
            ],
          ),
        ),

        // Data Protection
        _SecurityCard(
          icon: LucideIcons.database,
          title: SecurityContent.dataProtectionTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SecurityContent.dataProtectionDescription,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SubSection(
                title: 'Encryption',
                items: SecurityContent.encryptionItems,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SubSection(
                title: 'Database Security',
                items: SecurityContent.databaseSecurityItems,
              ),
              const SizedBox(height: AppSpacing.lg),
              _WarningAlert(
                message: SecurityContent.secretsWarning,
              ),
            ],
          ),
        ),

        // Observability Pipeline Security
        _SecurityCard(
          icon: LucideIcons.activity,
          title: SecurityContent.observabilitySecurityTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SecurityContent.observabilitySecurityDescription,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...SecurityContent.observabilityFeatures
                  .map((f) => _ChecklistItem(title: f.title, desc: f.desc)),
            ],
          ),
        ),

        // Access Control
        _SecurityCard(
          icon: LucideIcons.key,
          title: SecurityContent.accessControlTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SecurityContent.accessControlDescription,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SubSection(
                title: 'Role-Based Permissions',
                items: SecurityContent.rolePermissions,
              ),
            ],
          ),
        ),

        // Enterprise Identity
        _SecurityCard(
          icon: LucideIcons.fingerprint,
          title: SecurityContent.enterpriseIdentityTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SecurityContent.enterpriseIdentityDescription,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...SecurityContent.enterpriseIdentityFeatures
                  .map((f) => _ChecklistItem(title: f.title, desc: f.desc)),
            ],
          ),
        ),

        // Compliance & Governance
        _SecurityCard(
          icon: LucideIcons.scale,
          title: SecurityContent.complianceTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SecurityContent.complianceDescription,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...SecurityContent.complianceFeatures
                  .map((f) => _ChecklistItem(title: f.title, desc: f.desc)),
            ],
          ),
        ),

        // API Security
        _SecurityCard(
          icon: LucideIcons.plug,
          title: SecurityContent.apiSecurityTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SecurityContent.apiSecurityDescription,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...SecurityContent.apiFeatures
                  .map((f) => _ChecklistItem(title: f.title, desc: f.desc)),
            ],
          ),
        ),

        // Best Practices
        _SecurityCard(
          icon: LucideIcons.bookOpen,
          title: SecurityContent.bestPracticesTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SecurityContent.bestPracticesDescription,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SubSection(
                title: 'Development Practices',
                items: SecurityContent.devPractices,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SubSection(
                title: 'Operational Security',
                items: SecurityContent.opsPractices,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SubSection(
                title: 'For Users',
                items: SecurityContent.userPractices,
              ),
            ],
          ),
        ),

        // Production Checklist
        _SecurityCard(
          icon: LucideIcons.clipboardCheck,
          title: SecurityContent.checklistTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SecurityContent.checklistDescription,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...SecurityContent.productionChecklist
                  .map((f) => _ChecklistItem(title: f.title, desc: f.desc)),
            ],
          ),
        ),

        // Reporting
        _SecurityCard(
          icon: LucideIcons.alertTriangle,
          title: SecurityContent.reportingTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SecurityContent.reportingDescription,
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              _DangerAlert(
                message: SecurityContent.vulnerabilityWarning,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ContactBox(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecurityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SecurityCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blue500,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.headingSM.copyWith(
                    color: AppColors.blue400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.gray700,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.gray600),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.headingMD.copyWith(
              color: AppColors.blue400,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySM.copyWith(
              color: AppColors.gray400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String title;
  final String desc;

  const _ChecklistItem({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.gray700),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check, color: Colors.white, size: 14),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMD.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  desc,
                  style: AppTypography.bodySM.copyWith(
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubSection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _SubSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.bodyMD.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                bottom: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: AppTypography.bodyMD.copyWith(
                      color: AppColors.blue400,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTypography.bodyMD.copyWith(
                        color: AppColors.gray300,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _WarningAlert extends StatelessWidget {
  final String message;

  const _WarningAlert({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertTriangle, color: AppColors.warning, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMD.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerAlert extends StatelessWidget {
  final String message;

  const _DangerAlert({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMD.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blue500.withValues(alpha: 0.1),
            AppColors.blue600.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.blue500),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security Contact',
            style: AppTypography.bodyLG.copyWith(
              color: AppColors.blue400,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Email: ${SecurityContent.securityEmail}',
            style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Please include:',
            style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...SecurityContent.reportingIncludes.map((item) => Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  bottom: AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: AppTypography.bodyMD.copyWith(
                        color: AppColors.blue400,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTypography.bodyMD.copyWith(
                          color: AppColors.gray300,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: AppSpacing.md),
          Text(
            SecurityContent.responseTime,
            style: AppTypography.bodySM.copyWith(
              color: AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }
}
