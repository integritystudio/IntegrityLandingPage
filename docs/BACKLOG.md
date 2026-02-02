# Test Performance Optimization Backlog

All items completed as of 2026-01-31.

## Completed

- [x] Replace scroll operations with `find.byKey()` (60-80s savings) - `10ab6e4`
- [x] Replace `pumpAndSettle()` with fixed frame pumping (20-40s savings) - `10ab6e4`
- [x] Share widget state via `setUpAll()` (10-20s savings) - `10ab6e4`
- [x] Add `pumpFrames()` helper to test_helpers.dart - `10ab6e4`
- [x] Remove redundant MediaQuery wrapping (2-5s savings) - `1658132`
- [x] Add semantic labels for complex page sections (15-30s savings) - `2fe6cc1`
- [x] Move navigation tests to integration suite (8-10s savings) - `2fe6cc1`
- [x] Implement performance budget enforcement - `2fe6cc1`
- [x] Create fast page pumping helper - `10ab6e4`
- [x] Remove widget type assertions testing implementation details - `809bab1`

## Commits

| Commit | Description |
|--------|-------------|
| `10ab6e4` | perf(tests): optimize page test runtime with key-based lookups |
| `1658132` | perf(tests): remove redundant MediaQuery wrappers from page tests |
| `2fe6cc1` | perf(tests): add semantic labels and remove duplicate nav tests |
| `809bab1` | refactor(tests): remove widget type assertions testing implementation details |
| `08f30f2` | refactor(test): consolidate content_loader_test.dart |

## Implementation Details

### Semantic Labels (`2fe6cc1`)
Added `Semantics` widget wrappers with labels to:
- `docs_alerts_page.dart` - `_DocSection` wraps content in Semantics
- `docs_quickstart_page.dart` - `_DocSection` wraps content in Semantics
- `comparison_page.dart` - All section SliverToBoxAdapters wrapped

### Navigation Test Migration (`2fe6cc1`)
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

### Widget Type Assertions Removed (`809bab1`)
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
