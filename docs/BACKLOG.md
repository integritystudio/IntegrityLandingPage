# Test Performance Optimization Backlog

All items completed as of 2026-01-31. See commits c1ae24a, 10ab6e4, 2fe6cc1, and 809bab1.

## Completed

- [x] Replace scroll operations with `find.byKey()` (60-80s savings)
- [x] Replace `pumpAndSettle()` with fixed frame pumping (20-40s savings)
- [x] Share widget state via `setUpAll()` (10-20s savings)
- [x] Add `pumpFrames()` helper to test_helpers.dart
- [x] Remove redundant MediaQuery wrapping (2-5s savings)
- [x] Add semantic labels for complex page sections (15-30s savings)
- [x] Move navigation tests to integration suite (8-10s savings)
- [x] Implement performance budget enforcement
- [x] Create fast page pumping helper
- [x] Remove widget type assertions testing implementation details

## Implementation Details

### Semantic Labels (commit 2fe6cc1)
Added `Semantics` widget wrappers with labels to:
- `docs_alerts_page.dart` - `_DocSection` wraps content in Semantics
- `docs_quickstart_page.dart` - `_DocSection` wraps content in Semantics
- `comparison_page.dart` - All section SliverToBoxAdapters wrapped

### Navigation Test Migration (commit 2fe6cc1)
Removed 20+ duplicate navigation tests from landing_page_test.dart. Tests exist in:
- test/integration/landing_navigation_test.dart
- test/integration/mobile_navigation_test.dart

### Performance Budget Enforcement (test/performance/test_performance_budget_test.dart)
Automated checks that fail if tests exceed time budgets:
- Page tests: < 80s
- Unit tests: < 15s

### Fast Page Pumping Helper (test/helpers/page_test_helpers.dart)
Comprehensive helper library with:
- `pumpPageFast()`, `pumpTestableFast()` - Fast pumping without animation waiting
- `findInPage()`, `findDescendantByText()`, `findBySemantics()` - Fast finders
- `FastPumpExtensions` - Extension methods on WidgetTester
- `createSharedPage()`, `pumpSharedPage()` - Setup patterns for setUpAll()

### Widget Type Assertions Removed (commit 809bab1)
Removed redundant `find.byType()` assertions testing implementation details:
- docs_alerts_page_test: Table type check
- comparison_page_test: DataTable type check
- docs_interoperability_page_test: 7 Doc* widget type-only tests
- docs_observability_page_test: entire 'doc components' group (6 tests)
- signup_page_test: IconButton and Wrap type checks

## Final Results

| Optimization | Time Saved | Status |
|--------------|------------|--------|
| Scroll ops → keys | 60-80s | Done |
| pumpAndSettle → pump | 20-40s | Done |
| setUpAll sharing | 10-20s | Done |
| MediaQuery removal | 2-5s | Done |
| Semantic labels | 15-30s | Done |
| Nav test migration | 8-10s | Done |
| Performance budget | - | Done |
| Page pumping helper | - | Done |
| Widget type assertions | - | Done |

**Page test runtime:** ~51s (down from ~144s)
**Target achieved:** ~50-60s ✓
