import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content/contact_content.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_constants.dart';

void main() {
  setUpAll(initializeTestContent);

  group('ContactContentVariants', () {
    group('static constants', () {
      group('hero content', () {
        test('heroBadge is non-empty', () {
          expect(ContactContentVariants.heroBadge, isNotEmpty);
        });

        test('heroHeadline is non-empty', () {
          expect(ContactContentVariants.heroHeadline, isNotEmpty);
        });

        test('heroSubheadline is non-empty', () {
          expect(ContactContentVariants.heroSubheadline, isNotEmpty);
        });
      });

      group('field names and labels', () {
        test('firstNameFieldName is non-empty', () {
          expect(ContactContentVariants.firstNameFieldName, isNotEmpty);
        });

        test('firstNameLabel is non-empty', () {
          expect(ContactContentVariants.firstNameLabel, isNotEmpty);
        });

        test('lastNameFieldName is non-empty', () {
          expect(ContactContentVariants.lastNameFieldName, isNotEmpty);
        });

        test('lastNameLabel is non-empty', () {
          expect(ContactContentVariants.lastNameLabel, isNotEmpty);
        });

        test('emailFieldName is non-empty', () {
          expect(ContactContentVariants.emailFieldName, isNotEmpty);
        });

        test('emailLabel is non-empty', () {
          expect(ContactContentVariants.emailLabel, isNotEmpty);
        });

        test('companyFieldName is non-empty', () {
          expect(ContactContentVariants.companyFieldName, isNotEmpty);
        });

        test('companyLabel is non-empty', () {
          expect(ContactContentVariants.companyLabel, isNotEmpty);
        });

        test('companySizeFieldName is non-empty', () {
          expect(ContactContentVariants.companySizeFieldName, isNotEmpty);
        });

        test('companySizeLabel is non-empty', () {
          expect(ContactContentVariants.companySizeLabel, isNotEmpty);
        });

        test('useCaseFieldName is non-empty', () {
          expect(ContactContentVariants.useCaseFieldName, isNotEmpty);
        });

        test('useCaseLabel is non-empty', () {
          expect(ContactContentVariants.useCaseLabel, isNotEmpty);
        });

        test('messageFieldName is non-empty', () {
          expect(ContactContentVariants.messageFieldName, isNotEmpty);
        });

        test('messageLabel is non-empty', () {
          expect(ContactContentVariants.messageLabel, isNotEmpty);
        });
      });

      group('field placeholders', () {
        test('firstNamePlaceholder is non-empty', () {
          expect(ContactContentVariants.firstNamePlaceholder, isNotEmpty);
        });

        test('lastNamePlaceholder is non-empty', () {
          expect(ContactContentVariants.lastNamePlaceholder, isNotEmpty);
        });

        test('emailPlaceholder is non-empty', () {
          expect(ContactContentVariants.emailPlaceholder, isNotEmpty);
        });

        test('companyPlaceholder is non-empty', () {
          expect(ContactContentVariants.companyPlaceholder, isNotEmpty);
        });

        test('selectPlaceholder is non-empty', () {
          expect(ContactContentVariants.selectPlaceholder, isNotEmpty);
        });

        test('messagePlaceholder is non-empty', () {
          expect(ContactContentVariants.messagePlaceholder, isNotEmpty);
        });
      });

      group('field types', () {
        test('textFieldType is non-empty', () {
          expect(ContactContentVariants.textFieldType, isNotEmpty);
        });

        test('emailFieldType is non-empty', () {
          expect(ContactContentVariants.emailFieldType, isNotEmpty);
        });

        test('selectFieldType is non-empty', () {
          expect(ContactContentVariants.selectFieldType, isNotEmpty);
        });

        test('textareaFieldType is non-empty', () {
          expect(ContactContentVariants.textareaFieldType, isNotEmpty);
        });
      });

      group('field options', () {
        test('companySizeOptions is non-empty', () {
          expect(ContactContentVariants.companySizeOptions, isNotEmpty);
        });

        test('useCaseOptions is non-empty', () {
          expect(ContactContentVariants.useCaseOptions, isNotEmpty);
        });
      });

      group('contact method labels and values', () {
        test('emailMethodLabel is non-empty', () {
          expect(ContactContentVariants.emailMethodLabel, isNotEmpty);
        });

        test('scheduleADemoMethodLabel is non-empty', () {
          expect(ContactContentVariants.scheduleADemoMethodLabel, isNotEmpty);
        });

        test('phoneMethodLabel is non-empty', () {
          expect(ContactContentVariants.phoneMethodLabel, isNotEmpty);
        });

        test('locationMethodLabel is non-empty', () {
          expect(ContactContentVariants.locationMethodLabel, isNotEmpty);
        });

        test('linkedinMethodLabel is non-empty', () {
          expect(ContactContentVariants.linkedinMethodLabel, isNotEmpty);
        });

        test('githubMethodLabel is non-empty', () {
          expect(ContactContentVariants.githubMethodLabel, isNotEmpty);
        });

        test('scheduleADemoMethodValue is non-empty', () {
          expect(ContactContentVariants.scheduleADemoMethodValue, isNotEmpty);
        });

        test('linkedinMethodValue is non-empty', () {
          expect(ContactContentVariants.linkedinMethodValue, isNotEmpty);
        });

        test('githubMethodValue is non-empty', () {
          expect(ContactContentVariants.githubMethodValue, isNotEmpty);
        });
      });

      group('content strings', () {
        test('sectionId is non-empty', () {
          expect(ContactContentVariants.sectionId, isNotEmpty);
        });

        test('contentTitle is non-empty', () {
          expect(ContactContentVariants.contentTitle, isNotEmpty);
        });

        test('contentSubtitle is non-empty', () {
          expect(ContactContentVariants.contentSubtitle, isNotEmpty);
        });

        test('contentDescription is non-empty', () {
          expect(ContactContentVariants.contentDescription, isNotEmpty);
        });
      });
    });

    group('current content', () {
      test('current is non-null', () {
        expect(ContactContentVariants.current, isNotNull);
      });

      test('sectionId is contact', () {
        expect(ContactContentVariants.current.sectionId, equals(ContactContentVariants.sectionId));
      });

      test('title is non-empty', () {
        expect(ContactContentVariants.current.title, isNotEmpty);
      });

      test('subtitle is non-empty', () {
        expect(ContactContentVariants.current.subtitle, isNotEmpty);
      });

      test('description is non-empty', () {
        expect(ContactContentVariants.current.description, isNotEmpty);
      });

      test('formSubmitText is non-empty', () {
        expect(ContactContentVariants.current.formSubmitText, isNotEmpty);
      });

      test('formSuccessMessage is non-empty', () {
        expect(ContactContentVariants.current.formSuccessMessage, isNotEmpty);
      });

      test('formErrorMessage is non-empty', () {
        expect(ContactContentVariants.current.formErrorMessage, isNotEmpty);
      });

      test('calendlyUrl is non-empty', () {
        expect(ContactContentVariants.current.calendlyUrl, isNotEmpty);
      });

      test('calendlyCtaText is non-empty', () {
        expect(ContactContentVariants.current.calendlyCtaText, isNotEmpty);
      });
    });

    group('form fields', () {
      late List<dynamic> fields;

      setUp(() {
        fields = ContactContentVariants.current.formFields;
      });

      test('has at least 7 fields', () {
        expect(fields.length, greaterThanOrEqualTo(kContactFormMinFieldCount));
      });

      test('has firstName field', () {
        expect(fields.any((f) => f.name == ContactContentVariants.firstNameFieldName), isTrue);
      });

      test('has lastName field', () {
        expect(fields.any((f) => f.name == ContactContentVariants.lastNameFieldName), isTrue);
      });

      test('has email field', () {
        expect(fields.any((f) => f.name == ContactContentVariants.emailFieldName), isTrue);
      });

      test('has company field', () {
        expect(fields.any((f) => f.name == ContactContentVariants.companyFieldName), isTrue);
      });

      test('has companySize field', () {
        expect(fields.any((f) => f.name == ContactContentVariants.companySizeFieldName), isTrue);
      });

      test('has useCase field', () {
        expect(fields.any((f) => f.name == ContactContentVariants.useCaseFieldName), isTrue);
      });

      test('has message field', () {
        expect(fields.any((f) => f.name == ContactContentVariants.messageFieldName), isTrue);
      });

      test('firstName field is required', () {
        final field = fields.firstWhere((f) => f.name == ContactContentVariants.firstNameFieldName);
        expect(field.required, isTrue);
      });

      test('lastName field is required', () {
        final field = fields.firstWhere((f) => f.name == ContactContentVariants.lastNameFieldName);
        expect(field.required, isTrue);
      });

      test('email field is required', () {
        final field = fields.firstWhere((f) => f.name == ContactContentVariants.emailFieldName);
        expect(field.required, isTrue);
      });

      test('company field is required', () {
        final field = fields.firstWhere((f) => f.name == ContactContentVariants.companyFieldName);
        expect(field.required, isTrue);
      });

      test('email field has type email', () {
        final field = fields.firstWhere((f) => f.name == ContactContentVariants.emailFieldName);
        expect(field.type, equals(ContactContentVariants.emailFieldType));
      });

      test('message field is textarea type', () {
        final field = fields.firstWhere((f) => f.name == ContactContentVariants.messageFieldName);
        expect(field.type, equals(ContactContentVariants.textareaFieldType));
      });

      test('companySize field has options', () {
        final field = fields.firstWhere((f) => f.name == ContactContentVariants.companySizeFieldName);
        expect(field.options, isNotNull);
        expect(field.options, isNotEmpty);
      });

      test('useCase field has options', () {
        final field = fields.firstWhere((f) => f.name == ContactContentVariants.useCaseFieldName);
        expect(field.options, isNotNull);
        expect(field.options, isNotEmpty);
      });

      test('each field has non-empty label', () {
        for (final field in fields) {
          expect(field.label, isNotEmpty,
              reason: 'Field ${field.name} has empty label');
        }
      });

      test('each field has non-empty placeholder', () {
        for (final field in fields) {
          expect(field.placeholder, isNotEmpty,
              reason: 'Field ${field.name} has empty placeholder');
        }
      });

      group('field labels match constants', () {
        test('firstName label matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.firstNameFieldName);
          expect(field.label, equals(ContactContentVariants.firstNameLabel));
        });

        test('lastName label matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.lastNameFieldName);
          expect(field.label, equals(ContactContentVariants.lastNameLabel));
        });

        test('email label matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.emailFieldName);
          expect(field.label, equals(ContactContentVariants.emailLabel));
        });

        test('company label matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.companyFieldName);
          expect(field.label, equals(ContactContentVariants.companyLabel));
        });

        test('companySize label matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.companySizeFieldName);
          expect(field.label, equals(ContactContentVariants.companySizeLabel));
        });

        test('useCase label matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.useCaseFieldName);
          expect(field.label, equals(ContactContentVariants.useCaseLabel));
        });

        test('message label matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.messageFieldName);
          expect(field.label, equals(ContactContentVariants.messageLabel));
        });
      });

      group('field placeholders match constants', () {
        test('firstName placeholder matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.firstNameFieldName);
          expect(field.placeholder, equals(ContactContentVariants.firstNamePlaceholder));
        });

        test('lastName placeholder matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.lastNameFieldName);
          expect(field.placeholder, equals(ContactContentVariants.lastNamePlaceholder));
        });

        test('email placeholder matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.emailFieldName);
          expect(field.placeholder, equals(ContactContentVariants.emailPlaceholder));
        });

        test('company placeholder matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.companyFieldName);
          expect(field.placeholder, equals(ContactContentVariants.companyPlaceholder));
        });

        test('companySize placeholder matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.companySizeFieldName);
          expect(field.placeholder, equals(ContactContentVariants.selectPlaceholder));
        });

        test('useCase placeholder matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.useCaseFieldName);
          expect(field.placeholder, equals(ContactContentVariants.selectPlaceholder));
        });

        test('message placeholder matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.messageFieldName);
          expect(field.placeholder, equals(ContactContentVariants.messagePlaceholder));
        });
      });

      group('field types match constants', () {
        test('firstName field type matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.firstNameFieldName);
          expect(field.type, equals(ContactContentVariants.textFieldType));
        });

        test('lastName field type matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.lastNameFieldName);
          expect(field.type, equals(ContactContentVariants.textFieldType));
        });

        test('email field type matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.emailFieldName);
          expect(field.type, equals(ContactContentVariants.emailFieldType));
        });

        test('company field type matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.companyFieldName);
          expect(field.type, equals(ContactContentVariants.textFieldType));
        });

        test('companySize field type matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.companySizeFieldName);
          expect(field.type, equals(ContactContentVariants.selectFieldType));
        });

        test('useCase field type matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.useCaseFieldName);
          expect(field.type, equals(ContactContentVariants.selectFieldType));
        });

        test('message field type matches constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.messageFieldName);
          expect(field.type, equals(ContactContentVariants.textareaFieldType));
        });
      });

      group('field options match constants', () {
        test('companySize options match constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.companySizeFieldName);
          expect(field.options, equals(ContactContentVariants.companySizeOptions));
        });

        test('useCase options match constant', () {
          final field = fields.firstWhere((f) => f.name == ContactContentVariants.useCaseFieldName);
          expect(field.options, equals(ContactContentVariants.useCaseOptions));
        });
      });
    });

    group('contact methods', () {
      late List<dynamic> methods;

      setUp(() {
        methods = ContactContentVariants.current.contactMethods;
      });

      test('has at least one contact method', () {
        expect(methods, isNotEmpty);
      });

      test('has email method', () {
        expect(methods.any((m) => m.label == ContactContentVariants.emailMethodLabel), isTrue);
      });

      test('has Schedule a Demo method', () {
        expect(methods.any((m) => m.label == ContactContentVariants.scheduleADemoMethodLabel), isTrue);
      });

      test('email method has mailto url', () {
        final email = methods.firstWhere((m) => m.label == ContactContentVariants.emailMethodLabel);
        expect(email.url, startsWith('mailto:'));
      });

      test('email method is primary', () {
        final email = methods.firstWhere((m) => m.label == ContactContentVariants.emailMethodLabel);
        expect(email.isPrimary, isTrue);
      });

      test('calendly method is primary', () {
        final demo = methods.firstWhere((m) => m.label == ContactContentVariants.scheduleADemoMethodLabel);
        expect(demo.isPrimary, isTrue);
      });

      test('each method has non-empty value', () {
        for (final method in methods) {
          expect(method.value, isNotEmpty,
              reason: 'Contact method ${method.label} has empty value');
        }
      });
    });
  });
}
