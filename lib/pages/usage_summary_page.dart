import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../widgets/common/alert.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/dashboard_card.dart';
import '../widgets/common/dashboard_scaffold.dart';
import '../widgets/common/error_card.dart';

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

/// When the monthly quota resets: the gateway's quota counter restarts at the
/// start of each UTC calendar month, so the label names UTC explicitly.
@visibleForTesting
String monthlyResetLabel(DateTime now) {
  final utc = now.toUtc();
  final reset = DateTime.utc(utc.year, utc.month + 1);
  return 'Resets ${CalendarText.monthNames[reset.month - 1]} ${reset.day}, 00:00 UTC';
}

/// Arguments passed to UsageSummaryPage via GoRouter state.extra.
class UsageSummaryArgs {
  final String orgId;
  final String orgName;
  final String jwt;

  const UsageSummaryArgs({
    required this.orgId,
    required this.orgName,
    required this.jwt,
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

  /// The org's quota as the gateway enforces it. The usage bar reads its
  /// `monthlyUsed` and `monthlyLimit`, so both come from one meter; the chart and
  /// per-metric table keep the bucket totals. Null until a fetch succeeds.
  QuotaStatusData? _quota;

  static const Duration _pollInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.trackPageView('usage_summary');
    _refresh();
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
    switch (state) {
      case AppLifecycleState.resumed:
        _refresh();
        _startPolling();
      // Nobody sees a hidden tab or a backgrounded app, and every poll counts
      // toward the org's per-minute limit, so stop until it is visible again.
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopPolling();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _refresh() {
    _fetchSummary();
    _fetchQuota();
  }

  Future<void> _fetchQuota() async {
    final response = await DashboardService.fetchQuotaStatus(
      orgId: widget.args.orgId,
      jwt: widget.args.jwt,
    );
    if (!mounted) return;
    // A quota Durable Object with no state answers without a plan, which would
    // parse as "no limit"; treat it like an error rather than as unlimited.
    if (response case QuotaStatusSuccess(:final data) when data.planKey != null) {
      setState(() {
        _quota = data;
      });
    }
    // Otherwise keep the current value; null shows the bucket total, no limit.
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchSummary() async {
    if (_isFetching) return;
    _isFetching = true;

    // Show spinner only on initial load; background polls refresh silently so
    // existing data remains visible while the refresh is in-flight.
    final isInitialLoad = _summary == null;
    if (isInitialLoad) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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
            _errorMessage = null;
          });
        case UsageSummaryError():
          setState(() {
            _isLoading = false;
            // On background poll failure, preserve existing data rather than
            // replacing the visible summary with an error card.
            if (isInitialLoad) _errorMessage = response.error;
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
    return DashboardScaffold(
      title: 'Usage Summary',
      subtitle: widget.args.orgName.isNotEmpty
          ? widget.args.orgName
          : 'Current month usage breakdown',
      onBack: widget.onBack,
      children: [
        if (_errorMessage != null)
          ErrorCard(
            message: _errorMessage!,
            onRetry: _fetchSummary,
          )
        else
          _UsageSummaryCard(
            summary: _summary,
            isLoading: _isLoading,
            quota: _quota,
            resetLabel: monthlyResetLabel(DateTime.now()),
            onRefresh: _refresh,
            aggregateBuckets: _aggregateBuckets,
            grandTotalQuantity: _grandTotalQuantity,
          ),
      ],
    );
  }
}

class _UsageSummaryCard extends StatelessWidget {
  final UsageSummaryData? summary;
  final bool isLoading;
  final QuotaStatusData? quota;
  final String resetLabel;
  final VoidCallback onRefresh;
  final Map<String, _MetricTotal> Function(List<UsageBucket>) aggregateBuckets;
  final int Function(Map<String, _MetricTotal>) grandTotalQuantity;

  const _UsageSummaryCard({
    required this.summary,
    required this.isLoading,
    required this.quota,
    required this.resetLabel,
    required this.onRefresh,
    required this.aggregateBuckets,
    required this.grandTotalQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final totals =
        summary != null ? aggregateBuckets(summary!.buckets) : <String, _MetricTotal>{};
    final total = grandTotalQuantity(totals);
    final periodLabel = summary?.periodStart.isNotEmpty == true
        ? 'Since ${summary!.periodStart}'
        : 'Current period';

    return DashboardCard(
      title: 'Monthly Usage',
      isLoading: isLoading,
      children: [
        if (summary != null) ...[
          const SizedBox(height: AppSpacing.md),
          // Usage bar
          _UsageBar(
            quota: quota,
            bucketTotal: total,
            periodLabel: periodLabel,
            resetLabel: resetLabel,
          ),
          if (summary!.buckets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            // Daily bar chart
            _DailyBarChart(
              buckets: summary!.buckets,
              monthlyUnitsQuota: quota?.monthlyLimit ?? 0,
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
    );
  }
}

/// Where the org stands against its monthly limit.
enum _QuotaLevel { normal, warning, danger, reached }

/// Usage against the monthly limit, read from the quota the gateway enforces.
///
/// With no [quota] (the fetch failed) it shows the bucket total alone. Colour
/// never carries the level by itself: the status line says it in words, and at
/// the warning threshold and above an [Alert] states what it means.
class _UsageBar extends StatelessWidget {
  static const double _statusIconSize = 14;

  final QuotaStatusData? quota;
  final int bucketTotal;
  final String periodLabel;
  final String resetLabel;

  const _UsageBar({
    required this.quota,
    required this.bucketTotal,
    required this.periodLabel,
    required this.resetLabel,
  });

  int get _used => quota?.monthlyUsed ?? bucketTotal;

  /// The monthly limit, or null when unlimited or unknown.
  int? get _limit {
    final limit = quota?.monthlyLimit;
    return limit != null && limit > 0 ? limit : null;
  }

  bool get _isUnlimited => quota != null && quota!.monthlyLimit == null;

  double get _ratio => _limit == null ? 0 : (_used / _limit!).clamp(0.0, 1.0);

  /// Rounded down, so "100% used" never shows before the limit is reached.
  int get _percent => _limit == null ? 0 : (_used * 100) ~/ _limit!;

  _QuotaLevel get _level {
    if (_limit == null) return _QuotaLevel.normal;
    if (_used >= _limit!) return _QuotaLevel.reached;
    if (_ratio >= QuotaThresholds.danger) return _QuotaLevel.danger;
    if (_ratio >= QuotaThresholds.warning) return _QuotaLevel.warning;
    return _QuotaLevel.normal;
  }

  Color get _levelColor => switch (_level) {
        _QuotaLevel.reached || _QuotaLevel.danger => AppColors.error,
        _QuotaLevel.warning => AppColors.warning,
        _QuotaLevel.normal => AppColors.blue500,
      };

  String _usageLabel() => _limit != null
      ? '$_used / $_limit units'
      : '$_used units';

  String? _statusLabel() {
    if (_isUnlimited) return 'Unlimited plan';
    if (_limit == null) return null;
    if (_level == _QuotaLevel.reached) return 'Monthly limit reached';
    return '$_percent% used';
  }

  Widget? _alert() => switch (_level) {
        _QuotaLevel.reached => Alert(
            variant: AlertVariant.error,
            title: 'Monthly limit reached',
            message: 'New requests are refused until the quota resets. '
                '$resetLabel.',
          ),
        _QuotaLevel.danger || _QuotaLevel.warning => Alert(
            variant: AlertVariant.warning,
            title: 'Approaching your monthly limit',
            message: "You have used $_percent% of this month's $_limit units. "
                '$resetLabel.',
          ),
        _QuotaLevel.normal => null,
      };

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel();
    final alert = _alert();
    final isRaised = _level != _QuotaLevel.normal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // The period label gives way first, so the usage figure is never cut.
            Flexible(
              child: Text(
                periodLabel,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _usageLabel(),
              style: AppTypography.bodySM.copyWith(
                color: AppColors.gray300,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (_limit != null) ...[
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: _ratio,
              minHeight: 6,
              backgroundColor: AppColors.gray700,
              valueColor: AlwaysStoppedAnimation(_levelColor),
              // The progress-bar role takes a number from 0 to 100 as its value,
              // so the units go in the label.
              semanticsLabel: 'Monthly usage, $_used of $_limit units',
              semanticsValue: '$_percent',
            ),
          ),
        ],
        if (status != null) ...[
          const SizedBox(height: AppSpacing.xs),
          // Wraps rather than truncates, so neither line is lost at large text sizes.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRaised) ...[
                    Icon(LucideIcons.alertTriangle, size: _statusIconSize, color: _levelColor),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    status,
                    style: AppTypography.bodySM.copyWith(
                      color: isRaised ? _levelColor : AppColors.gray300,
                      fontWeight: isRaised ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
              Text(
                resetLabel,
                style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
              ),
            ],
          ),
        ],
        if (alert != null) ...[
          const SizedBox(height: AppSpacing.md),
          alert,
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
    if (ratio >= QuotaThresholds.danger) return AppColors.error;
    if (ratio >= QuotaThresholds.warning) return AppColors.warning;
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
