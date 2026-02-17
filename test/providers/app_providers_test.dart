import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:integrity_studio_ai/providers/app_providers.dart';
import 'package:integrity_studio_ai/controllers/landing_controller.dart';

void main() {
  group('AppProviders', () {
    testWidgets('provides LandingController to descendants', (tester) async {
      LandingController? captured;

      await tester.pumpWidget(
        AppProviders(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                captured = context.read<LandingController>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured, isNotNull);
      expect(captured, isA<LandingController>());
    });

    testWidgets('provides ContentVariantController to descendants',
        (tester) async {
      ContentVariantController? captured;

      await tester.pumpWidget(
        AppProviders(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                captured = context.read<ContentVariantController>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured, isNotNull);
      expect(captured, isA<ContentVariantController>());
    });

    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        AppProviders(
          child: const MaterialApp(
            home: Text('Test Child'),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });
  });

  group('ProviderExtensions', () {
    testWidgets('landingController extension returns controller',
        (tester) async {
      LandingController? captured;

      await tester.pumpWidget(
        AppProviders(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                captured = context.landingController;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured, isNotNull);
    });

    testWidgets('variantController extension returns controller',
        (tester) async {
      ContentVariantController? captured;

      await tester.pumpWidget(
        AppProviders(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                captured = context.variantController;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured, isNotNull);
    });
  });
}
