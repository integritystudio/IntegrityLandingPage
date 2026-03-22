import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/analytics.dart';
import '../services/provisioning_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/containers.dart';

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
      defaultValue: 'https://sender-worker.example.workers.dev',
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
            additionalPadding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Service Status',
                  style: AppTypography.headingLG.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Subtitle
                Text(
                  'Monitor the health of the Sender Worker',
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.gray300,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Status card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.gray800,
                    border: Border.all(color: AppColors.gray700),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sender Worker',
                            style: AppTypography.bodyMD.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Status badge
                          if (_isHealthy != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: _isHealthy!
                                    ? AppColors.success.withAlpha(25)
                                    : AppColors.error.withAlpha(25),
                                border: Border.all(
                                  color: _isHealthy!
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSM,
                                ),
                              ),
                              child: Text(
                                _isHealthy! ? 'Healthy' : 'Unhealthy',
                                style: AppTypography.bodySM.copyWith(
                                  color: _isHealthy!
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ) else if (_isLoading)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.blue500,
                                  ),
                                ),
                              ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Version
                      Text(
                        'Version: 1.0.0',
                        style: AppTypography.bodySM.copyWith(
                          color: AppColors.gray300,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Last check time
                      if (_lastCheckTime != null)
                        Text(
                          'Last check: ${_lastCheckTime!.toLocal().toString().split('.')[0]}',
                          style: AppTypography.bodySM.copyWith(
                            color: AppColors.gray400,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),

                      // Refresh button
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
