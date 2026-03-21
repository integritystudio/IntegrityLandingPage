import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/analytics.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/containers.dart';

// Quota thresholds shared by _UsageBar and _DailyBarChart.
const double _dangerThreshold = 0.90;
const double _warningThreshold = 0.75;

/// Aggregates usage buckets by date, summing totalQuantity across all metrics.
///
/// Returns a map of ISO date string → total quantity for use in [_DailyBarChart].
@visibleForTesting
Map<String, int> aggregateUsageByDate(List<UsageBucket> buckets) {
  final daily = <String, int>{};
  for (final b in buckets) {
    daily[b.bucketDate] = (daily[b.bucketDate] ?? 0) + b.totalQuantity;
  }
  return daily;
}

/// Arguments passed to UsageSummaryPage via GoRouter state.extra.
class UsageSummaryArgs {
  final String orgId;
  final String orgName;
  final String jwt;

  /// Monthly units quota from entitlements. 0 = unlimited.
  final int monthlyUnitsQuota;

  const UsageSummaryArgs({
    required this.orgId,
    required this.orgName,
    required this.jwt,
    required this.monthlyUnitsQuota,
  });
}

/// Per-metric aggregated totals for the display table.
class _MetricTotal {
  final int totalQuantity;
  final int requestCount;

  const _MetricTotal({required this.totalQuantity, required this.requestCount});
}

/// Page displaying current-month usage summary by metric.
class UsageSummaryPage extends StatefulWidget {
  final UsageSummaryArgs args;
  final VoidCallback? onBack;

  const UsageSummaryPage({
    super.key,
    required this.args,
    this.onBack,
  });

  @override
  State<UsageSummaryPage> createState() => _UsageSummaryPageState();
}

