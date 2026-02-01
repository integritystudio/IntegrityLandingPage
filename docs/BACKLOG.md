# Test Performance Optimization Backlog

Remaining items from code review (2026-01-31). See commits c1ae24a and 10ab6e4 for completed work.

## Completed

- [x] Replace scroll operations with `find.byKey()` (60-80s savings)
- [x] Replace `pumpAndSettle()` with fixed frame pumping (20-40s savings)
- [x] Share widget state via `setUpAll()` (10-20s savings)
- [x] Add `pumpFrames()` helper to test_helpers.dart
- [x] Remove redundant MediaQuery wrapping (2-5s savings)

## Remaining Optimizations

### Medium Effort - Completed

#### Add semantic labels for complex page sections (15-30s savings) ✓
Enables direct widget access without scrolling or tall viewports.

**Completed:** Added `Semantics` widget wrappers with labels to:
- `docs_alerts_page.dart` - `_DocSection` now wraps content in Semantics with title-based label
- `docs_quickstart_page.dart` - `_DocSection` now wraps content in Semantics with title-based label
- `comparison_page.dart` - All section SliverToBoxAdapters wrapped with Semantics labels

**Usage in tests:**
```dart
expect(find.bySemanticsLabel('Alert Types'), findsOneWidget);
```

#### Move navigation tests to integration suite ✓
Navigation tests removed from landing_page_test.dart (lines 414-779).

**Completed:** Removed 20+ duplicate navigation tests that existed in:
- test/integration/landing_navigation_test.dart
- test/integration/mobile_navigation_test.dart

**Impact:** Reduced landing_page_test.dart from ~60 tests to ~40 tests, cleaner separation of concerns

### Infrastructure

#### Implement performance budget enforcement
Create automated check that fails if page tests exceed time budget.

**File:** test/performance/test_performance_budget.dart

```dart
test('page tests complete within performance budget', () async {
  final result = await Process.run('flutter', ['test', 'test/pages/']);
  final output = result.stdout.toString();

  final match = RegExp(r'(\d+) tests passed.*in ([\d.]+)s').firstMatch(output);
  final runtime = double.parse(match!.group(2)!);

  // Budget: page tests should complete in < 80s
  expect(runtime, lessThan(80.0),
    reason: 'Page tests exceeded performance budget of 80s');
});
```

#### Create fast page pumping helper
Extend test helpers with standardized fast pumping pattern.

**File:** test/helpers/page_test_helpers.dart

```dart
/// Fast page pumping without animation waiting
Future<void> pumpPageFast(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(page);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Find widget in page without scrolling
Finder findInPage(String keyName) => find.byKey(Key(keyName));

/// Find descendant without scrolling
Finder findDescendantByText(Finder parent, String text) {
  return find.descendant(of: parent, matching: find.text(text));
}
```

## Anti-Patterns to Address

### Testing implementation details instead of behavior
Some tests verify widget types exist rather than user-facing behavior.

**Example:** docs_alerts_page_test.dart lines 620-633
```dart
// Tests that Table widget exists - implementation detail
expect(find.byType(Table), findsWidgets);
```

**Better:** Test that metrics information is accessible to users

### Duplicate test coverage across layers
Navigation tests appear in both page tests AND integration tests.

**Action:** Audit for duplicates, remove from page tests

## Estimated Impact

| Optimization | Time Saved | Effort | Status |
|--------------|------------|--------|--------|
| Scroll ops → keys | 60-80s | Medium | Done |
| pumpAndSettle → pump | 20-40s | Low | Done |
| setUpAll sharing | 10-20s | Low | Done |
| MediaQuery removal | 2-5s | Low | Done |
| Semantic labels | 15-30s | Medium | Done |
| Nav test migration | 8-10s | Medium | Done |
| Performance budget | - | Low | Backlog |

**Current page test runtime:** ~51s (down from ~144s)
**Target achieved:** ~50-60s
