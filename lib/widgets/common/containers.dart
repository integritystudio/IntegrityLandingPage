import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/theme.dart';

/// Responsive container with max-width and horizontal padding
///
/// Automatically adjusts padding based on screen size:
/// - Mobile: 16px
/// - Tablet: 24px
/// - Desktop: 32px
///
/// Usage:
/// ```dart
/// ResponsiveContainer(
///   child: Column(children: [...]),
/// )
/// ```
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final bool useSafeArea;
  final EdgeInsets? additionalPadding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.useSafeArea = false,
    this.additionalPadding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppSpacing.containerMaxWidth,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.containerPadding(context),
          ).add(additionalPadding ?? EdgeInsets.zero),
          child: child,
        ),
      ),
    );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}

/// Section container with vertical padding and optional background
///
/// Usage:
/// ```dart
/// SectionContainer(
///   id: 'features',
///   backgroundColor: AppColors.gray800,
///   child: FeaturesContent(),
/// )
/// ```
class SectionContainer extends StatelessWidget {
  final String? id;
  final Widget child;
  final Color? backgroundColor;
  final Gradient? backgroundGradient;
  final EdgeInsets? padding;
  final bool useResponsiveContainer;

  const SectionContainer({
    super.key,
    this.id,
    required this.child,
    this.backgroundColor,
    this.backgroundGradient,
    this.padding,
    this.useResponsiveContainer = true,
  });

  @override
  Widget build(BuildContext context) {
    final sectionPadding = padding ??
        EdgeInsets.symmetric(
          vertical: AppSpacing.sectionPadding(context),
        );

    Widget content = Padding(
      padding: sectionPadding,
      child: useResponsiveContainer
          ? ResponsiveContainer(child: child)
          : child,
    );

    if (backgroundColor != null || backgroundGradient != null) {
      content = Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          gradient: backgroundGradient,
        ),
        child: content,
      );
    }

    if (id != null) {
      return Semantics(
        container: true,
        label: '$id section',
        child: content,
      );
    }

    return content;
  }
}

/// Section title with optional subtitle
///
/// Usage:
/// ```dart
/// SectionTitle(
///   title: 'Platform Features',
///   subtitle: 'Everything you need for AI observability',
///   alignment: CrossAxisAlignment.center,
/// )
/// ```
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final CrossAxisAlignment alignment;
  final TextAlign? textAlign;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.alignment = CrossAxisAlignment.center,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextAlign = textAlign ??
        (alignment == CrossAxisAlignment.center
            ? TextAlign.center
            : TextAlign.left);

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTypography.headingMDResponsive(context),
            textAlign: effectiveTextAlign,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            subtitle!,
            style: AppTypography.bodyLG,
            textAlign: effectiveTextAlign,
          ),
        ],
      ],
    );
  }
}