class _UsageSummaryPageState extends State<UsageSummaryPage>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isFetching = false;
  String? _errorMessage;
  UsageSummaryData? _summary;
  Timer? _pollTimer;

  static const Duration _pollInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.trackPageView('usage_summary');
    _fetchSummary();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchSummary();
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(_pollInterval, (_) => _fetchSummary());
  }

  Future<void> _fetchSummary() async {
    if (_isFetching) return;
    _isFetching = true;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await DashboardService.fetchUsageSummary(
        orgId: widget.args.orgId,
        jwt: widget.args.jwt,
      );

      if (!mounted) return;

      switch (response) {
        case UsageSummarySuccess():
          setState(() {
            _summary = response.data;
            _isLoading = false;
          });
        case UsageSummaryError():
          setState(() {
            _errorMessage = response.error;
            _isLoading = false;
          });
      }
    } finally {
      _isFetching = false;
    }
  }

  Map<String, _MetricTotal> _aggregateBuckets(List<UsageBucket> buckets) {
    final totals = <String, _MetricTotal>{};
    for (final bucket in buckets) {
      final existing = totals[bucket.metricKey];
      totals[bucket.metricKey] = _MetricTotal(
        totalQuantity: (existing?.totalQuantity ?? 0) + bucket.totalQuantity,
        requestCount: (existing?.requestCount ?? 0) + bucket.requestCount,
      );
    }
    return totals;
  }

  int _grandTotalQuantity(Map<String, _MetricTotal> totals) =>
      totals.values.fold(0, (sum, t) => sum + t.totalQuantity);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: GradientBackground(
        child: Center(
          child: ResponsiveContainer(
            maxWidth: 600,
            additionalPadding:
                EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usage Summary',
                  style: AppTypography.headingLG.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.args.orgName.isNotEmpty
                      ? widget.args.orgName
                      : 'Current month usage breakdown',
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.gray300,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_errorMessage != null)
                  _ErrorCard(
                    message: _errorMessage!,
                    onRetry: _fetchSummary,
                  )
                else
                  _UsageSummaryCard(
                    summary: _summary,
                    isLoading: _isLoading,
                    monthlyUnitsQuota: widget.args.monthlyUnitsQuota,
                    onRefresh: _fetchSummary,
                    aggregateBuckets: _aggregateBuckets,
                    grandTotalQuantity: _grandTotalQuantity,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UsageSummaryCard extends StatelessWidget {
  final UsageSummaryData? summary;
  final bool isLoading;
  final int monthlyUnitsQuota;
  final VoidCallback onRefresh;
  final Map<String, _MetricTotal> Function(List<UsageBucket>) aggregateBuckets;
  final int Function(Map<String, _MetricTotal>) grandTotalQuantity;

  const _UsageSummaryCard({
    required this.summary,
    required this.isLoading,
    required this.monthlyUnitsQuota,
    required this.onRefresh,
    required this.aggregateBuckets,
    required this.grandTotalQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final totals =
        summary != null ? aggregateBuckets(summary!.buckets) : <String, _MetricTotal>{};
    final total = grandTotalQuantity(totals);
    final quota = monthlyUnitsQuota;
    final hasQuota = quota > 0;
    final usageRatio = hasQuota ? (total / quota).clamp(0.0, 1.0) : 0.0;
    final periodLabel = summary?.periodStart.isNotEmpty == true
        ? 'Since ${summary!.periodStart}'
        : 'Current period';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        border: Border.all(color: AppColors.gray700),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Usage',
                style: AppTypography.bodyMD.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.blue500),
                  ),
                ),
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: AppSpacing.md),
            // Usage bar
            _UsageBar(
              usedUnits: total,
              quotaUnits: quota,
              ratio: usageRatio,
              periodLabel: periodLabel,
            ),
            if (summary!.buckets.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              // Daily bar chart
              _DailyBarChart(
                buckets: summary!.buckets,
                monthlyUnitsQuota: monthlyUnitsQuota,
              ),
            ],
            if (totals.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              // Per-metric breakdown
              _MetricTable(totals: totals),
            ],
          ] else if (!isLoading) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'No usage data for this period.',
              style: AppTypography.bodySM.copyWith(color: AppColors.gray300),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlineButton(
                  onPressed: isLoading ? null : onRefresh,
                  text: 'Refresh',
                  icon: LucideIcons.rotateCw,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final int usedUnits;
  final int quotaUnits;
  final double ratio;
  final String periodLabel;

  const _UsageBar({
    required this.usedUnits,
    required this.quotaUnits,
    required this.ratio,
    required this.periodLabel,
  });

  Color _barColor() {
    if (ratio >= _dangerThreshold) return AppColors.error;
    if (ratio >= _warningThreshold) return AppColors.warning;
    return AppColors.blue500;
  }

  String _quotaLabel() => quotaUnits > 0
      ? '$usedUnits / $quotaUnits units'
      : '$usedUnits units';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              periodLabel,
              style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
            ),
            Text(
              _quotaLabel(),
              style: AppTypography.bodySM.copyWith(
                color: AppColors.gray300,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (quotaUnits > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.gray700,
              valueColor: AlwaysStoppedAnimation(_barColor()),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bar chart showing daily usage totals over the current period.
///
/// Groups [UsageBucket] entries by date and renders each day as a vertical bar.
/// A dashed reference line marks the daily average quota when [monthlyUnitsQuota] > 0.
class _DailyBarChart extends StatelessWidget {
  static const double _chartAreaHeight = 120.0;
  static const double _xLabelAreaHeight = 20.0;

  final List<UsageBucket> buckets;
  final int monthlyUnitsQuota;

  const _DailyBarChart({
    required this.buckets,
    required this.monthlyUnitsQuota,
  });

  /// Extracts the day number from an ISO-8601 date string ("2026-03-15" → "15").
  ///
  /// Returns empty string for malformed input so no label is rendered.
  static String _dayLabel(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length < 3) return '';
    final day = int.tryParse(parts[2]);
    if (day == null || day == 0) return '';
    return day.toString();
  }

  @override
  Widget build(BuildContext context) {
    final daily = aggregateUsageByDate(buckets);
    if (daily.isEmpty) return const SizedBox.shrink();

    final sortedDates = daily.keys.toList()..sort();
    final values = sortedDates.map((d) => daily[d]!).toList();
    final labels = sortedDates.map(_dayLabel).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily usage',
          style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: _chartAreaHeight + _xLabelAreaHeight,
          child: CustomPaint(
            painter: _DailyBarChartPainter(
              values: values,
              labels: labels,
              monthlyUnitsQuota: monthlyUnitsQuota,
            ),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _DailyBarChartPainter extends CustomPainter {
  static const double _xLabelAreaHeight = 20.0;
  static const double _barGapFraction = 0.3;
  static const int _gridLineCount = 4;
  static const double _barCornerRadius = 2.0;
  static const double _xLabelPaddingTop = 4.0;
  static const double _dashLength = 4.0;
  static const double _dashGap = 4.0;
  static const int _labelIntervalDays = 5;
  static const int _defaultDaysInMonth = 30;
  static const double _gridStrokeWidth = 0.5;
  static const double _quotaLineStrokeWidth = 1.0;

  final List<int> values;
  final List<String> labels;
  final int monthlyUnitsQuota;

  const _DailyBarChartPainter({
    required this.values,
    required this.labels,
    required this.monthlyUnitsQuota,
  });

  Color _barColor(int value) {
    if (monthlyUnitsQuota <= 0) return AppColors.blue500;
    final dailyQuota = monthlyUnitsQuota / _defaultDaysInMonth;
    final ratio = dailyQuota > 0 ? value / dailyQuota : 0.0;
    if (ratio >= _dangerThreshold) return AppColors.error;
    if (ratio >= _warningThreshold) return AppColors.warning;
    return AppColors.blue500;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return;

    final chartHeight = size.height - _xLabelAreaHeight;
    final barCount = values.length;
    final slotWidth = size.width / barCount;
    final barWidth = slotWidth * (1 - _barGapFraction);

    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = AppColors.gray700
      ..strokeWidth = _gridStrokeWidth;
    for (var i = 1; i <= _gridLineCount; i++) {
      final y = chartHeight * (1 - i / _gridLineCount);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Dashed daily quota reference line
    if (monthlyUnitsQuota > 0) {
      final dailyQuota = monthlyUnitsQuota / _defaultDaysInMonth;
      final qRatio = (dailyQuota / maxValue).clamp(0.0, 1.0);
      final qY = chartHeight * (1 - qRatio);
      final quotaPaint = Paint()
        ..color = AppColors.gray400
        ..strokeWidth = _quotaLineStrokeWidth;
      var x = 0.0;
      while (x < size.width) {
        final end = (x + _dashLength).clamp(0.0, size.width);
        canvas.drawLine(Offset(x, qY), Offset(end, qY), quotaPaint);
        x += _dashLength + _dashGap;
      }
    }

    // Bars and X-axis labels
    final labelStyle = AppTypography.caption.copyWith(
      color: AppColors.gray400,
      fontSize: 10,
    );
    for (var i = 0; i < barCount; i++) {
      final value = values[i];
      final ratio = value / maxValue;
      final x = i * slotWidth + (slotWidth - barWidth) / 2;
      final barHeight = chartHeight * ratio;
      final rect = Rect.fromLTWH(x, chartHeight - barHeight, barWidth, barHeight);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(_barCornerRadius)),
        Paint()..color = _barColor(value),
      );

      // X label: day 1 and every _labelIntervalDays thereafter
      final day = int.tryParse(labels[i]) ?? 0;
      if (day == 1 || day % _labelIntervalDays == 0) {
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(i * slotWidth + slotWidth / 2 - tp.width / 2, chartHeight + _xLabelPaddingTop),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DailyBarChartPainter old) =>
      monthlyUnitsQuota != old.monthlyUnitsQuota ||
      values.length != old.values.length ||
      !listEquals(values, old.values);
}

class _MetricTable extends StatelessWidget {
  final Map<String, _MetricTotal> totals;

  const _MetricTable({required this.totals});

  String _formatMetricKey(String key) {
    // Convert snake_case to Title Case
    return key
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.totalQuantity.compareTo(a.value.totalQuantity));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Breakdown by metric',
          style: AppTypography.bodySM.copyWith(
            color: AppColors.gray400,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Header row
        _TableRow(
          metric: 'Metric',
          units: 'Units',
          requests: 'Requests',
          isHeader: true,
        ),
        const SizedBox(height: AppSpacing.xs),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: _TableRow(
              metric: _formatMetricKey(entry.key),
              units: entry.value.totalQuantity.toString(),
              requests: entry.value.requestCount.toString(),
              isHeader: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  final String metric;
  final String units;
  final String requests;
  final bool isHeader;

  const _TableRow({
    required this.metric,
    required this.units,
    required this.requests,
    required this.isHeader,
  });

  @override
  Widget build(BuildContext context) {
    final style = isHeader
        ? AppTypography.bodySM.copyWith(
            color: AppColors.gray400,
            fontWeight: FontWeight.w500,
          )
        : AppTypography.bodySM.copyWith(color: AppColors.gray300);

    return Row(
      children: [
        Expanded(flex: 3, child: Text(metric, style: style)),
        Expanded(
          child: Text(units, style: style, textAlign: TextAlign.right),
        ),
        Expanded(
          child: Text(requests, style: style, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        border: Border.all(color: AppColors.gray700),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertCircle, size: 16, color: AppColors.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodySM.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlineButton(
                  onPressed: onRetry,
                  text: 'Try again',
                  icon: LucideIcons.rotateCw,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
