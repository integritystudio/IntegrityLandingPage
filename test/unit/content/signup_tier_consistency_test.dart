// Regression tests: every signup link must target a tier that has content in
// content.yaml, and every pricing tier must have matching signup content.
//
// Background: the hero, CTA, and services CTAs linked to /signup?tier=Team.
// content.yaml only defines starter/growth/enterprise, and ContentLoader
// returns '' for missing keys, so the signup page rendered a blank heading,
// blank description, no feature list, and an unlabeled submit button.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content/constants.dart';
import 'package:yaml/yaml.dart';

/// Matches a literal tier value in a link, e.g. `tier=Growth`.
/// Interpolated values (`tier=$tier`) are normalized at the router instead.
final _tierLinkPattern = RegExp(r'tier=([A-Za-z]\w*)');

void main() {
  late YamlMap content;

  setUpAll(() {
    final file = File('content.yaml');
    expect(file.existsSync(), isTrue,
        reason: 'content.yaml must exist at project root');
    content = loadYaml(file.readAsStringSync()) as YamlMap;
  });

  group('SignupTiers.normalize', () {
    test('returns canonical keys unchanged', () {
      for (final tier in SignupTiers.all) {
        expect(SignupTiers.normalize(tier), equals(tier));
      }
    });

    test('lowercases pricing display names', () {
      expect(SignupTiers.normalize('Growth'), equals(SignupTiers.growth));
      expect(SignupTiers.normalize('ENTERPRISE'),
          equals(SignupTiers.enterprise));
    });

    test('falls back to the default tier for unknown values', () {
      expect(SignupTiers.normalize('Team'), equals(SignupTiers.defaultTier));
      expect(SignupTiers.normalize(''), equals(SignupTiers.defaultTier));
      expect(SignupTiers.normalize(null), equals(SignupTiers.defaultTier));
    });
  });

  group('signup tier content', () {
    test('every canonical tier has complete signup content', () {
      final tiers = (content['signup'] as YamlMap)['tiers'] as YamlMap;

      for (final tier in SignupTiers.all) {
        final tierContent = tiers[tier] as YamlMap?;
        expect(tierContent, isNotNull,
            reason: 'signup.tiers.$tier is missing from content.yaml');
        for (final field in ['heading', 'description', 'cta']) {
          expect(tierContent![field], isNotNull,
              reason: 'signup.tiers.$tier.$field is missing from content.yaml');
          expect(tierContent[field].toString(), isNotEmpty,
              reason: 'signup.tiers.$tier.$field is empty in content.yaml');
        }
        expect(tierContent!['features'], isA<YamlList>(),
            reason: 'signup.tiers.$tier.features must be a list');
      }
    });

    test('every pricing tier maps to a tier with signup content', () {
      final pricingTiers = (content['pricing'] as YamlMap)['tiers'] as YamlList;
      final signupTiers = (content['signup'] as YamlMap)['tiers'] as YamlMap;

      for (final tier in pricingTiers) {
        final name = (tier as YamlMap)['name'].toString();
        expect(signupTiers[name.toLowerCase()], isNotNull,
            reason: 'Pricing tier "$name" has no signup.tiers.'
                '${name.toLowerCase()} entry, so selecting it would render an '
                'empty signup page');
      }
    });
  });

  group('signup links', () {
    test('Routes.signupGrowth targets a canonical tier', () {
      final tier = Uri.parse(Routes.signupGrowth).queryParameters['tier'];
      expect(SignupTiers.all, contains(tier));
    });

    test('no source file links to a non-canonical tier', () {
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        for (final match
            in _tierLinkPattern.allMatches(entity.readAsStringSync())) {
          final tier = match.group(1)!;
          if (!SignupTiers.all.contains(tier.toLowerCase())) {
            offenders.add('${entity.path}: tier=$tier');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'These links target a tier with no signup content, which '
              'renders an empty signup page: ${offenders.join(', ')}');
    });
  });
}
