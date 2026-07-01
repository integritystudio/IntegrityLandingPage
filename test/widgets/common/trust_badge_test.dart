import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/common/trust_badge.dart';
import 'package:integrity_studio_ai/theme/theme.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('TrustBadge', () {
    testWidgets('renders icon and label', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const TrustBadge(
            icon: LucideIcons.shieldCheck,
            label: 'Enterprise Security',
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
      expect(find.text('Enterprise Security'), findsOneWidget);
    });

    testWidgets('uses success color for icon by default', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const TrustBadge(
            icon: LucideIcons.lock,
            label: 'GDPR Ready',
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.lock));
      expect(icon.color, AppColors.success);
    });

    testWidgets('uses custom iconColor when provided', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const TrustBadge(
            icon: LucideIcons.shieldCheck,
            label: 'Custom',
            iconColor: AppColors.blue400,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.shieldCheck));
      expect(icon.color, AppColors.blue400);
    });

    testWidgets('icon size is 16', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const TrustBadge(
            icon: LucideIcons.fileCheck,
            label: 'EU AI Act Ready',
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.fileCheck));
      expect(icon.size, 16.0);
    });
  });
}
