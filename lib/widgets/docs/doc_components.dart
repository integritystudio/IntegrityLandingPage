import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/theme.dart';

/// Reusable documentation section with icon and title.
class DocSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color? accentColor;

  const DocSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.blue500;
    return Semantics(
      label: title,
      container: true,
      child: Container(
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
                    color: color,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.headingSM.copyWith(
                      color: color.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

class DocFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color? accentColor;

  const DocFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.blue500;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray700,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.gray600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  AppColors.purple500.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            ),
            child: Icon(icon, color: color.withValues(alpha: 0.9), size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.bodyMD.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
          ),
        ],
      ),
    );
  }
}

/// Code block with monospace font and syntax-friendly styling.
class DocCodeBlock extends StatelessWidget {
  final String code;
  final String? title;

  const DocCodeBlock({super.key, required this.code, this.title});

  @override
  Widget build(BuildContext context) {
    final codeWidget = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray900,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.gray700),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 13,
          color: AppColors.gray300,
          height: 1.5,
        ),
      ),
    );
    if (title == null) return codeWidget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title!,
          style: AppTypography.bodySM.copyWith(
            color: AppColors.gray400,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        codeWidget,
      ],
    );
  }
}

/// Simple table for documentation data display.
/// Horizontally scrollable on mobile to prevent overflow.
class DocTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;

  const DocTable({
    super.key,
    required this.headers,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        constraints: const BoxConstraints(minWidth: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
          border: Border.all(color: AppColors.gray700),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.symmetric(
              inside: BorderSide(color: AppColors.gray700),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: AppColors.gray800),
                children: headers
                    .map((h) => Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            h,
                            style: AppTypography.bodySM.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              ...rows.map(
                (row) => TableRow(
                  children: row
                      .map((cell) => Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              cell,
                              style: AppTypography.bodySM.copyWith(
                                color: AppColors.gray300,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bullet list with accent-colored bullets.
/// Set [checked] to true to show checkmark icons instead of bullet characters.
class DocBulletList extends StatelessWidget {
  final List<String> items;
  final Color? bulletColor;
  final bool checked;

  const DocBulletList({
    super.key,
    required this.items,
    this.bulletColor,
    this.checked = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = bulletColor ?? AppColors.blue400;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (checked)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Icon(
                          LucideIcons.checkSquare,
                          size: 18,
                          color: AppColors.success,
                        ),
                      )
                    else
                      Text(
                        '\u2022 ',
                        style: AppTypography.bodyMD.copyWith(color: color),
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
              ))
          .toList(),
    );
  }
}

/// Stat card for displaying a key metric with a label.
/// [accentColor] controls the value text color; defaults to [AppColors.blue400].
class DocStatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? accentColor;

  const DocStatCard({
    super.key,
    required this.value,
    required this.label,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.blue400;
    return Container(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 160),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.headingMD.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Numbered list with accent-colored numbers in circles.
class DocNumberedList extends StatelessWidget {
  final List<String> items;
  final Color? accentColor;

  const DocNumberedList({
    super.key,
    required this.items,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.blue500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final item = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: AppTypography.bodySM.copyWith(
                      color: color.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item,
                    style: AppTypography.bodyMD.copyWith(
                      color: AppColors.gray300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Callout variant types for documentation.
enum DocCalloutVariant { success, info, warning, danger }

/// Callout box for important information.
class DocCallout extends StatelessWidget {
  final String title;
  final String? message;
  final List<String>? items;
  final DocCalloutVariant variant;

  const DocCallout({
    super.key,
    required this.title,
    this.message,
    this.items,
    this.variant = DocCalloutVariant.info,
  }) : assert(message != null || items != null);

  const DocCallout.success({
    super.key,
    required this.title,
    this.message,
    this.items,
  }) : variant = DocCalloutVariant.success;

  const DocCallout.info({
    super.key,
    required this.title,
    this.message,
    this.items,
  }) : variant = DocCalloutVariant.info;

  const DocCallout.warning({
    super.key,
    required this.title,
    this.message,
    this.items,
  }) : variant = DocCalloutVariant.warning;

  const DocCallout.danger({
    super.key,
    required this.title,
    this.message,
    this.items,
  }) : variant = DocCalloutVariant.danger;

  Color get _color => switch (variant) {
        DocCalloutVariant.success => AppColors.success,
        DocCalloutVariant.info => AppColors.blue500,
        DocCalloutVariant.warning => AppColors.warning,
        DocCalloutVariant.danger => AppColors.error,
      };

  IconData get _icon => switch (variant) {
        DocCalloutVariant.success => LucideIcons.checkCircle,
        DocCalloutVariant.info => LucideIcons.lightbulb,
        DocCalloutVariant.warning => LucideIcons.alertTriangle,
        DocCalloutVariant.danger => LucideIcons.alertCircle,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border(
          left: BorderSide(color: _color, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, color: _color, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.bodyMD.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (message != null)
            Text(
              message!,
              style: AppTypography.bodyMD.copyWith(
                color: variant == DocCalloutVariant.warning ||
                        variant == DocCalloutVariant.danger
                    ? _color
                    : AppColors.gray300,
              ),
            ),
          if (items != null)
            ...items!.map((item) => Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg, bottom: 4),
                  child: Text(
                    '\u2022 $item',
                    style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
                  ),
                )),
        ],
      ),
    );
  }
}
