import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/theme.dart';
import '../../services/consent_manager.dart';
import '../common/buttons.dart';

/// GDPR-compliant cookie consent banner
///
/// This banner MUST be shown before any analytics tracking begins.
/// It provides:
/// - Clear explanation of cookie usage
/// - Granular consent options
/// - Easy access to privacy policy
/// - Ability to reject non-essential cookies
///
/// Usage:
/// ```dart
/// Stack(
///   children: [
///     LandingPage(),
///     if (_showCookieBanner)
///       CookieBanner(onConsentGiven: () => setState(() => _showCookieBanner = false)),
///   ],
/// )
/// ```
class CookieBanner extends StatefulWidget {
  final VoidCallback onConsentGiven;

  const CookieBanner({
    super.key,
    required this.onConsentGiven,
  });

  @override
  State<CookieBanner> createState() => _CookieBannerState();
}

class _CookieBannerState extends State<CookieBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _showPreferences = false;
  bool _analyticsEnabled = true;
  bool _marketingEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Animate in
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleConsent(ConsentLevel level) async {
    await ConsentManager.saveConsent(level.toPreferences());
    await _animateOut();
    widget.onConsentGiven();
  }

  Future<void> _handleCustomConsent() async {
    final prefs = ConsentPreferences(
      analytics: _analyticsEnabled,
      marketing: _marketingEnabled,
    );
    await ConsentManager.saveConsent(prefs);
    await _animateOut();
    widget.onConsentGiven();
  }

  Future<void> _animateOut() async {
    await _controller.reverse();
  }

  void _openPrivacyPolicy() {
    final uri = Uri.parse('https://integritystudio.ai/privacy');
    const mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
    launchUrl(uri, mode: mode);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    // Use Column with Spacer to push banner to bottom while only capturing
    // hits on its own content, allowing scroll gestures to pass through
    // to the page below
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Spacer that ignores pointer events, allowing scrolling through
        const Expanded(child: IgnorePointer(child: SizedBox.expand())),
        SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              elevation: 16,
              color: AppColors.gray800,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.all(
                    isMobile ? AppSpacing.md : AppSpacing.lg,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppColors.gray700,
                        width: 1,
                      ),
                    ),
                  ),
                  child: _showPreferences
                      ? _buildPreferencesView(isMobile)
                      : _buildMainView(isMobile),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainView(bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(
              Icons.cookie_outlined,
              color: AppColors.blue400,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Cookie Preferences',
                style: AppTypography.headingSM.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Description
        Text(
          'We use cookies to improve your experience and analyze site traffic. '
          'You can manage your preferences or decline non-essential cookies.',
          style: AppTypography.bodyMD,
        ),

        const SizedBox(height: AppSpacing.lg),

        // Buttons
        if (isMobile)
          _buildMobileButtons()
        else
          _buildDesktopButtons(),

        const SizedBox(height: AppSpacing.md),

        // Privacy Policy Link
        Center(
          child: TextButton(
            onPressed: _openPrivacyPolicy,
            child: Text(
              'Read our Privacy Policy',
              style: AppTypography.bodySM.copyWith(
                color: AppColors.textLink,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlineButton(
          text: 'Manage Preferences',
          onPressed: () => setState(() => _showPreferences = true),
        ),
        const SizedBox(width: AppSpacing.md),
        OutlineButton(
          text: 'Reject Non-Essential',
          onPressed: () => _handleConsent(ConsentLevel.essential),
        ),
        const SizedBox(width: AppSpacing.md),
        GradientButton(
          text: 'Accept All',
          onPressed: () => _handleConsent(ConsentLevel.all),
        ),
      ],
    );
  }

  Widget _buildMobileButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientButton(
          text: 'Accept All',
          onPressed: () => _handleConsent(ConsentLevel.all),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlineButton(
                text: 'Reject',
                onPressed: () => _handleConsent(ConsentLevel.essential),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlineButton(
                text: 'Manage',
                onPressed: () => setState(() => _showPreferences = true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreferencesView(bool isMobile) {
    // On mobile, constrain height and make scrollable to prevent overflow
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with back button
        Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: AppColors.gray300),
              onPressed: () => setState(() => _showPreferences = false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Cookie Preferences',
                style: AppTypography.headingSM.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // Essential cookies (always on)
        const _CookieCategory(
          title: 'Essential Cookies',
          description:
              'Required for the website to function properly. Cannot be disabled.',
          enabled: true,
          onChanged: null, // Cannot be changed
          required: true,
        ),

        const SizedBox(height: AppSpacing.md),

        // Analytics cookies
        _CookieCategory(
          title: 'Analytics Cookies',
          description:
              'Help us understand how visitors interact with our website using Google Analytics.',
          enabled: _analyticsEnabled,
          onChanged: (value) => setState(() => _analyticsEnabled = value),
        ),

        const SizedBox(height: AppSpacing.md),

        // Marketing cookies
        _CookieCategory(
          title: 'Marketing Cookies',
          description:
              'Used to track visitors across websites for advertising purposes (Facebook Pixel).',
          enabled: _marketingEnabled,
          onChanged: (value) => setState(() => _marketingEnabled = value),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Save buttons
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GradientButton(
                text: 'Save Preferences',
                onPressed: _handleCustomConsent,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlineButton(
                text: 'Accept All',
                onPressed: () => _handleConsent(ConsentLevel.all),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlineButton(
                text: 'Reject All',
                onPressed: () => _handleConsent(ConsentLevel.essential),
              ),
              const SizedBox(width: AppSpacing.md),
              GradientButton(
                text: 'Save Preferences',
                onPressed: _handleCustomConsent,
              ),
              const SizedBox(width: AppSpacing.md),
              OutlineButton(
                text: 'Accept All',
                onPressed: () => _handleConsent(ConsentLevel.all),
              ),
            ],
          ),
      ],
    );

    // On mobile, make scrollable and constrain max height to prevent overflow
    if (isMobile) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500),
        child: SingleChildScrollView(child: content),
      );
    }

    return content;
  }
}

class _CookieCategory extends StatelessWidget {
  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final bool required;

  const _CookieCategory({
    required this.title,
    required this.description,
    required this.enabled,
    this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTypography.bodyMD.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (required) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gray700,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSM),
                        ),
                        child: Text(
                          'Required',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTypography.bodySM,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeTrackColor: AppColors.blue500,
            inactiveThumbColor: required ? AppColors.gray500 : AppColors.gray400,
            inactiveTrackColor: AppColors.gray700,
          ),
        ],
      ),
    );
  }
}
