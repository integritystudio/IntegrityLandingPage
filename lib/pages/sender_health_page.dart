import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/analytics.dart';
import '../services/provisioning_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/dashboard_card.dart';
import '../widgets/common/gradient_page_shell.dart';
import '../widgets/common/status_badge.dart';

/// Sender Worker health check page.
///
/// Displays the health status of the Sender Worker service.
class SenderHealthPage extends StatefulWidget {
  final VoidCallback? onBack;

  const SenderHealthPage({
    super.key,
    this.onBack,
  });

  @override
  State<SenderHealthPage> createState() => _SenderHealthPageState();
}

class _SenderHealthPageState extends State<SenderHealthPage> {
  bool? _isHealthy;
  bool _isLoading = false;
  DateTime? _lastCheckTime;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('sender_health');
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() {
      _isLoading = true;
    });

    // Get the sender worker URL from environment
    const senderWorkerUrl = String.fromEnvironment(
      'SENDER_WORKER_URL',
      defaultValue: 'https://sender-worker.alyshia-b38.workers.dev',
    );

    final isHealthy =
        await ProvisioningService.checkHealth(senderWorkerUrl);

    if (!mounted) return;

    setState(() {
      _isHealthy = isHealthy;
      _lastCheckTime = DateTime.now();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientPageShell(
      onBack: widget.onBack,
      maxWidth: 600,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Status',
            style: AppTypography.headingLG.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Monitor the health of the Sender Worker',
            style: AppTypography.bodyMD.copyWith(
              color: AppColors.gray300,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DashboardCard(
            title: 'Sender Worker',
            isLoading: _isLoading,
            trailing: _isHealthy != null
                ? StatusBadge(
                    label: _isHealthy! ? 'Healthy' : 'Unhealthy',
                    color: _isHealthy! ? AppColors.success : AppColors.error,
                  )
                : null,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text(
                'Version: 1.0.0',
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.gray300,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_lastCheckTime != null)
                Text(
                  'Last check: ${_lastCheckTime!.toLocal().toString().split('.')[0]}',
                  style: AppTypography.bodySM.copyWith(
                    color: AppColors.gray400,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlineButton(
                      onPressed: _isLoading ? null : _checkHealth,
                      text: 'Refresh',
                      icon: LucideIcons.rotateCw,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
