import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/config/content.dart';

void main() {

  group('ContactContent', () {
    group('current content', () {
      test('has required fields', () {
        final content = AppContent.contact;

        expect(content.sectionId, equals('contact'));
        expect(content.title, isNotEmpty);
        expect(content.subtitle, isNotEmpty);
        expect(content.description, isNotEmpty);
        expect(content.formSubmitText, isNotEmpty);
        expect(content.formSuccessMessage, isNotEmpty);
        expect(content.formErrorMessage, isNotEmpty);
      });

      test('has calendly integration', () {
        final content = AppContent.contact;

        expect(content.calendlyUrl, isNotEmpty);
        expect(content.calendlyUrl, contains('calendly.com'));
        expect(content.calendlyCtaText, isNotEmpty);
      });

      test('has 7 form fields', () {
        final content = AppContent.contact;

        expect(content.formFields.length, equals(7));
      });

      test('form has essential lead qualification fields', () {
        final content = AppContent.contact;
        final fieldNames = content.formFields.map((f) => f.name).toList();

        expect(fieldNames, contains('firstName'));
        expect(fieldNames, contains('lastName'));
        expect(fieldNames, contains('email'));
        expect(fieldNames, contains('company'));
        expect(fieldNames, contains('companySize'));
        expect(fieldNames, contains('useCase'));
        expect(fieldNames, contains('message'));
      });

      test('each form field has required properties', () {
        final content = AppContent.contact;

        for (final field in content.formFields) {
          expect(field.name, isNotEmpty);
          expect(field.label, isNotEmpty);
          expect(field.placeholder, isNotEmpty);
          expect(field.type, isNotEmpty);
        }
      });

      test('required fields are marked as required', () {
        final content = AppContent.contact;
        final requiredFields = content.formFields.where((f) => f.required);

        // At minimum: name, email, company should be required
        expect(requiredFields.length, greaterThanOrEqualTo(4));
      });

      test('select fields have options', () {
        final content = AppContent.contact;
        final selectFields =
            content.formFields.where((f) => f.type == 'select');

        for (final field in selectFields) {
          expect(field.options, isNotNull);
          expect(field.options, isNotEmpty);
        }
      });

      test('companySize field has enterprise-appropriate options', () {
        final content = AppContent.contact;
        final companySizeField = content.formFields.firstWhere(
          (f) => f.name == 'companySize',
        );

        expect(companySizeField.options, isNotNull);
        expect(companySizeField.options!.any((o) => o.contains('1,000')), isTrue);
      });

      test('useCase field includes EU AI Act Compliance option', () {
        final content = AppContent.contact;
        final useCaseField = content.formFields.firstWhere(
          (f) => f.name == 'useCase',
        );

        expect(useCaseField.options, isNotNull);
        expect(
          useCaseField.options!.any((o) => o.toLowerCase().contains('compliance')),
          isTrue,
        );
      });

      test('has 6 contact methods', () {
        final content = AppContent.contact;

        expect(content.contactMethods.length, equals(6));
      });

      test('contact methods include primary channels', () {
        final content = AppContent.contact;
        final labels = content.contactMethods.map((m) => m.label).toList();

        expect(labels, contains('Email'));
        expect(labels, contains('Schedule a Demo'));
        expect(labels, contains('Location'));
      });

      test('contact methods include social links', () {
        final content = AppContent.contact;
        final labels = content.contactMethods.map((m) => m.label).toList();

        expect(labels, contains('LinkedIn'));
        expect(labels, contains('X'));
        expect(labels, contains('GitHub'));
      });

      test('each contact method has required fields', () {
        final content = AppContent.contact;

        for (final method in content.contactMethods) {
          expect(method.icon, isNotNull);
          expect(method.label, isNotEmpty);
          expect(method.value, isNotEmpty);
        }
      });

      test('primary contact methods are marked as primary', () {
        final content = AppContent.contact;
        final primaryMethods =
            content.contactMethods.where((m) => m.isPrimary).toList();

        expect(primaryMethods.length, greaterThanOrEqualTo(2));
      });

      test('email method has valid email address', () {
        final content = AppContent.contact;
        final emailMethod = content.contactMethods.firstWhere(
          (m) => m.label == 'Email',
        );

        expect(emailMethod.value, contains('@'));
        expect(emailMethod.value, contains('integritystudio.ai'));
      });
    });

    group('ContactFormFieldContent', () {
      test('creates with all required fields', () {
        const field = ContactFormFieldContent(
          name: 'testField',
          label: 'Test Field',
          placeholder: 'Enter test',
          type: 'text',
          required: true,
          options: null,
        );

        expect(field.name, equals('testField'));
        expect(field.label, equals('Test Field'));
        expect(field.placeholder, equals('Enter test'));
        expect(field.type, equals('text'));
        expect(field.required, isTrue);
        expect(field.options, isNull);
      });

      test('creates select field with options', () {
        const field = ContactFormFieldContent(
          name: 'size',
          label: 'Size',
          placeholder: 'Select...',
          type: 'select',
          required: true,
          options: ['Small', 'Medium', 'Large'],
        );

        expect(field.type, equals('select'));
        expect(field.options, isNotNull);
        expect(field.options!.length, equals(3));
      });

      test('required defaults to false', () {
        const field = ContactFormFieldContent(
          name: 'optional',
          label: 'Optional',
          placeholder: 'Optional...',
          type: 'text',
        );

        expect(field.required, isFalse);
      });
    });

    group('ContactMethodContent', () {
      test('creates with all required fields', () {
        const method = ContactMethodContent(
          icon: LucideIcons.mail,
          label: 'Email',
          value: 'test@example.com',
          url: 'mailto:test@example.com',
          isPrimary: true,
        );

        expect(method.icon, equals(LucideIcons.mail));
        expect(method.label, equals('Email'));
        expect(method.value, equals('test@example.com'));
        expect(method.url, equals('mailto:test@example.com'));
        expect(method.isPrimary, isTrue);
      });

      test('url is optional', () {
        const method = ContactMethodContent(
          icon: LucideIcons.mapPin,
          label: 'Location',
          value: 'Austin, TX',
        );

        expect(method.url, isNull);
        expect(method.isPrimary, isFalse);
      });
    });

    group('ContactContent constructor', () {
      test('creates with all required fields', () {
        const content = ContactContent(
          sectionId: 'test-contact',
          title: 'Test Contact',
          subtitle: 'Test Subtitle',
          description: 'Test Description',
          formFields: [],
          contactMethods: [],
          formSubmitText: 'Submit',
          formSuccessMessage: 'Success!',
          formErrorMessage: 'Error!',
          calendlyUrl: 'https://calendly.com/test',
          calendlyCtaText: 'Book Call',
        );

        expect(content.sectionId, equals('test-contact'));
        expect(content.title, equals('Test Contact'));
        expect(content.formFields, isEmpty);
        expect(content.contactMethods, isEmpty);
        expect(content.calendlyUrl, equals('https://calendly.com/test'));
      });
    });

    group('content quality', () {
      test('form success message is professional', () {
        final content = AppContent.contact;

        expect(content.formSuccessMessage.length, greaterThan(20));
        expect(
          content.formSuccessMessage.toLowerCase(),
          contains('thank you'),
        );
      });

      test('form error message provides fallback contact', () {
        final content = AppContent.contact;

        expect(content.formErrorMessage, contains('email'));
      });

      test('description mentions demo option', () {
        final content = AppContent.contact;

        expect(content.description.toLowerCase(), contains('demo'));
      });

      test('email type field is properly typed', () {
        final content = AppContent.contact;
        final emailField = content.formFields.firstWhere(
          (f) => f.name == 'email',
        );

        expect(emailField.type, equals('email'));
        expect(emailField.required, isTrue);
      });

      test('message field is textarea type', () {
        final content = AppContent.contact;
        final messageField = content.formFields.firstWhere(
          (f) => f.name == 'message',
        );

        expect(messageField.type, equals('textarea'));
        expect(messageField.required, isFalse); // Message is optional
      });
    });
  });
}
