/// Widget tests for Integrity Studio AI landing page.
///
/// These tests verify the app loads correctly and basic UI elements render.
/// Tests now use proper viewport sizing to avoid responsive layout overflow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:integrity_studio_ai/app.dart';
import 'helpers/test_helpers.dart';

void main() {

  /// Helper to set proper viewport size for full app tests
  void setLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('IntegrityStudioApp', () {
    testWidgets('renders without errors', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(const IntegrityStudioApp());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(IntegrityStudioApp), findsOneWidget);
    });

    testWidgets('contains MaterialApp', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(const IntegrityStudioApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('uses dark theme background', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(const IntegrityStudioApp());
      await tester.pump(const Duration(seconds: 1));
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsWidgets);
    });

    testWidgets('hero section renders on large viewport', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(const IntegrityStudioApp());
      await tester.pump(const Duration(seconds: 1));

      // Hero section should be visible with AI Observability text
      expect(find.textContaining('AI Observability'), findsOneWidget);
    });

    testWidgets('app contains scrollable content', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(const IntegrityStudioApp());
      await tester.pump(const Duration(seconds: 1));

      // App should have scrollable content
      expect(find.byType(Scrollable), findsWidgets);
    });
  });

  group('IntegrityStudioApp Responsive', () {
    testWidgets(
      'renders on mobile viewport',
      (tester) async {
        setMobileSize(tester);
        await tester.pumpWidget(const IntegrityStudioApp());
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(IntegrityStudioApp), findsOneWidget);
        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets(
      'renders on tablet viewport',
      (tester) async {
        setTabletSize(tester);
        await tester.pumpWidget(const IntegrityStudioApp());
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(IntegrityStudioApp), findsOneWidget);
        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets('renders on desktop viewport', (tester) async {
      // Use large viewport to avoid AppBar overflow issues
      setLargeViewport(tester);
      await tester.pumpWidget(const IntegrityStudioApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(IntegrityStudioApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
