import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:integrity_studio_ai/main.dart' as app;
import 'package:integrity_studio_ai/widgets/common/alert.dart';

/// E2E tests for the contact form submission workflow.
///
/// Tests the complete user journey: scrolling to the contact form, verifying
/// field rendering, entering data, validating input, and submitting.
///
/// NOTE: Uses pump(Duration) instead of pumpAndSettle() because the landing
/// page has continuous animations that would cause pumpAndSettle to timeout.
///
/// NOTE: Uses directEnterText() instead of tester.enterText() because
/// IntegrationTestWidgetsFlutterBinding (which extends LiveTestWidgetsFlutterBinding)
/// does not register testTextInput in showKeyboard(), leaving _client null.
/// In profile mode (dart2js), the null dereference produces an empty TypeError.
/// directEnterText bypasses testTextInput by calling EditableTextState.updateEditingValue
/// directly.
///
/// NOTE: Test data must not match field placeholder text (e.g. content.yaml
/// sets lastName placeholder to "Smith"). Hint text stays in the widget tree
/// at opacity 0, so find.text matches both the hint and the entered value,
/// causing findsOneWidget to fail with 2 matches.
///
/// PREREQUISITE: chromedriver must be installed for `flutter drive -d chrome`.
///   brew install chromedriver  # macOS
///   Then: flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/e2e/contact_form_test.dart -d chrome
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /// Pump frames without waiting for animations to settle.
  Future<void> pumpFrames(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Dismiss cookie consent banner if present.
  Future<void> dismissCookieBanner(WidgetTester tester) async {
    final acceptButton = find.text('Accept All');
    if (acceptButton.evaluate().isNotEmpty) {
      await tester.tap(acceptButton);
      await pumpFrames(tester, frames: 5);
    }
  }

  /// Scroll to the contact section at the bottom of the page.
  ///
  /// Uses scrollUntilVisible to reliably reach the contact form header
  /// regardless of total page height (the section count can grow).
  Future<void> scrollToContactSection(WidgetTester tester) async {
    final scrollableFinder = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Send us a message'),
      500.0,
      scrollable: scrollableFinder,
      maxScrolls: 100,
    );
    await pumpFrames(tester, frames: 5);
  }

  /// Find the form submit button. Returns the finder (may be empty).
  Finder findSubmitButton() {
    // Real content.yaml uses "Send Message"; fallback to other patterns
    final candidates = [
      find.textContaining('Send Message'),
      find.textContaining('Send'),
      find.textContaining('Submit'),
      find.textContaining('Start Your Journey'),
    ];
    for (final f in candidates) {
      if (f.evaluate().isNotEmpty) return f.first;
    }
    return candidates.first;
  }

  /// Find a TextFormField by its associated label text.
  Finder findFieldByLabel(String label) {
    return find.textContaining(label);
  }

  /// Scroll field into viewport then enter text via EditableTextState.
  ///
  /// Bypasses tester.enterText() which is broken in
  /// IntegrationTestWidgetsFlutterBinding (testTextInput._client is null).
  /// Instead, directly calls updateEditingValue on the EditableTextState.
  Future<void> directEnterText(
      WidgetTester tester, Finder field, String text) async {
    await tester.ensureVisible(field);
    await pumpFrames(tester, frames: 2);
    final EditableTextState editableState = tester.state<EditableTextState>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    editableState.updateEditingValue(TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ));
    await pumpFrames(tester, frames: 5);
  }

  /// Bootstrap the app and scroll to the contact section.
  Future<void> launchAndScrollToContact(WidgetTester tester) async {
    app.main();
    await pumpFrames(tester, frames: 20);
    await dismissCookieBanner(tester);
    await scrollToContactSection(tester);
  }

  // ===========================================================================
  // Contact Form Rendering (E2: replace soft assertions)
  // ===========================================================================

  group('Contact Form Rendering', () {
    testWidgets('contact section is reachable via scrolling', (tester) async {
      await launchAndScrollToContact(tester);

      // The form card header is hardcoded in ContactSection widget
      expect(
        find.text('Send us a message'),
        findsOneWidget,
        reason: 'Form header "Send us a message" should be visible',
      );
    });

    testWidgets('form renders text input fields', (tester) async {
      await launchAndScrollToContact(tester);

      // Content.yaml defines: firstName, lastName, email, company as text/email fields
      final textFormFields = find.byType(TextFormField);
      expect(
        textFormFields.evaluate().length,
        greaterThanOrEqualTo(4),
        reason: 'Form should have at least 4 TextFormFields '
            '(firstName, lastName, email, company)',
      );
    });

    testWidgets('form renders field labels', (tester) async {
      await launchAndScrollToContact(tester);

      // Required fields show label with asterisk (e.g. "First Name *")
      for (final label in ['First Name', 'Last Name', 'Email', 'Company']) {
        expect(
          findFieldByLabel(label),
          findsWidgets,
          reason: '"$label" label should be visible in the form',
        );
      }
    });

    testWidgets('submit button is present with correct text', (tester) async {
      await launchAndScrollToContact(tester);

      // Content.yaml: submit_text: "Send Message"
      expect(
        find.textContaining('Send Message'),
        findsOneWidget,
        reason: 'Submit button should display "Send Message"',
      );
    });

    testWidgets('contact methods section renders', (tester) async {
      await launchAndScrollToContact(tester);

      // "Get in touch" is hardcoded in ContactSection._buildContactMethods
      expect(
        find.text('Get in touch'),
        findsOneWidget,
        reason: '"Get in touch" contact methods header should be visible',
      );
    });

    testWidgets('calendly demo CTA renders', (tester) async {
      await launchAndScrollToContact(tester);

      // Content.yaml: calendly_cta_text: "View Demo"
      // And the hardcoded label: "Want a Live Demo?"
      expect(
        find.text('Want a Live Demo?'),
        findsOneWidget,
        reason: 'Live demo CTA card should be visible',
      );
    });
  });

  // ===========================================================================
  // Form Field Interaction
  // ===========================================================================

  group('Contact Form Interaction', () {
    testWidgets('text fields accept user input', (tester) async {
      await launchAndScrollToContact(tester);

      final textFields = find.byType(TextFormField);
      expect(textFields.evaluate().length, greaterThanOrEqualTo(3),
          reason: 'Need at least 3 text fields to test input');

      // Enter text in the first two fields (firstName, lastName)
      await directEnterText(tester, textFields.at(0), 'Jane');
      await directEnterText(tester, textFields.at(1), 'Doe');

      expect(find.text('Jane'), findsOneWidget);
      expect(find.text('Doe'), findsOneWidget);
    });

    testWidgets('email field accepts email input', (tester) async {
      await launchAndScrollToContact(tester);

      final textFields = find.byType(TextFormField);
      // Email is the 3rd TextFormField (index 2) per content.yaml field order
      await directEnterText(tester, textFields.at(2), 'jane@example.com');

      expect(find.text('jane@example.com'), findsOneWidget);
    });

    testWidgets('can scroll back to top after viewing contact form',
        (tester) async {
      await launchAndScrollToContact(tester);

      // Verify we're at the contact section
      expect(find.text('Send us a message'), findsOneWidget);

      // Scroll back up
      final scrollableFinder = find.byType(Scrollable).first;
      for (var i = 0; i < 10; i++) {
        await tester.fling(scrollableFinder, const Offset(0, 1000), 2000);
        await pumpFrames(tester, frames: 8);
      }

      // Hero section text should be visible again
      final heroText = find.textContaining('AI Observability');
      expect(heroText.evaluate().isNotEmpty, isTrue,
          reason: 'Hero section should be visible after scrolling back up');
    });
  });

  // ===========================================================================
  // Form Validation (E1/E2: verify validation error display)
  // ===========================================================================

  group('Contact Form Validation', () {
    testWidgets('empty submission shows validation errors', (tester) async {
      await launchAndScrollToContact(tester);

      // Tap submit without filling any fields
      final submitBtn = findSubmitButton();
      await tester.ensureVisible(submitBtn);
      await pumpFrames(tester, frames: 3);
      await tester.tap(submitBtn);
      await pumpFrames(tester, frames: 10);

      // ContactService.validateForm returns "Please enter your full name"
      // and "Please enter your email address" for empty required fields
      expect(
        find.text('Please enter your full name'),
        findsWidgets,
        reason: 'Name validation error should appear on empty submission',
      );
      expect(
        find.text('Please enter your email address'),
        findsWidgets,
        reason: 'Email validation error should appear on empty submission',
      );
    });

    testWidgets('invalid email shows validation error', (tester) async {
      await launchAndScrollToContact(tester);

      final textFields = find.byType(TextFormField);

      // Fill name fields so only email validation fires
      await directEnterText(tester, textFields.at(0), 'Jane');
      await directEnterText(tester, textFields.at(1), 'Doe');

      // Enter invalid email
      await directEnterText(tester, textFields.at(2), 'not-an-email');

      // Fill company (required field, index 3)
      await directEnterText(tester, textFields.at(3), 'Acme Inc');

      // Submit
      final submitBtn = findSubmitButton();
      await tester.ensureVisible(submitBtn);
      await pumpFrames(tester, frames: 3);
      await tester.tap(submitBtn);
      await pumpFrames(tester, frames: 10);

      expect(
        find.text('Please enter a valid email address'),
        findsWidgets,
        reason: 'Email validation error should appear for invalid email',
      );
    });

    testWidgets('valid form data passes client validation', (tester) async {
      await launchAndScrollToContact(tester);

      final textFields = find.byType(TextFormField);

      // Fill all required fields with valid data
      await directEnterText(tester, textFields.at(0), 'Jane');
      await directEnterText(tester, textFields.at(1), 'Doe');
      await directEnterText(tester, textFields.at(2), 'jane@example.com');
      await directEnterText(tester, textFields.at(3), 'Acme Inc');

      // Submit — should pass validation (no client-side errors)
      final submitBtn = findSubmitButton();
      await tester.ensureVisible(submitBtn);
      await pumpFrames(tester, frames: 3);
      await tester.tap(submitBtn);
      // Wait long enough for async network response to arrive and
      // reset _isSubmitting, preventing state leakage into the next test.
      await pumpFrames(tester, frames: 30);

      // Validation errors should NOT be present
      expect(
        find.text('Please enter your full name'),
        findsNothing,
        reason: 'No name validation error with valid name',
      );
      expect(
        find.text('Please enter your email address'),
        findsNothing,
        reason: 'No email validation error with valid email',
      );
      expect(
        find.text('Please enter a valid email address'),
        findsNothing,
        reason: 'No email format error with valid email',
      );
    });
  });

  // ===========================================================================
  // Form Submission (E1: submit-response-alert cycle)
  // ===========================================================================

  group('Contact Form Submission', () {
    testWidgets('submit shows loading state then error alert', (tester) async {
      await launchAndScrollToContact(tester);

      final textFields = find.byType(TextFormField);

      // Fill all required fields
      await directEnterText(tester, textFields.at(0), 'Jane');
      await directEnterText(tester, textFields.at(1), 'Doe');
      await directEnterText(tester, textFields.at(2), 'jane@example.com');
      await directEnterText(tester, textFields.at(3), 'Acme Inc');

      // Submit the form
      final submitBtn = findSubmitButton();
      await tester.ensureVisible(submitBtn);
      await pumpFrames(tester, frames: 3);
      await tester.tap(submitBtn);

      // Immediately after tap, button should show "Sending..." loading state
      await pumpFrames(tester, frames: 2);
      final sendingText = find.textContaining('Sending');
      // Loading state may be brief; check it appeared or already resolved
      final showedLoadingOrResolved =
          sendingText.evaluate().isNotEmpty || find.byType(Alert).evaluate().isNotEmpty;
      expect(showedLoadingOrResolved, isTrue,
          reason: 'Should show loading state or have already received response');

      // Wait for the network request to fail (no real backend in test)
      // ContactService retries with exponential backoff; wait enough frames
      await pumpFrames(tester, frames: 80);

      // An error Alert should appear since the API is unreachable
      expect(
        find.byType(Alert),
        findsOneWidget,
        reason: 'Error Alert should appear after failed network request',
      );
    });

    testWidgets('submit button re-enables after error', (tester) async {
      await launchAndScrollToContact(tester);

      final textFields = find.byType(TextFormField);

      // Fill required fields
      await directEnterText(tester, textFields.at(0), 'Jane');
      await directEnterText(tester, textFields.at(1), 'Doe');
      await directEnterText(tester, textFields.at(2), 'jane@example.com');
      await directEnterText(tester, textFields.at(3), 'Acme Inc');

      // Submit and wait for error
      final submitBtn = findSubmitButton();
      await tester.ensureVisible(submitBtn);
      await pumpFrames(tester, frames: 3);
      await tester.tap(submitBtn);
      await pumpFrames(tester, frames: 80);

      // After error, button should show original text again (not "Sending...")
      expect(
        find.textContaining('Send Message'),
        findsOneWidget,
        reason: 'Submit button should re-enable after error response',
      );
      expect(
        find.textContaining('Sending'),
        findsNothing,
        reason: 'Loading text should be gone after error response',
      );
    });
  });
}
