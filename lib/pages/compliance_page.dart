import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/docs/doc_components.dart';
import '../widgets/sections/page_hero_section.dart';

/// General compliance and governance overview page.
///
/// Covers SOC 2, GDPR, HIPAA, and EU AI Act compliance with links
/// to detailed documentation.
class CompliancePage extends StatelessWidget {
  final VoidCallback? onBack;

  const CompliancePage({
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
              'Compliance & Governance',
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
            child: PageHeroSection(
              isMobile: isMobile,
              accentColor: AppColors.purple400,
              badgeIcon: LucideIcons.shieldCheck,
              badgeText: 'Enterprise Compliance',
              headline: 'Compliance & Governance',
              subheadline:
                  'Meet regulatory requirements with confidence. Integrity Studio is designed for enterprise compliance across SOC 2, GDPR, and the EU AI Act.',
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: SectionContainer(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: const _ComplianceContent(),
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
                      'Built for enterprise compliance',
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '\u00A9 2026 Integrity Studio LLC',
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

class _ComplianceContent extends StatelessWidget {
  const _ComplianceContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SOC 2 Type II Section
        DocSection(
          icon: LucideIcons.shield,
          title: 'SOC 2 Type II',
          accentColor: AppColors.blue500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Our platform is designed to meet SOC 2 Type II requirements across all five Trust Service Principles.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Trust Principle', 'How We Address It'],
                rows: [
                  ['Security', 'Role-based access, encryption at rest/transit, audit logging'],
                  ['Availability', '99.9% uptime SLA, redundant infrastructure'],
                  ['Processing Integrity', 'Data validation, error handling, transaction logging'],
                  ['Confidentiality', 'Data isolation, access controls, secure deletion'],
                  ['Privacy', 'PII detection, consent management, data minimization'],
                ],
              ),
            ],
          ),
        ),

        // GDPR Section
        DocSection(
          icon: LucideIcons.globe,
          title: 'GDPR',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Full compliance with the General Data Protection Regulation for EU data subjects.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocBulletList(
                items: [
                  'Data Subject Rights - Access, rectification, erasure, portability',
                  'Lawful Basis - Documented processing purposes',
                  'Data Processing Agreements - Standard DPAs available',
                  'Cross-border Transfers - EU-US Data Privacy Framework compliant',
                ],
                bulletColor: AppColors.purple400,
              ),
            ],
          ),
        ),

        // HIPAA Section
        DocSection(
          icon: LucideIcons.heartPulse,
          title: 'HIPAA',
          accentColor: AppColors.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DocCallout.warning(
                title: 'Healthcare Data Protection',
                message: 'HIPAA-ready architecture available for healthcare deployments. Contact us for Business Associate Agreement (BAA).',
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocBulletList(
                items: [
                  'PHI encryption and access controls',
                  'Audit logging for all data access',
                  'BAA available for enterprise customers',
                  'Dedicated healthcare deployment options',
                ],
                bulletColor: AppColors.warning,
              ),
            ],
          ),
        ),

        // EU AI Act Section
        DocSection(
          icon: LucideIcons.scale,
          title: 'EU AI Act',
          accentColor: AppColors.purple500,
          child: Builder(
            builder: (context) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comprehensive observability tooling aligned with EU AI Act requirements for LLM and GenAI systems.',
                    style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const DocTable(
                    headers: ['Milestone', 'Date', 'Requirements'],
                    rows: [
                      ['Act in Force', 'Aug 2024', 'Regulation published and effective'],
                      ['GPAI Obligations', 'Aug 2025', 'Articles 53, 55 - Documentation & transparency'],
                      ['High-Risk Requirements', 'Aug 2026', 'Articles 12, 19 - Logging & record-keeping'],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/eu-ai-act'),
                      icon: const Icon(LucideIcons.arrowRight, size: 18),
                      label: const Text('View Detailed EU AI Act Requirements'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Enterprise Certifications Section
        DocSection(
          icon: LucideIcons.award,
          title: 'Enterprise Certifications',
          accentColor: AppColors.success,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current certification status and roadmap.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Certification', 'Status'],
                rows: [
                  ['SOC 2 Type II', 'Audit Ready'],
                  ['GDPR', 'Compliant'],
                  ['EU AI Act', 'Preparing (Aug 2025)'],
                  ['ISO 27001', 'Roadmap'],
                ],
              ),
            ],
          ),
        ),

        // Resources Section
        DocSection(
          icon: LucideIcons.fileText,
          title: 'Resources',
          accentColor: AppColors.gray500,
          child: Builder(
            builder: (context) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Access detailed compliance documentation and guides.',
                    style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ResourceLink(
                    icon: LucideIcons.scale,
                    title: 'EU AI Act Requirements',
                    description: 'Detailed observability and logging requirements',
                    onTap: () => context.go('/eu-ai-act'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ResourceLink(
                    icon: LucideIcons.lock,
                    title: 'Security Overview',
                    description: 'Authentication, encryption, and access controls',
                    onTap: () => context.go('/security'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ResourceLink(
                    icon: LucideIcons.fileText,
                    title: 'Privacy Policy',
                    description: 'How we handle and protect your data',
                    onTap: () => context.go('/privacy'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ResourceLink(
                    icon: LucideIcons.mail,
                    title: 'Contact Us',
                    description: 'Questions about compliance? Get in touch',
                    onTap: () => context.go('/contact'),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResourceLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ResourceLink({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.gray800,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(color: AppColors.gray700),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.gray700,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
              ),
              child: Icon(icon, size: 20, color: AppColors.gray400),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySM.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 20, color: AppColors.gray500),
          ],
        ),
      ),
    );
  }
}
