import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/models/dashboard_models.dart';
import 'package:integrity_studio_ai/pages/dashboard_page.dart';

void main() {
  group('pickActiveOrg', () {
    const orgs = [
      OrgSummary(orgId: 'org-1', name: 'One'),
      OrgSummary(orgId: 'org-2', name: 'Two'),
    ];

    test('selects the preferred org when the list contains it', () {
      expect(pickActiveOrg(orgs, 'org-2')?.orgId, 'org-2');
    });

    test('falls back to the first org when the preferred one is gone', () {
      expect(pickActiveOrg(orgs, 'org-9')?.orgId, 'org-1');
    });

    test('selects the first org when no preference is given', () {
      expect(pickActiveOrg(orgs, null)?.orgId, 'org-1');
    });

    test('returns null for an empty list', () {
      expect(pickActiveOrg(const [], 'org-1'), isNull);
    });
  });
}
