import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/config/content.dart';

void main() {

  group('AboutContent', () {
    group('current content', () {
      test('has required fields', () {
        final content = AppContent.about;

        expect(content.sectionId, equals('about'));
        expect(content.title, isNotEmpty);
        expect(content.subtitle, isNotEmpty);
      });

      test('has mission statement', () {
        final content = AppContent.about;

        expect(content.missionStatement, isNotEmpty);
        expect(content.missionStatement.length, greaterThan(50));
      });

      test('has vision statement', () {
        final content = AppContent.about;

        expect(content.visionStatement, isNotEmpty);
        expect(content.visionStatement.length, greaterThan(50));
      });

      test('has company story', () {
        final content = AppContent.about;

        expect(content.story, isNotEmpty);
        expect(content.story.length, greaterThan(200));
        // Story should have multiple paragraphs
        expect(content.story.contains('\n\n'), isTrue);
      });

      test('has 4 company values', () {
        final content = AppContent.about;

        expect(content.values.length, equals(4));
      });

      test('value titles cover core principles', () {
        final content = AppContent.about;
        final valueTitles = content.values.map((v) => v.title).toList();

        expect(valueTitles, contains('Transparency'));
        expect(valueTitles, contains('Trust'));
        expect(valueTitles, contains('Developer-First'));
        expect(valueTitles, contains('Compliance by Design'));
      });

      test('each value has required fields', () {
        final content = AppContent.about;

        for (final value in content.values) {
          expect(value.icon, isNotNull);
          expect(value.title, isNotEmpty);
          expect(value.description, isNotEmpty);
          expect(value.description.length, greaterThan(50));
        }
      });

      test('has at least one team member', () {
        final content = AppContent.about;

        expect(content.team, isNotEmpty);
      });

      test('team members have required fields', () {
        final content = AppContent.about;

        for (final member in content.team) {
          expect(member.name, isNotEmpty);
          expect(member.role, isNotEmpty);
          expect(member.bio, isNotEmpty);
        }
      });

      test('has location information', () {
        final content = AppContent.about;

        expect(content.locationCity, isNotEmpty);
        expect(content.locationRegion, isNotEmpty);
        expect(content.locationCity, equals('Austin'));
        expect(content.locationRegion, equals('Texas'));
      });

      test('has founding year', () {
        final content = AppContent.about;

        expect(content.foundedYear, isNotEmpty);
        expect(content.foundedYear, equals('2025'));
      });
    });

    group('TeamMemberContent', () {
      test('creates with all required fields', () {
        const member = TeamMemberContent(
          name: 'John Doe',
          role: 'CTO',
          bio: 'Experienced tech leader',
          avatarAsset: 'assets/john.png',
          linkedInUrl: 'https://linkedin.com/in/johndoe',
          xUrl: 'https://x.com/johndoe',
          githubUrl: 'https://github.com/johndoe',
        );

        expect(member.name, equals('John Doe'));
        expect(member.role, equals('CTO'));
        expect(member.bio, equals('Experienced tech leader'));
        expect(member.avatarAsset, equals('assets/john.png'));
        expect(member.linkedInUrl, isNotNull);
        expect(member.xUrl, isNotNull);
        expect(member.githubUrl, isNotNull);
      });

      test('social links are optional', () {
        const member = TeamMemberContent(
          name: 'Jane Doe',
          role: 'Engineer',
          bio: 'Software engineer',
        );

        expect(member.avatarAsset, isNull);
        expect(member.linkedInUrl, isNull);
        expect(member.xUrl, isNull);
        expect(member.githubUrl, isNull);
      });
    });

    group('CompanyValueContent', () {
      test('creates with all required fields', () {
        const value = CompanyValueContent(
          icon: LucideIcons.shield,
          title: 'Security',
          description: 'We prioritize security in everything we build.',
        );

        expect(value.icon, equals(LucideIcons.shield));
        expect(value.title, equals('Security'));
        expect(value.description, isNotEmpty);
      });
    });

    group('AboutContent constructor', () {
      test('creates with all required fields', () {
        const content = AboutContent(
          sectionId: 'test-about',
          title: 'Test About',
          subtitle: 'Test Subtitle',
          missionStatement: 'Test mission',
          visionStatement: 'Test vision',
          story: 'Test story',
          values: [],
          team: [],
          locationCity: 'Test City',
          locationRegion: 'Test State',
          foundedYear: '2020',
        );

        expect(content.sectionId, equals('test-about'));
        expect(content.title, equals('Test About'));
        expect(content.missionStatement, equals('Test mission'));
        expect(content.visionStatement, equals('Test vision'));
        expect(content.story, equals('Test story'));
        expect(content.values, isEmpty);
        expect(content.team, isEmpty);
        expect(content.locationCity, equals('Test City'));
        expect(content.foundedYear, equals('2020'));
      });
    });

    group('content quality', () {
      test('mission mentions observability', () {
        final content = AppContent.about;

        expect(
          content.missionStatement.toLowerCase(),
          contains('observability'),
        );
      });

      test('vision mentions enterprise', () {
        final content = AppContent.about;

        expect(
          content.visionStatement.toLowerCase(),
          contains('enterprise'),
        );
      });

      test('story mentions AI observability context', () {
        final content = AppContent.about;

        expect(content.story.toLowerCase(), contains('llm'));
        expect(content.story.toLowerCase(), contains('observability'));
      });

      test('at least one team member has social links', () {
        final content = AppContent.about;
        final membersWithLinkedIn =
            content.team.where((m) => m.linkedInUrl != null).toList();

        expect(membersWithLinkedIn, isNotEmpty);
      });
    });
  });
}
