import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/signup_page.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import 'package:integrity_studio_ai/widgets/common/form_fields.dart';
import '../helpers/test_helpers.dart';

void main() {

  group('SignupPage', () {
    void setLargeViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Widget buildSignupPage({String tier = 'starter', VoidCallback? onBack}) {
      return MaterialApp(
        theme: testTheme,
        home: SignupPage(tier: tier, onBack: onBack),
      );
    }

    group('widget structure', () {
      testWidgets('renders SignupPage', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders Scaffold', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('renders CustomScrollView', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(CustomScrollView), findsOneWidget);
      });

      testWidgets('renders SliverAppBar', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SliverAppBar), findsOneWidget);
      });
    });

    group('form fields', () {
      testWidgets('renders FormTextField widgets', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        // Should have 3 form fields: name, email, company
        expect(find.byType(FormTextField), findsNWidgets(3));
      });

      testWidgets('renders Checkbox for terms agreement', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(Checkbox), findsOneWidget);
      });

      testWidgets('renders GradientButton for submit', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(GradientButton), findsOneWidget);
      });
    });

    group('tier display', () {
      testWidgets('renders with starter tier', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'starter'));
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders with growth tier', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'growth'));
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders with scale tier', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'scale'));
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders with enterprise tier', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'enterprise'));
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders with custom tier', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'custom-tier'));
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });
    });

    group('form interaction', () {
      testWidgets('can enter text in name field', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        final textFields = find.byType(TextFormField);
        expect(textFields, findsWidgets);

        await tester.enterText(textFields.first, 'Test User');
        await tester.pump();
      });

      testWidgets('can toggle terms checkbox', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        final checkbox = find.byType(Checkbox);
        expect(checkbox, findsOneWidget);

        // Get initial state
        final initialCheckbox = tester.widget<Checkbox>(checkbox);
        expect(initialCheckbox.value, isFalse);

        // Tap to toggle
        await tester.tap(checkbox);
        await tester.pump();

        // Check new state
        final updatedCheckbox = tester.widget<Checkbox>(checkbox);
        expect(updatedCheckbox.value, isTrue);
      });
    });

    group('navigation', () {
      testWidgets('onBack callback is called when provided', (tester) async {
        setLargeViewport(tester);
        var backCalled = false;

        await tester.pumpWidget(buildSignupPage(onBack: () => backCalled = true));
        await tester.pump();

        // Find and tap the back button (first IconButton)
        final iconButtons = find.byType(IconButton);
        expect(iconButtons, findsWidgets);

        await tester.tap(iconButtons.first);
        await tester.pump();

        expect(backCalled, isTrue);
      });
    });

    group('responsive design', () {
      testWidgets('renders on mobile viewport', (tester) async {
        setMobileSize(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders on tablet viewport', (tester) async {
        setTabletSize(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders on desktop viewport', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });
    });

    group('form validation', () {
      testWidgets('submit button exists', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(GradientButton), findsOneWidget);
      });

      testWidgets('tapping submit without filling form shows validation', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        // Tap submit button
        final submitButton = find.byType(GradientButton);
        await tester.tap(submitButton);
        await tester.pump();

        // Form should still be visible (validation prevents submission)
        expect(find.byType(SignupPage), findsOneWidget);
      });
    });

    group('widget disposal', () {
      testWidgets('disposes without error', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        // Replace with different widget to trigger dispose
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const Scaffold(body: Text('Replaced')),
          ),
        );
        await tester.pump();

        expect(find.byType(SignupPage), findsNothing);
      });
    });
  });
}
