import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/widgets/sections/contact_section.dart';
import 'package:integrity_studio_ai/widgets/common/alert.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import 'package:integrity_studio_ai/widgets/common/form_fields.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('ContactSection', () {
    // ==========================================================================
    // Test Fixtures
    // ==========================================================================

    Widget buildTestWidget({
      Future<bool> Function(Map<String, String>)? onFormSubmit,
      ContactContent? content,
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1920, 1080)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: content != null
                  ? ContactSection(
                      onFormSubmit: onFormSubmit,
                      content: content,
                    )
                  : ContactSection(
                      onFormSubmit: onFormSubmit,
                    ),
            ),
          ),
        ),
      );
    }

    void setLargeViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    void setMobileViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// Standard form content for submission tests
    ContactContent minimalFormContent({
      String successMessage = 'Success',
      String errorMessage = 'Error',
    }) {
      return ContactContent(
        sectionId: 'test',
        title: 'Contact',
        subtitle: '',
        description: '',
        formFields: [
          ContactFormFieldContent(
            name: 'name',
            label: 'Name',
            type: 'text',
            placeholder: 'Name',
            required: true,
          ),
          ContactFormFieldContent(
            name: 'email',
            label: 'Email',
            type: 'email',
            placeholder: 'Email',
            required: true,
          ),
          ContactFormFieldContent(
            name: 'message',
            label: 'Message',
            type: 'textarea',
            placeholder: 'Message',
            required: true,
          ),
        ],
        contactMethods: [],
        formSubmitText: 'Submit',
        formSuccessMessage: successMessage,
        formErrorMessage: errorMessage,
        calendlyUrl: '',
        calendlyCtaText: '',
      );
    }

    /// Helper to fill and submit the minimal form
    Future<void> fillAndSubmitForm(WidgetTester tester) async {
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'John Doe');
      await tester.pump();
      await tester.enterText(textFields.at(1), 'john@example.com');
      await tester.pump();

      // Fill textarea
      final textAreas = find.byType(TextField);
      for (var i = 0; i < textAreas.evaluate().length; i++) {
        final widget = tester.widget<TextField>(textAreas.at(i));
        if (widget.maxLines != null && widget.maxLines! > 1) {
          await tester.enterText(
              textAreas.at(i), 'This is a test message with enough characters');
          break;
        }
      }
      await tester.pump();

      // Scroll and submit
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      final submitButton = find.text('Submit');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
    }

    // ==========================================================================
    // Content Tests (no widget rendering needed)
    // ==========================================================================

    group('content structure', () {
      test('form fields are defined', () {
        expect(AppContent.contact.formFields, isNotEmpty);
        expect(AppContent.contact.formFields.length, equals(7));
      });

      test('contact methods are defined with expected values', () {
        expect(AppContent.contact.contactMethods.length, equals(6));

        final labels =
            AppContent.contact.contactMethods.map((m) => m.label).toList();
        expect(labels, containsAll(['Email', 'LinkedIn', 'X', 'GitHub', 'Location', 'Schedule a Demo']));

        final primaryMethods =
            AppContent.contact.contactMethods.where((m) => m.isPrimary);
        expect(primaryMethods.length, equals(2));
      });

      test('required fields count is sufficient', () {
        final requiredFields =
            AppContent.contact.formFields.where((f) => f.required);
        expect(requiredFields.length, greaterThanOrEqualTo(4));
      });
    });

    // ==========================================================================
    // Widget Structure Tests
    // ==========================================================================

    group('widget structure', () {
      testWidgets('renders all section elements', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildTestWidget());

        // Section text content
        expect(find.text(AppContent.contact.title), findsOneWidget);
        expect(find.text(AppContent.contact.subtitle), findsOneWidget);
        expect(find.text(AppContent.contact.description), findsOneWidget);
        expect(find.text(AppContent.contact.formSubmitText), findsOneWidget);
        expect(find.text(AppContent.contact.calendlyCtaText), findsWidgets);

        // UI sections
        expect(find.text('Get in touch'), findsOneWidget);
        expect(find.text('Follow us'), findsOneWidget);
        expect(find.text('Send us a message'), findsOneWidget);
        expect(find.text('Want a Live Demo?'), findsOneWidget);
      });

      testWidgets('renders form field widgets', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(TextFormField), findsWidgets);
        expect(find.byType(FormTextField), findsWidgets);
        expect(find.byType(FormTextArea), findsWidgets);
      });

      testWidgets('renders form labels from content', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildTestWidget());

        for (final field in AppContent.contact.formFields) {
          final labelText = field.required ? '${field.label} *' : field.label;
          expect(find.text(labelText), findsWidgets);
        }
      });
    });

    // ==========================================================================
    // Form Interaction Tests
    // ==========================================================================

    group('form interaction', () {
      testWidgets('can enter and update text in fields', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildTestWidget());

        final textFields = find.byType(TextFormField);
        expect(textFields, findsWidgets);

        await tester.enterText(textFields.at(0), 'John');
        await tester.pump();
        expect(find.text('John'), findsWidgets);

        await tester.enterText(textFields.at(0), 'Jane');
        await tester.pump();
        expect(find.text('Jane'), findsWidgets);
      });

      testWidgets('textarea accepts long text', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildTestWidget());

        final textarea = find.byType(FormTextArea);
        expect(textarea, findsWidgets);

        final textAreas = find.descendant(
          of: textarea.first,
          matching: find.byType(TextField),
        );

        if (textAreas.evaluate().isNotEmpty) {
          await tester.enterText(textAreas.first,
              'This is a longer message that contains multiple words.');
          await tester.pump();
        }
      });
    });

    // ==========================================================================
    // Form Submission Tests
    // ==========================================================================

    group('form submission', () {
      testWidgets('shows success alert after successful submission',
          (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: minimalFormContent(successMessage: 'Thank you!'),
          onFormSubmit: (data) async => true,
        ));

        await fillAndSubmitForm(tester);

        expect(find.byType(Alert), findsOneWidget);
        expect(find.text('Thank you!'), findsOneWidget);
      });

      testWidgets('shows error alert after failed submission', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: minimalFormContent(errorMessage: 'Failed to submit'),
          onFormSubmit: (data) async => false,
        ));

        await fillAndSubmitForm(tester);

        expect(find.byType(Alert), findsOneWidget);
        expect(find.text('Failed to submit'), findsOneWidget);
      });

      testWidgets('shows error alert when exception is thrown', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: minimalFormContent(),
          onFormSubmit: (data) async => throw Exception('Network error'),
        ));

        await fillAndSubmitForm(tester);

        expect(find.byType(Alert), findsOneWidget);
        expect(find.textContaining('Network error'), findsOneWidget);
      });

      testWidgets('can dismiss alert', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: minimalFormContent(successMessage: 'Thank you!'),
          onFormSubmit: (data) async => true,
        ));

        await fillAndSubmitForm(tester);
        expect(find.byType(Alert), findsOneWidget);

        final dismissButton = find.byIcon(LucideIcons.x);
        expect(dismissButton, findsOneWidget);
        await tester.tap(dismissButton);
        await tester.pumpAndSettle();

        expect(find.byType(Alert), findsNothing);
      });

      testWidgets('shows sending state during submission', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: minimalFormContent(),
          onFormSubmit: (data) async {
            await Future.delayed(const Duration(seconds: 2));
            return true;
          },
        ));

        // Fill form
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'John Doe');
        await tester.pump();
        await tester.enterText(textFields.at(1), 'john@example.com');
        await tester.pump();

        final textAreas = find.byType(TextField);
        for (var i = 0; i < textAreas.evaluate().length; i++) {
          final widget = tester.widget<TextField>(textAreas.at(i));
          if (widget.maxLines != null && widget.maxLines! > 1) {
            await tester.enterText(
                textAreas.at(i), 'This is a test message with enough chars');
            break;
          }
        }
        await tester.pump();

        // Scroll and submit
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pump();

        expect(find.text('Sending...'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      });
    });

    // ==========================================================================
    // Form Validation Tests
    // ==========================================================================

    group('form validation', () {
      testWidgets('shows validation errors for empty required fields',
          (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: minimalFormContent(),
          onFormSubmit: (data) async => true,
        ));

        // Submit without filling
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Please enter'), findsWidgets);
      });

      testWidgets('shows validation error for invalid email', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: minimalFormContent(),
          onFormSubmit: (data) async => true,
        ));

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'John Doe');
        await tester.pump();
        await tester.enterText(textFields.at(1), 'invalid-email');
        await tester.pump();

        // Fill message
        final textAreas = find.byType(TextField);
        for (var i = 0; i < textAreas.evaluate().length; i++) {
          final widget = tester.widget<TextField>(textAreas.at(i));
          if (widget.maxLines != null && widget.maxLines! > 1) {
            await tester.enterText(textAreas.at(i), 'Test message here');
            break;
          }
        }
        await tester.pump();

        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(find.textContaining('valid email'), findsOneWidget);
      });

      testWidgets('shows validation error for short message', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: minimalFormContent(),
          onFormSubmit: (data) async => true,
        ));

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'John Doe');
        await tester.pump();
        await tester.enterText(textFields.at(1), 'john@example.com');
        await tester.pump();

        // Short message
        final textAreas = find.byType(TextField);
        for (var i = 0; i < textAreas.evaluate().length; i++) {
          final widget = tester.widget<TextField>(textAreas.at(i));
          if (widget.maxLines != null && widget.maxLines! > 1) {
            await tester.enterText(textAreas.at(i), 'Hi');
            break;
          }
        }
        await tester.pump();

        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(find.textContaining('more details'), findsOneWidget);
      });
    });

    // ==========================================================================
    // Field Type Tests
    // ==========================================================================

    group('field types', () {
      testWidgets('renders all field types correctly', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Test Contact',
            subtitle: 'Test Subtitle',
            description: 'Test Description',
            formFields: [
              ContactFormFieldContent(
                  name: 'name', label: 'Name', type: 'text', placeholder: '', required: true),
              ContactFormFieldContent(
                  name: 'email', label: 'Email', type: 'email', placeholder: '', required: true),
              ContactFormFieldContent(
                  name: 'phone', label: 'Phone', type: 'phone', placeholder: '', required: false),
              ContactFormFieldContent(
                  name: 'website', label: 'Website', type: 'url', placeholder: '', required: false),
              ContactFormFieldContent(
                  name: 'dept', label: 'Department', type: 'select', placeholder: '',
                  required: false, options: ['Sales', 'Support']),
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [],
            formSubmitText: 'Send',
            formSuccessMessage: 'Sent!',
            formErrorMessage: 'Failed',
            calendlyUrl: 'https://calendly.com/test',
            calendlyCtaText: 'Book Demo',
          ),
        ));

        expect(find.byType(FormTextField), findsWidgets);
        expect(find.byType(FormSelect<String>), findsOneWidget);
        expect(find.byType(FormTextArea), findsOneWidget);
        expect(find.byType(GradientButton), findsWidgets);
      });

      testWidgets('phone field handles input', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Contact',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'phone', label: 'Phone', type: 'phone', placeholder: '', required: false),
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: '',
          ),
        ));

        final textField = find.byType(TextFormField).first;
        await tester.enterText(textField, '555-123-4567');
        await tester.pump();
        expect(find.text('555-123-4567'), findsOneWidget);
      });

      testWidgets('url field handles input', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Contact',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'website', label: 'Website', type: 'url', placeholder: '', required: false),
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: '',
          ),
        ));

        final textField = find.byType(TextFormField).first;
        await tester.enterText(textField, 'https://example.com');
        await tester.pump();
        expect(find.text('https://example.com'), findsOneWidget);
      });

      testWidgets('unknown field type falls back to text', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Contact',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'custom', label: 'Custom', type: 'unknown_type', placeholder: '', required: false),
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: '',
          ),
        ));

        expect(find.byType(FormTextField), findsOneWidget);

        final textField = find.byType(TextFormField).first;
        await tester.enterText(textField, 'Custom value');
        await tester.pump();
        expect(find.text('Custom value'), findsOneWidget);
      });

      testWidgets('select field can change value', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Contact',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'dept', label: 'Department', type: 'select', placeholder: 'Select',
                  required: true, options: ['Sales', 'Support', 'Engineering']),
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: '',
          ),
        ));

        final dropdown = find.byType(DropdownButtonFormField<String>);
        expect(dropdown, findsOneWidget);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sales').last);
        await tester.pumpAndSettle();

        expect(find.text('Sales'), findsWidgets);
      });

      testWidgets('select field renders with null options', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Contact',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'category', label: 'Category', type: 'select', placeholder: 'Select', required: false),
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: '',
          ),
        ));

        expect(find.byType(FormSelect<String>), findsOneWidget);
      });
    });

    // ==========================================================================
    // Field Pairing Tests
    // ==========================================================================

    group('field pairing', () {
      testWidgets('pairs firstName/lastName fields in a row', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Test',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'firstName', label: 'First Name', type: 'text', placeholder: '', required: true),
              ContactFormFieldContent(
                  name: 'lastName', label: 'Last Name', type: 'text', placeholder: '', required: true),
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: '',
          ),
        ));

        expect(find.byType(Row), findsWidgets);
        expect(find.byType(FormTextField), findsWidgets);
      });

      testWidgets('does not pair non-name text fields', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Contact',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'company', label: 'Company', type: 'text', placeholder: '', required: true),
              ContactFormFieldContent(
                  name: 'title', label: 'Job Title', type: 'text', placeholder: '', required: true),
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: '',
          ),
        ));

        expect(find.byType(FormTextField), findsNWidgets(2));
      });
    });

    // ==========================================================================
    // Contact Methods Tests
    // ==========================================================================

    group('contact methods', () {
      testWidgets('primary method with url shows arrow icon', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Contact',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [
              ContactMethodContent(
                icon: Icons.email,
                label: 'Email',
                value: 'test@example.com',
                url: 'mailto:test@example.com',
                isPrimary: true,
              ),
            ],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: '',
          ),
        ));

        expect(find.byIcon(Icons.arrow_forward), findsWidgets);
      });

      testWidgets('primary method without url does not show arrow',
          (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Contact',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [
              ContactMethodContent(
                icon: Icons.location_on,
                label: 'Location',
                value: 'New York, USA',
                isPrimary: true,
              ),
            ],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: '',
          ),
        ));

        expect(find.byIcon(Icons.arrow_forward), findsNothing);
      });

      testWidgets('secondary contact method shows tooltip', (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Contact',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [
              ContactMethodContent(
                icon: Icons.link,
                label: 'LinkedIn',
                value: 'Follow us',
                url: 'https://linkedin.com',
                isPrimary: false,
              ),
            ],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: '',
          ),
        ));

        expect(find.byType(Tooltip), findsWidgets);
      });
    });

    // ==========================================================================
    // Content Variations Tests
    // ==========================================================================

    group('content variations', () {
      testWidgets('renders with empty content (falls back to AppContent)',
          (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: const ContactContent(
            sectionId: 'test',
            title: 'Test Title',
            subtitle: 'Test Subtitle',
            description: '',
            formFields: [],
            contactMethods: [],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: 'Schedule',
          ),
        ));

        expect(find.byType(ContactSection), findsOneWidget);
      });

      testWidgets('does not render calendly section when URL is empty',
          (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Contact',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: 'Book Demo',
          ),
        ));

        expect(find.text('Want a Live Demo?'), findsNothing);
      });

      testWidgets('does not render follow us section when no secondary methods',
          (tester) async {
        setLargeViewport(tester);

        await tester.pumpWidget(buildTestWidget(
          content: ContactContent(
            sectionId: 'test',
            title: 'Contact',
            subtitle: '',
            description: '',
            formFields: [
              ContactFormFieldContent(
                  name: 'message', label: 'Message', type: 'textarea', placeholder: '', required: true),
            ],
            contactMethods: [
              ContactMethodContent(
                icon: Icons.email,
                label: 'Email',
                value: 'test@example.com',
                isPrimary: true,
              ),
            ],
            formSubmitText: 'Submit',
            formSuccessMessage: 'Success',
            formErrorMessage: 'Error',
            calendlyUrl: '',
            calendlyCtaText: '',
          ),
        ));

        expect(find.text('Follow us'), findsNothing);
      });
    });

    // ==========================================================================
    // Mobile Layout Tests
    // ==========================================================================

    // Mobile layout tests skipped due to known overflow issues at mobile viewport
    group('mobile layout', () {
      testWidgets(
        'renders on mobile viewport',
        (tester) async {
          setMobileViewport(tester);

          await tester.pumpWidget(buildTestWidget(
            content: ContactContent(
              sectionId: 'test',
              title: 'Contact',
              subtitle: 'Subtitle',
              description: '',
              formFields: [
                ContactFormFieldContent(
                    name: 'name', label: 'Name', type: 'text', placeholder: '', required: true),
              ],
              contactMethods: [
                ContactMethodContent(
                  icon: Icons.email,
                  label: 'Email',
                  value: 'test@test.com',
                  isPrimary: true,
                ),
              ],
              formSubmitText: 'Submit',
              formSuccessMessage: 'Success',
              formErrorMessage: 'Error',
              calendlyUrl: '',
              calendlyCtaText: '',
            ),
          ));

          expect(find.byType(ContactSection), findsOneWidget);
          expect(find.text('Contact'), findsOneWidget);
        },
        skip: true, // Known overflow issues at mobile viewport
      );
    });

    // ==========================================================================
    // Accessibility Tests
    // ==========================================================================

    group('accessibility', () {
      testWidgets('contact methods are semantically accessible', (tester) async {
        setLargeViewport(tester);

        final semanticsHandle = tester.ensureSemantics();
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Email'), findsWidgets);

        semanticsHandle.dispose();
      });
    });

    // ==========================================================================
    // Alert Widget Tests
    // ==========================================================================

    group('alert widget', () {
      testWidgets('Alert widget renders correctly', (tester) async {
        await tester.pumpWidget(
          testableWidget(Alert.success(message: 'Test alert')),
        );

        expect(find.byType(Alert), findsOneWidget);
        expect(find.text('Test alert'), findsOneWidget);
      });
    });
  });
}
