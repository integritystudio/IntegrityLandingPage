import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/sections/contact_section.dart';

/// Demo page with "Coming Soon" message and embedded contact form.
class DemoPage extends StatelessWidget {
  final VoidCallback? onBack;

  const DemoPage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray900,
      appBar: AppBar(
        backgroundColor: AppColors.gray900,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: onBack ?? () => context.go('/'),
        ),
        title: Text(
          'Demo',
          style: AppTypography.headingSM.copyWith(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Coming Soon hero
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.rocket,
                    size: 64,
                    color: AppColors.blue400,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Coming Soon!',
                    style: AppTypography.headingXL.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Our interactive demo is currently in development.\nContact us below for a personalized walkthrough.',
                    style: AppTypography.bodyLG.copyWith(
                      color: AppColors.gray300,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Embedded contact section
            const ContactSection(showLiveDemoSection: false),
          ],
        ),
      ),
    );
  }
}