/// Responsive grid that adjusts columns based on screen size
///
/// Usage:
/// ```dart
/// ResponsiveGrid(
///   children: features.map((f) => FeatureCard(feature: f)).toList(),
/// )
/// ```
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.spacing = AppSpacing.lg,
    this.runSpacing = AppSpacing.lg,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveUtils.responsive(
      context,
      mobile: mobileColumns ?? 1,
      tablet: tabletColumns ?? 2,
      desktop: desktopColumns ?? 3,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

/// Gradient background container with optional decorative orbs
///
/// Usage:
/// ```dart
/// GradientBackground(
///   showOrbs: true,
///   child: HeroContent(),
/// )
/// ```
class GradientBackground extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final bool showOrbs;
  final double? orbOpacity;

  const GradientBackground({
    super.key,
    required this.child,
    this.gradient,
    this.showOrbs = false,
    this.orbOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.backgroundGradient,
      ),
      child: Stack(
        children: [
          if (showOrbs) ...[
            // Top-left orb
            Positioned(
              left: -80,
              top: -80,
              child: Container(
                width: 256,
                height: 256,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.blue500.withValues(alpha: orbOpacity ?? 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Bottom-right orb
            Positioned(
              right: -60,
              bottom: 100,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.indigo500.withValues(alpha: orbOpacity ?? 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
          child,
        ],
      ),
    );
  }
}

/// Divider with optional label
///
/// Usage:
/// ```dart
/// LabeledDivider(label: 'or')
/// ```
class LabeledDivider extends StatelessWidget {
  final String? label;
  final Color? color;

  const LabeledDivider({
    super.key,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Divider(color: color ?? AppColors.gray700);
    }

    return Row(
      children: [
        Expanded(child: Divider(color: color ?? AppColors.gray700)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label!,
            style: AppTypography.caption,
          ),
        ),
        Expanded(child: Divider(color: color ?? AppColors.gray700)),
      ],
    );
  }
}

/// Icon container with gradient background
///
/// Consolidates the common pattern of a sized container with gradient
/// background containing a centered icon.
///
/// Variants:
/// - Default: Primary gradient (blue to indigo)
/// - Translucent: Semi-transparent colored background
/// - Solid: Solid color background
///
/// Usage:
/// ```dart
/// GradientIconContainer(
///   icon: LucideIcons.activity,
/// )
///
/// GradientIconContainer.translucent(
///   icon: Icons.flag_outlined,
///   color: AppColors.blue500,
/// )
///
/// GradientIconContainer(
///   icon: LucideIcons.shield,
///   size: 56,
///   iconSize: 28,
/// )
/// ```
class GradientIconContainer extends StatelessWidget {
  final IconData icon;
  final double size;
  final double? iconSize;
  final Color iconColor;
  final Gradient? gradient;
  final Color? backgroundColor;
  final double borderRadius;

  const GradientIconContainer({
    super.key,
    required this.icon,
    this.size = 48,
    this.iconSize,
    this.iconColor = Colors.white,
    this.gradient,
    this.backgroundColor,
    this.borderRadius = AppSpacing.radiusLG,
  })  : _translucentColor = null,
        _translucentOpacity = null;

  /// Creates a translucent icon container with a semi-transparent colored background.
  ///
  /// Usage:
  /// ```dart
  /// GradientIconContainer.translucent(
  ///   icon: Icons.flag_outlined,
  ///   color: AppColors.blue500,
  ///   iconColor: AppColors.blue400,
  /// )
  /// ```
  const GradientIconContainer.translucent({
    super.key,
    required this.icon,
    required Color color,
    this.size = 48,
    this.iconSize,
    Color? iconColor,
    this.borderRadius = AppSpacing.radiusMD,
    double opacity = 0.15,
  })  : gradient = null,
        backgroundColor = null,
        iconColor = iconColor ?? color,
        _translucentColor = color,
        _translucentOpacity = opacity;

  // Private fields for translucent variant
  final Color? _translucentColor;
  final double? _translucentOpacity;

  /// Creates a solid colored icon container.
  ///
  /// Usage:
  /// ```dart
  /// GradientIconContainer.solid(
  ///   icon: Icons.check,
  ///   color: AppColors.gray700,
  /// )
  /// ```
  const GradientIconContainer.solid({
    super.key,
    required this.icon,
    required Color color,
    this.size = 48,
    this.iconSize,
    this.iconColor = Colors.white,
    this.borderRadius = AppSpacing.radiusMD,
  })  : gradient = null,
        backgroundColor = color,
        _translucentColor = null,
        _translucentOpacity = null;

  @override
  Widget build(BuildContext context) {
    final effectiveIconSize = iconSize ?? size * 0.5;

    BoxDecoration decoration;
    Color effectiveIconColor = iconColor;

    if (_translucentColor != null) {
      // Translucent variant
      decoration = AppDecorations.translucentIconBox(
        _translucentColor!,
        opacity: _translucentOpacity ?? 0.15,
        radius: borderRadius,
      );
      // For translucent, use a lighter shade of the color for the icon
      effectiveIconColor = iconColor;
    } else if (backgroundColor != null) {
      // Solid variant
      decoration = AppDecorations.iconBox(
        backgroundColor: backgroundColor,
        radius: borderRadius,
      );
    } else {
      // Default gradient variant
      decoration = AppDecorations.gradientIconBox(
        gradient: gradient,
        radius: borderRadius,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: decoration,
      child: Icon(
        icon,
        size: effectiveIconSize,
        color: effectiveIconColor,
      ),
    );
  }
}

/// Bullet point row for feature lists
///
/// Consolidates the common pattern of a bullet indicator followed by text.
/// Supports multiple bullet styles: dot, check icon, or custom icon.
///
/// Variants:
/// - Default: Blue dot bullet
/// - Check: Gradient circle with checkmark
/// - Icon: Custom icon bullet
///
/// Usage:
/// ```dart
/// BulletPoint(text: 'Feature one')
///
/// BulletPoint.check(text: 'Benefit item')
///
/// BulletPoint.icon(
///   icon: LucideIcons.zap,
///   text: 'Custom bullet',
/// )
///
/// // For lists:
/// Column(
///   children: features.map((f) => BulletPoint(text: f)).toList(),
/// )
/// ```
class BulletPoint extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final Color? dotColor;
  final double dotSize;
  final IconData? icon;
  final bool useGradientCheck;
  final EdgeInsetsGeometry padding;

  /// Creates a bullet point with a simple colored dot.
  const BulletPoint({
    super.key,
    required this.text,
    this.textStyle,
    this.dotColor,
    this.dotSize = 6,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.xs),
  })  : icon = null,
        useGradientCheck = false;

  /// Creates a bullet point with a gradient checkmark icon.
  ///
  /// Usage:
  /// ```dart
  /// BulletPoint.check(text: 'Completed feature')
  /// ```
  const BulletPoint.check({
    super.key,
    required this.text,
    this.textStyle,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.sm),
  })  : dotColor = null,
        dotSize = 6,
        icon = null,
        useGradientCheck = true;

  /// Creates a bullet point with a custom icon.
  ///
  /// Usage:
  /// ```dart
  /// BulletPoint.icon(
  ///   icon: LucideIcons.star,
  ///   text: 'Premium feature',
  /// )
  /// ```
  const BulletPoint.icon({
    super.key,
    required this.text,
    required IconData this.icon,
    this.textStyle,
    this.dotColor,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.xs),
  })  : dotSize = 6,
        useGradientCheck = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBullet(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: textStyle ?? AppTypography.bodySM,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet() {
    if (useGradientCheck) {
      // Gradient circle with checkmark
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          LucideIcons.check,
          size: 12,
          color: Colors.white,
        ),
      );
    }

    if (icon != null) {
      // Custom icon bullet
      return Container(
        margin: const EdgeInsets.only(top: 2),
        child: Icon(
          icon,
          size: 16,
          color: dotColor ?? AppColors.blue500,
        ),
      );
    }

    // Simple dot bullet
    return Container(
      width: dotSize,
      height: dotSize,
      margin: const EdgeInsets.only(top: 6),
      decoration: AppDecorations.bulletDot,
    );
  }
}

/// Convenience widget for rendering a list of bullet points
///
/// Usage:
/// ```dart
/// BulletList(
///   items: ['Feature one', 'Feature two', 'Feature three'],
/// )
///
/// BulletList.checks(
///   items: ['Benefit one', 'Benefit two'],
/// )
/// ```
class BulletList extends StatelessWidget {
  final List<String> items;
  final TextStyle? textStyle;
  final Color? dotColor;
  final bool useChecks;

  const BulletList({
    super.key,
    required this.items,
    this.textStyle,
    this.dotColor,
  }) : useChecks = false;

  const BulletList.checks({
    super.key,
    required this.items,
    this.textStyle,
  })  : dotColor = null,
        useChecks = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        if (useChecks) {
          return BulletPoint.check(text: item, textStyle: textStyle);
        }
        return BulletPoint(
          text: item,
          textStyle: textStyle,
          dotColor: dotColor,
        );
      }).toList(),
    );
  }
}
