import 'package:flutter/material.dart';
import '../../theme/spacing.dart';

class VerticalIndicatorList extends StatelessWidget {
  const VerticalIndicatorList({
    super.key,
    required this.itemCount,
    required this.indicatorBuilder,
    required this.contentBuilder,
    this.spacing = AppSpacing.md,
  });

  final int itemCount;
  final Widget Function(int index) indicatorBuilder;
  final Widget Function(int index, bool isLast) contentBuilder;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(itemCount, (index) {
        final isLast = index == itemCount - 1;
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            indicatorBuilder(index),
            SizedBox(width: AppSpacing.md),
            Expanded(child: contentBuilder(index, isLast)),
          ],
        );
        if (isLast) return row;
        return Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: row,
        );
      }),
    );
  }
}
