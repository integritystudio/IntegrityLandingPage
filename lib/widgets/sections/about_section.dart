import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/content.dart';
import '../../theme/theme.dart';
import '../common/cards.dart';
import '../common/containers.dart';

/// About section showcasing company mission, values, and team.
///
/// Brand voice: Professional, Technical, Approachable, Forward-thinking
///
/// Features:
/// - Mission and vision statements
/// - Company story with founding narrative
/// - Core values grid
/// - Team member profiles
/// - Location and founding year
///
/// Usage:
/// ```dart
/// AboutSection(
///   content: AboutContent.current, // or AppContent.about
/// )
/// ```
class AboutSection extends StatelessWidget {
  final AboutContent content;

  const AboutSection({
    super.key,
    this.content = const AboutContent(
      sectionId: 'about',
      title: 'About',
      subtitle: '',
      missionStatement: '',
      visionStatement: '',
      story: '',
      values: [],
      team: [],
      locationCity: '',
      locationRegion: '',
      foundedYear: '',
    ),
  });

  // Use content from widget or fallback to AppContent
  AboutContent get _content =>
      content.story.isEmpty ? AppContent.about : content;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return SectionContainer(
      id: _content.sectionId,
      backgroundColor: AppColors.gray800,
      child: Column(
        children: [
          // Section header
          SectionTitle(
            title: _content.title,
            subtitle: _content.subtitle,
          ),

          SizedBox(height: AppSpacing.sectionPadding(context) * 0.5),

          // Mission & Vision cards
          _buildMissionVisionRow(context, isMobile),

          SizedBox(height: AppSpacing.sectionPadding(context) * 0.5),

          // Our Story
          _buildStorySection(context),

          SizedBox(height: AppSpacing.sectionPadding(context) * 0.5),

          // Core Values
          _buildValuesSection(context),

          SizedBox(height: AppSpacing.sectionPadding(context) * 0.5),

          // Team (if members are defined)
          if (_content.team.isNotEmpty) ...[
            _buildTeamSection(context, isMobile),
            const SizedBox(height: AppSpacing.xl),
          ],

          // Location badge
          _buildLocationBadge(),
        ],
      ),
    );
  }

  Widget _buildMissionVisionRow(BuildContext context, bool isMobile) {
    // Mission card content
    final missionCard = GlassCard(
      tier: GlassCardTier.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconContainer.translucent(
                icon: Icons.flag_outlined,
                color: AppColors.blue500,
                iconColor: AppColors.blue400,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Our Mission',
                style: AppTypography.headingSM.copyWith(
                  color: AppColors.blue400,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _content.missionStatement,
            style: AppTypography.bodyLG,
          ),
        ],
      ),
    );

    // Vision card content
    final visionCard = GlassCard(
      tier: GlassCardTier.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconContainer.translucent(
                icon: Icons.visibility_outlined,
                color: AppColors.indigo500,
                iconColor: AppColors.indigo400,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Our Vision',
                style: AppTypography.headingSM.copyWith(
                  color: AppColors.indigo400,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _content.visionStatement,
            style: AppTypography.bodyLG,
          ),
        ],
      ),
    );

    // Mobile: Stack vertically without Expanded (unbounded height in scrollable)
    if (isMobile) {
      return Column(
        children: [
          missionCard,
          const SizedBox(height: AppSpacing.lg),
          visionCard,
        ],
      );
    }

    // Desktop: Side by side with Expanded (bounded width)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: missionCard),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: visionCard),
      ],
    );
  }

  Widget _buildStorySection(BuildContext context) {
    final paragraphs = _content.story.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Our Story',
          style: AppTypography.headingMDResponsive(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...paragraphs.map((paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                paragraph,
                style: AppTypography.bodyLG,
              ),
            )),
      ],
    );
  }

  Widget _buildValuesSection(BuildContext context) {
    return Column(
      children: [
        Text(
          'Our Values',
          style: AppTypography.headingMDResponsive(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 4,
          children: _content.values
              .map((value) => _ValueCard(value: value))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTeamSection(BuildContext context, bool isMobile) {
    return Column(
      children: [
        Text(
          'Meet the Team',
          style: AppTypography.headingMDResponsive(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 3,
          children: _content.team
              .map((member) => _TeamMemberCard(member: member))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildLocationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.gray900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(
          color: AppColors.gray700.withValues(alpha: 0.5),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.gray400,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${_content.locationCity}, ${_content.locationRegion}',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.gray400,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Founded ${_content.foundedYear}',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Value card showing a company principle.
class _ValueCard extends StatelessWidget {
  final CompanyValueContent value;

  const _ValueCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tier: GlassCardTier.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientIconContainer(
            icon: value.icon,
            borderRadius: AppSpacing.radiusMD,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value.title,
            style: AppTypography.headingSM,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value.description,
            style: AppTypography.bodySM,
          ),
        ],
      ),
    );
  }
}

/// Team member card with avatar and bio.
class _TeamMemberCard extends StatelessWidget {
  final TeamMemberContent member;

  const _TeamMemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    // Generate default alt text if not provided
    final altText = member.imageAlt ?? '${member.name}, ${member.role}';

    return GlassCard(
      tier: GlassCardTier.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with accessibility support
          Semantics(
            label: altText,
            image: true,
            child: CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.gray700,
              backgroundImage: member.avatarAsset != null
                  ? AssetImage(member.avatarAsset!)
                  : null,
              child: member.avatarAsset == null
                  ? Text(
                      member.name.split(' ').map((n) => n[0]).join(),
                      style: AppTypography.headingMDResponsive(context).copyWith(
                        color: AppColors.blue400,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            member.name,
            style: AppTypography.headingSM,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            member.role,
            style: AppTypography.bodyMD.copyWith(
              color: AppColors.blue400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            member.bio,
            style: AppTypography.bodySM,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Social links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (member.linkedInUrl != null)
                _SocialIconButton(
                  icon: Icons.link,
                  url: member.linkedInUrl!,
                  tooltip: 'LinkedIn',
                ),
              if (member.xUrl != null)
                _SocialIconButton(
                  icon: Icons.alternate_email,
                  url: member.xUrl!,
                  tooltip: 'X',
                ),
              if (member.githubUrl != null)
                _SocialIconButton(
                  icon: Icons.code,
                  url: member.githubUrl!,
                  tooltip: 'GitHub',
                ),
              if (member.websiteUrl != null)
                _SocialIconButton(
                  icon: Icons.language,
                  url: member.websiteUrl!,
                  tooltip: 'Website',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Social media icon button.
class _SocialIconButton extends StatelessWidget {
  final IconData icon;
  final String url;
  final String tooltip;

  const _SocialIconButton({
    required this.icon,
    required this.url,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: AppColors.gray400,
        hoverColor: AppColors.blue500.withValues(alpha: 0.1),
        onPressed: () => launchUrl(Uri.parse(url)),
      ),
    );
  }
}
