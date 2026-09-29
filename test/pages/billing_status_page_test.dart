import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/billing_status_page.dart';

void main() {
  // Instants at midday UTC fall on the same calendar date from UTC-11 to UTC+11, so
  // these hold in whatever zone the suite runs.
  group('formatRenewalDate', () {
    for (final (instant, expected) in [
      (DateTime.utc(2026, 10, 15, 12), 'October 15, 2026'),
      (DateTime.utc(2027, 1, 1, 12), 'January 1, 2027'),
      (DateTime.utc(2026, 12, 31, 12), 'December 31, 2026'),
    ]) {
      test('formats $instant as "$expected"', () {
        expect(formatRenewalDate(instant), expected);
      });
    }
  });
}
