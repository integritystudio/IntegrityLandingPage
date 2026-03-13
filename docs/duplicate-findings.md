# Widget Duplication Analysis

**Date:** 2026-03-09
**Tool:** `scripts/repomix/find_duplication.sh`
**Parameters:** construct=widget, min_similarity=0.7, min_lines=5

## Summary

| Metric | Value |
|--------|-------|
| Total widgets scanned | 294 |
| Duplicate pairs found | 358 |
| 100% identical pairs | 27 |
| 95-99% similar pairs | 26 |
| 90-94% similar pairs | 33 |
| 80-89% similar pairs | 55 |
| 70-79% similar pairs | 217 |

### Similarity Distribution

```
100% ████████████████████████████  27
 97% ██████████  10
 95% ███████████████  15
 94% ██████████  10
 93% ███████  7
 92% ██████  6
 91% ████████  8
 90% ██  2
 89% █████████████████████████████████  33
 88% ████████  8
 87% █████  5
 86% █████████  9
 85% ███████████  11
 84% █  1
 83% ███  3
 81% ██  2
 80% ██████████  10
 79% ████  4
 78% █████████████████████████████████  33
 77% █████████████████  17
 76% █████████████  13
 75% ███████████████  15
 74% ███████████████  15
 73% ███████████████████  19
 72% █████████████████████████████████  33
 71% ███████████████████████████████████  35
 70% █████████  9
```

---

## All Findings by Similarity Score

### 100% — `_SimpleTable` identical across 6 files

All six copies are byte-for-byte identical. Pure copy-paste duplication.

| File | Widget | Lines |
|------|--------|-------|
| `lib/pages/api_toolkit_page.dart` | `_SimpleTable` | 915-970 |
| `lib/pages/docs_agents_page.dart` | `_SimpleTable` | 718-773 |
| `lib/pages/docs_alerts_page.dart` | `_SimpleTable` | 1185-1240 |
| `lib/pages/docs_api_page.dart` | `_SimpleTable` | 833-888 |
| `lib/pages/docs_quickstart_page.dart` | `_SimpleTable` | 1072-1127 |
| `lib/pages/docs_tracing_page.dart` | `_SimpleTable` | 794-849 |

**Shared equivalent:** `DocTable` (lines 157-221) at 80% similarity — slightly different API surface.

**Recommendation:** Replace all 6 private `_SimpleTable` with `DocTable`, or create a new shared widget if the API differs enough.

---

### 100% — `_CodeBlock` identical across 4 files, 74% in 2 more

| File | Widget | Lines | Similarity to canonical |
|------|--------|-------|------------------------|
| `lib/pages/api_toolkit_page.dart` | `_CodeBlock` | 871-913 | canonical |
| `lib/pages/docs_agents_page.dart` | `_CodeBlock` | 775-817 | 100% |
| `lib/pages/docs_api_page.dart` | `_CodeBlock` | 789-831 | 100% |
| `lib/pages/docs_quickstart_page.dart` | `_CodeBlock` | 1028-1070 | 100% |
| `lib/pages/docs_alerts_page.dart` | `_CodeBlock` | 1157-1183 | 74% |
| `lib/pages/docs_tracing_page.dart` | `_CodeBlock` | 766-792 | 74% |

**Shared equivalent:** `DocCodeBlock` (lines 127-153) at 92% similarity.

**Recommendation:** Replace all with `DocCodeBlock`. The 74% variants (alerts, tracing) are shorter — may need a parameter to handle the difference.

---

### 100% — Callout widgets identical across 5 files

`_InfoCallout`, `_WarningCallout`, `_SuccessCallout` are structurally identical widgets (89-100% similar to each other) differing only by icon and color.

| File | Widgets | Lines |
|------|---------|-------|
| `lib/pages/docs_agents_page.dart` | `_InfoCallout`, `_WarningCallout` | 819-905 |
| `lib/pages/docs_api_page.dart` | `_InfoCallout`, `_WarningCallout` | 927-1002 |
| `lib/pages/docs_quickstart_page.dart` | `_SuccessCallout`, `_InfoCallout`, `_WarningAlert` | 1260-1486 |
| `lib/pages/docs_tracing_page.dart` | `_SuccessCallout`, `_InfoCallout`, `_WarningCallout` | 925-1055 |
| `lib/pages/security_page.dart` | `_WarningAlert`, `_DangerAlert` | 645-709 |

**100% identical pairs:**
- `docs_agents :: _InfoCallout` = `docs_quickstart :: _InfoCallout` = `docs_tracing :: _InfoCallout`
- `docs_quickstart :: _SuccessCallout` = `docs_tracing :: _SuccessCallout`
- `docs_quickstart :: _WarningAlert` = `security_page :: _WarningAlert`

**98% pair:** `docs_agents :: _WarningCallout` ~ `docs_tracing :: _WarningCallout`

**Recommendation:** Create a single `DocCallout` widget with a `CalloutType` enum (`info`, `warning`, `success`, `danger`). Eliminates ~50 duplicate pairs in one refactor.

---

### 97% — `_StatCard` similar across 3 files

| File | Widget | Lines |
|------|--------|-------|
| `lib/pages/api_toolkit_page.dart` | `_StatCard` | 207-247 |
| `lib/pages/docs_api_page.dart` | `_StatCard` | 158-198 |
| `lib/pages/docs_observability_page.dart` | `_StatCard` | 159-199 |

**Related variants:**
- `_StatBadge` (docs_agents_page:192-228) — 71% similar
- `_StatCard` (security_page:500-539) — 81% similar
- `_TimelineCard` (eu_ai_act_page:207-247) — 85% similar

**Recommendation:** Extract a shared `DocStatCard` widget to `doc_components.dart`.

---

### 97% — `_DocSection` similar across 7 files

| File | Widget | Lines | Similarity to agents canonical |
|------|--------|-------|-------------------------------|
| `lib/pages/api_toolkit_page.dart` | `_DocSection` | 817-869 | 97% |
| `lib/pages/docs_agents_page.dart` | `_DocSection` | 541-593 | canonical |
| `lib/pages/docs_alerts_page.dart` | `_DocSection` | 683-740 | 91% |
| `lib/pages/docs_api_page.dart` | `_DocSection` | 659-711 | 97% |
| `lib/pages/docs_quickstart_page.dart` | `_DocSection` | 760-816 | 94% |
| `lib/pages/docs_tracing_page.dart` | `_DocSection` | 535-587 | 97% |
| `lib/pages/security_page.dart` | `_SecurityCard` | 446-498 | 94% |

**Shared equivalent:** `DocSection` (lines 6-62) at 86-88% similarity.

**Recommendation:** Replace all with `DocSection`. The `_SecurityCard` in security_page is structurally the same widget with a different name.

---

### 97% — `_FeatureCard` similar across 4 files

| File | Widget | Lines | Similarity to agents canonical |
|------|--------|-------|-------------------------------|
| `lib/pages/docs_agents_page.dart` | `_FeatureCard` | 629-679 | canonical |
| `lib/pages/docs_alerts_page.dart` | `_FeatureCard` | 776-826 | 97% |
| `lib/pages/docs_quickstart_page.dart` | `_FeatureCard` | 852-902 | 97% |
| `lib/pages/docs_tracing_page.dart` | `_FeatureCard` | 623-678 | 94% |

**Shared equivalent:** `DocFeatureCard` (lines 65-124) at 86-92% similarity.

**Recommendation:** Replace all with `DocFeatureCard`.

---

### 95% — `_BulletList` similar across 6 files

| File | Widget | Lines |
|------|--------|-------|
| `lib/pages/api_toolkit_page.dart` | `_BulletList` | 972-1007 |
| `lib/pages/docs_agents_page.dart` | `_BulletList` | 681-716 |
| `lib/pages/docs_alerts_page.dart` | `_BulletList` | 1242-1277 |
| `lib/pages/docs_api_page.dart` | `_BulletList` | 890-925 |
| `lib/pages/docs_quickstart_page.dart` | `_BulletList` | 1129-1164 |
| `lib/pages/docs_tracing_page.dart` | `_BulletList` | 851-886 |

**Shared equivalent:** `DocBulletList` (lines 224-263) at 85% similarity.

**Related variants:**
- `_CheckList` (docs_quickstart_page:1166-1201) — 77% similar to `_BulletList`, 92% to `_ChecklistSection`
- `_ChecklistSection` (docs_tracing_page:888-923) — 77% similar to `_BulletList`

**Recommendation:** Replace all `_BulletList` with `DocBulletList`. Merge `_CheckList`/`_ChecklistSection` into a `DocBulletList` variant with a `checked` parameter.

---

### 93% — Docs page scaffolds similar across 7 files

All 7 docs pages share a nearly identical top-level page widget structure (Scaffold + AppBar + body layout).

| File | Widget | Lines |
|------|--------|-------|
| `lib/pages/docs_agents_page.dart` | `DocsAgentsPage` | 11-54 |
| `lib/pages/docs_alerts_page.dart` | `DocsAlertsPage` | 11-54 |
| `lib/pages/docs_api_page.dart` | `DocsApiPage` | 11-54 |
| `lib/pages/docs_interoperability_page.dart` | `DocsInteroperabilityPage` | 12-55 |
| `lib/pages/docs_observability_page.dart` | `DocsObservabilityPage` | 12-55 |
| `lib/pages/docs_quickstart_page.dart` | `DocsQuickstartPage` | 12-55 |
| `lib/pages/docs_tracing_page.dart` | `DocsTracingPage` | 11-54 |

**Similarity matrix (all pairs):**
- interop/observability/tracing/alerts pairs: 93%
- All other pairs: 89%

**Recommendation:** Extract a `DocsPageScaffold` that accepts title, sections, and navigation config. Each docs page becomes a thin wrapper that passes content to the scaffold.

---

### 89% — `_NumberedList` similar to shared component

| File | Widget | Lines | vs DocNumberedList |
|------|--------|-------|--------------------|
| `lib/pages/docs_alerts_page.dart` | `_NumberedList` | 1103-1155 | 89% |
| `lib/pages/docs_tracing_page.dart` | `_Timeline` | 692-764 | 73% |

**Shared equivalent:** `DocNumberedList` (lines 266-324).

**Recommendation:** Replace `_NumberedList` with `DocNumberedList`. `_Timeline` may need its own shared widget.

---

### 86% — Feature/content page structures

Larger page widgets with similar layout patterns:

| Pair | Similarity |
|------|-----------|
| `ApiToolkitPage` ~ `EuAiActPage` | 86% |
| `CompliancePage` ~ `EuAiActPage` | 86% |
| `ApiToolkitPage` ~ `CompliancePage` | 83% |
| `CompliancePage` ~ `SecurityPage` | 83% |
| `EuAiActPage` ~ `SecurityPage` | 79% |
| `ApiToolkitPage` ~ `SecurityPage` | 78% |
| Various ~ `HelpCenterPage` | 70-74% |

**Recommendation:** Medium priority. These pages share section layout patterns (hero + stat cards + content sections + CTA). A shared page template could reduce duplication but requires careful design to maintain per-page customization.

---

### 85% — Button variants

| Pair | Similarity |
|------|-----------|
| `AnimatedGradientBorderButton` ~ `GradientButton` | 85% |
| `AnimatedGradientBorderButton` ~ `OutlineButton` | 85% |
| `GradientButton` ~ `OutlineButton` | 85% |
| `AnimatedGradientBorderButton` ~ `AppTextButton` | 75% |
| `GradientButton` ~ `AppTextButton` | 75% |
| `OutlineButton` ~ `AppTextButton` | 75% |

All in `lib/widgets/common/buttons.dart`. These share build method structure but differ in decoration and interaction.

**Recommendation:** Low priority. Buttons intentionally differ in visual behavior. Could extract a shared `_ButtonBase` with a decoration callback, but the current code is readable.

---

### 80% — Hero sections

| Pair | Similarity |
|------|-----------|
| `features :: _HeroSection` ~ `status :: _HeroSection` | 80% |
| `compliance :: _HeroSection` ~ `tracing :: _HeroSection` | 76% |
| `compliance :: _HeroSection` ~ `security :: _HeroSection` | 74% |
| `sources :: _HeroSection` ~ `security :: _HeroSection` | 73% |
| `interop :: _HeroSection` ~ `tracing :: _HeroSection` | 72% |
| `interop :: _HeroSection` ~ `security :: _HeroSection` | 72% |
| `careers :: _CareersHeroSection` ~ `contact :: _ContactHeroSection` | 71% |
| `compliance :: _HeroSection` ~ `interop :: _HeroSection` | 71% |
| `features :: _HeroSection` ~ `security :: _HeroSection` | 71% |

**Recommendation:** Medium priority. Many hero sections follow gradient background + title + subtitle + stat badges pattern. A shared `PageHeroSection` widget with configurable gradient/stats/content slots could consolidate these.

---

### 80% — Trust/social proof widgets

| Pair | Similarity |
|------|-----------|
| `hero_section :: _TrustIndicator` ~ `social_proof_section :: _TrustBadge` | 80% |

**Recommendation:** Low priority. Only one pair, but if trust badges proliferate, extract a shared `TrustBadge` widget.

---

### 78% — Generic page shells

8 pages share an identical Scaffold + SingleChildScrollView + Column pattern.

| File | Widget | Lines |
|------|--------|-------|
| `lib/pages/about_page.dart` | `AboutPage` | 28-40 |
| `lib/pages/careers_page.dart` | `CareersPage` | 12-24 |
| `lib/pages/contact_page.dart` | `ContactPage` | 21-33 |
| `lib/pages/features_page.dart` | `FeaturesPage` | 13-25 |
| `lib/pages/pricing_page.dart` | `PricingPage` | 18-30 |
| `lib/pages/request_failure_page.dart` | `RequestFailurePage` | 13-25 |
| `lib/pages/request_success_page.dart` | `RequestSuccessPage` | 12-24 |
| `lib/pages/status_page.dart` | `StatusPage` | 15-27 |

All pairs are 78% similar. This is a boilerplate pattern — low priority since each page is only 12-13 lines and the structure is Flutter-idiomatic.

**Recommendation:** Low priority. Could extract a `PageShell` widget but the benefit is marginal for such small widgets.

---

### 78% — Cross-page card widgets

Various card-style widgets across different pages share structural similarity:

| Widget A | Widget B | Similarity |
|----------|----------|-----------|
| `sources :: _MethodologyCard` ~ `status :: _TechSection` | | 78% |
| `compliance :: _ResourceLink` ~ `status :: _TechSection` | | 73% |
| `compliance :: _ResourceLink` ~ `sources :: _MethodologyCard` | | 73% |
| `comparison :: _DifferentiatorCard` ~ `status :: _HealthComponentChip` | | 72% |
| `features :: _FeatureItem` ~ `sources :: _MethodologyCard` | | 72% |
| `sources :: _MethodologyCard` ~ `status :: _StatusChip` | | 71% |
| `comparison :: _ChoiceCard` ~ `features :: _QueryCard` | | 70% |
| `eu_ai_act :: _ChecklistItem` ~ `features :: _QueryCard` | | 70% |

**Recommendation:** Low priority. These are semantically different widgets that happen to share Container + Column + Text patterns. Consolidation would reduce clarity.

---

## Prioritized Action Plan

### Phase 1: Docs component consolidation (eliminates ~200 pairs)

1. **Replace all `_SimpleTable` with `DocTable`** — 6 files, 100% identical, zero-risk
2. **Replace all `_CodeBlock` with `DocCodeBlock`** — 6 files, add parameter for short variant
3. **Create `DocCallout` with type enum** — replaces `_InfoCallout`, `_WarningCallout`, `_SuccessCallout`, `_WarningAlert`, `_DangerAlert` across 5 files
4. **Replace all `_BulletList` with `DocBulletList`** — 6 files, add `checked` parameter for checklist variants
5. **Replace all `_DocSection` with `DocSection`** — 7 files including security_page `_SecurityCard`
6. **Replace all `_FeatureCard` with `DocFeatureCard`** — 4 files
7. **Extract `DocStatCard`** — new shared widget, replaces `_StatCard` in 3-4 files
8. **Replace `_NumberedList` with `DocNumberedList`** — 1 file

### Phase 2: Docs page scaffold (eliminates ~21 pairs)

9. **Extract `DocsPageScaffold`** — shared scaffold for all 7 docs pages

### Phase 3: Cross-page patterns (eliminates ~30 pairs)

10. **Extract `PageHeroSection`** — shared hero for compliance/security/features/status/tracing pages
11. **Evaluate feature page template** — shared layout for api_toolkit/compliance/eu_ai_act/security

### Phase 4: Low priority (eliminates ~10 pairs)

12. **Button base extraction** — optional refactor of `buttons.dart`
13. **Trust badge consolidation** — merge `_TrustIndicator` and `_TrustBadge`
14. **Page shell extraction** — optional for 8 generic page scaffolds

---

## Estimated Impact

| Phase | Pairs Eliminated | Files Modified | Risk |
|-------|-----------------|----------------|------|
| Phase 1 | ~200 | ~10 page files + doc_components.dart | Low (shared components exist) |
| Phase 2 | ~21 | 7 docs pages + 1 new scaffold | Medium (new abstraction) |
| Phase 3 | ~30 | ~10 pages | Medium (new abstraction) |
| Phase 4 | ~10 | ~4 files | Low (cosmetic) |
| **Total** | **~261 of 358** | | |

---

## Raw Data

### All 100% Identical Pairs (27 total)

```
100%: api_toolkit_page :: _CodeBlock (871-913) = docs_agents_page :: _CodeBlock (775-817)
100%: api_toolkit_page :: _CodeBlock (871-913) = docs_api_page :: _CodeBlock (789-831)
100%: api_toolkit_page :: _CodeBlock (871-913) = docs_quickstart_page :: _CodeBlock (1028-1070)
100%: api_toolkit_page :: _SimpleTable (915-970) = docs_agents_page :: _SimpleTable (718-773)
100%: api_toolkit_page :: _SimpleTable (915-970) = docs_alerts_page :: _SimpleTable (1185-1240)
100%: api_toolkit_page :: _SimpleTable (915-970) = docs_api_page :: _SimpleTable (833-888)
100%: api_toolkit_page :: _SimpleTable (915-970) = docs_quickstart_page :: _SimpleTable (1072-1127)
100%: api_toolkit_page :: _SimpleTable (915-970) = docs_tracing_page :: _SimpleTable (794-849)
100%: docs_agents_page :: _CodeBlock (775-817) = docs_api_page :: _CodeBlock (789-831)
100%: docs_agents_page :: _CodeBlock (775-817) = docs_quickstart_page :: _CodeBlock (1028-1070)
100%: docs_agents_page :: _InfoCallout (819-861) = docs_quickstart_page :: _InfoCallout (1304-1346)
100%: docs_agents_page :: _InfoCallout (819-861) = docs_tracing_page :: _InfoCallout (969-1011)
100%: docs_agents_page :: _SimpleTable (718-773) = docs_alerts_page :: _SimpleTable (1185-1240)
100%: docs_agents_page :: _SimpleTable (718-773) = docs_api_page :: _SimpleTable (833-888)
100%: docs_agents_page :: _SimpleTable (718-773) = docs_quickstart_page :: _SimpleTable (1072-1127)
100%: docs_agents_page :: _SimpleTable (718-773) = docs_tracing_page :: _SimpleTable (794-849)
100%: docs_alerts_page :: _CodeBlock (1157-1183) = docs_tracing_page :: _CodeBlock (766-792)
100%: docs_alerts_page :: _SimpleTable (1185-1240) = docs_api_page :: _SimpleTable (833-888)
100%: docs_alerts_page :: _SimpleTable (1185-1240) = docs_quickstart_page :: _SimpleTable (1072-1127)
100%: docs_alerts_page :: _SimpleTable (1185-1240) = docs_tracing_page :: _SimpleTable (794-849)
100%: docs_api_page :: _CodeBlock (789-831) = docs_quickstart_page :: _CodeBlock (1028-1070)
100%: docs_api_page :: _SimpleTable (833-888) = docs_quickstart_page :: _SimpleTable (1072-1127)
100%: docs_api_page :: _SimpleTable (833-888) = docs_tracing_page :: _SimpleTable (794-849)
100%: docs_quickstart_page :: _InfoCallout (1304-1346) = docs_tracing_page :: _InfoCallout (969-1011)
100%: docs_quickstart_page :: _SimpleTable (1072-1127) = docs_tracing_page :: _SimpleTable (794-849)
100%: docs_quickstart_page :: _SuccessCallout (1260-1302) = docs_tracing_page :: _SuccessCallout (925-967)
100%: docs_quickstart_page :: _WarningAlert (1455-1486) = security_page :: _WarningAlert (645-676)
```

### All 90%+ Pairs (86 total)

```
97%: api_toolkit_page :: _StatCard (207-247) ~ docs_api_page :: _StatCard (158-198)
97%: api_toolkit_page :: _StatCard (207-247) ~ docs_observability_page :: _StatCard (159-199)
97%: api_toolkit_page :: _DocSection (817-869) ~ docs_agents_page :: _DocSection (541-593)
94%: api_toolkit_page :: _DocSection (817-869) ~ docs_api_page :: _DocSection (659-711)
91%: api_toolkit_page :: _DocSection (817-869) ~ docs_quickstart_page :: _DocSection (760-816)
94%: api_toolkit_page :: _DocSection (817-869) ~ docs_tracing_page :: _DocSection (535-587)
91%: api_toolkit_page :: _DocSection (817-869) ~ security_page :: _SecurityCard (446-498)
95%: api_toolkit_page :: _BulletList (972-1007) ~ docs_agents_page :: _BulletList (681-716)
95%: api_toolkit_page :: _BulletList (972-1007) ~ docs_alerts_page :: _BulletList (1242-1277)
95%: api_toolkit_page :: _BulletList (972-1007) ~ docs_api_page :: _BulletList (890-925)
95%: api_toolkit_page :: _BulletList (972-1007) ~ docs_quickstart_page :: _BulletList (1129-1164)
95%: api_toolkit_page :: _BulletList (972-1007) ~ docs_tracing_page :: _BulletList (851-886)
93%: docs_agents_page :: DocsAgentsPage (11-54) ~ docs_observability_page :: DocsObservabilityPage (12-55)
91%: docs_agents_page :: _DocSection (541-593) ~ docs_alerts_page :: _DocSection (683-740)
97%: docs_agents_page :: _DocSection (541-593) ~ docs_api_page :: _DocSection (659-711)
94%: docs_agents_page :: _DocSection (541-593) ~ docs_quickstart_page :: _DocSection (760-816)
97%: docs_agents_page :: _DocSection (541-593) ~ docs_tracing_page :: _DocSection (535-587)
94%: docs_agents_page :: _DocSection (541-593) ~ security_page :: _SecurityCard (446-498)
97%: docs_agents_page :: _FeatureCard (629-679) ~ docs_alerts_page :: _FeatureCard (776-826)
97%: docs_agents_page :: _FeatureCard (629-679) ~ docs_quickstart_page :: _FeatureCard (852-902)
94%: docs_agents_page :: _FeatureCard (629-679) ~ docs_tracing_page :: _FeatureCard (623-678)
95%: docs_agents_page :: _BulletList (681-716) ~ docs_alerts_page :: _BulletList (1242-1277)
95%: docs_agents_page :: _BulletList (681-716) ~ docs_api_page :: _BulletList (890-925)
95%: docs_agents_page :: _BulletList (681-716) ~ docs_quickstart_page :: _BulletList (1129-1164)
95%: docs_agents_page :: _BulletList (681-716) ~ docs_tracing_page :: _BulletList (851-886)
94%: docs_agents_page :: _InfoCallout (819-861) ~ docs_api_page :: _InfoCallout (927-969)
94%: docs_agents_page :: _InfoCallout (819-861) ~ docs_quickstart_page :: _InfoCallout (1304-1346)
94%: docs_agents_page :: _InfoCallout (819-861) ~ docs_tracing_page :: _InfoCallout (969-1011)
98%: docs_agents_page :: _WarningCallout (863-905) ~ docs_tracing_page :: _WarningCallout (1013-1055)
90%: docs_agents_page :: _WarningCallout (863-905) ~ docs_quickstart_page :: _SuccessCallout (1260-1302)
90%: docs_agents_page :: _WarningCallout (863-905) ~ docs_tracing_page :: _SuccessCallout (925-967)
93%: docs_alerts_page :: DocsAlertsPage (11-54) ~ docs_interoperability_page :: DocsInteroperabilityPage (12-55)
93%: docs_alerts_page :: DocsAlertsPage (11-54) ~ docs_observability_page :: DocsObservabilityPage (12-55)
93%: docs_alerts_page :: DocsAlertsPage (11-54) ~ docs_tracing_page :: DocsTracingPage (11-54)
94%: docs_alerts_page :: _DocSection (683-740) ~ docs_quickstart_page :: _DocSection (760-816)
97%: docs_alerts_page :: _FeatureCard (776-826) ~ docs_quickstart_page :: _FeatureCard (852-902)
91%: docs_alerts_page :: _FeatureCard (776-826) ~ docs_tracing_page :: _FeatureCard (623-678)
92%: docs_alerts_page :: _CodeBlock (1157-1183) ~ doc_components.dart :: DocCodeBlock (127-153)
95%: docs_alerts_page :: _BulletList (1242-1277) ~ docs_api_page :: _BulletList (890-925)
95%: docs_alerts_page :: _BulletList (1242-1277) ~ docs_quickstart_page :: _BulletList (1129-1164)
95%: docs_alerts_page :: _BulletList (1242-1277) ~ docs_tracing_page :: _BulletList (851-886)
97%: docs_api_page :: _StatCard (158-198) ~ docs_observability_page :: _StatCard (159-199)
91%: docs_api_page :: _DocSection (659-711) ~ docs_quickstart_page :: _DocSection (760-816)
94%: docs_api_page :: _DocSection (659-711) ~ docs_tracing_page :: _DocSection (535-587)
91%: docs_api_page :: _DocSection (659-711) ~ security_page :: _SecurityCard (446-498)
95%: docs_api_page :: _BulletList (890-925) ~ docs_quickstart_page :: _BulletList (1129-1164)
95%: docs_api_page :: _BulletList (890-925) ~ docs_tracing_page :: _BulletList (851-886)
94%: docs_api_page :: _InfoCallout (927-969) ~ docs_quickstart_page :: _InfoCallout (1304-1346)
94%: docs_api_page :: _InfoCallout (927-969) ~ docs_tracing_page :: _InfoCallout (969-1011)
93%: docs_interoperability_page :: DocsInteroperabilityPage (12-55) ~ docs_observability_page :: DocsObservabilityPage (12-55)
93%: docs_interoperability_page :: DocsInteroperabilityPage (12-55) ~ docs_tracing_page :: DocsTracingPage (11-54)
93%: docs_observability_page :: DocsObservabilityPage (12-55) ~ docs_tracing_page :: DocsTracingPage (11-54)
91%: docs_quickstart_page :: _DocSection (760-816) ~ docs_tracing_page :: _DocSection (535-587)
91%: docs_quickstart_page :: _FeatureCard (852-902) ~ docs_tracing_page :: _FeatureCard (623-678)
95%: docs_quickstart_page :: _BulletList (1129-1164) ~ docs_tracing_page :: _BulletList (851-886)
92%: docs_quickstart_page :: _CheckList (1166-1201) ~ docs_tracing_page :: _ChecklistSection (888-923)
92%: docs_quickstart_page :: _WarningAlert (1455-1486) ~ security_page :: _DangerAlert (678-709)
97%: docs_tracing_page :: _DocSection (535-587) ~ security_page :: _SecurityCard (446-498)
92%: docs_tracing_page :: _FeatureCard (623-678) ~ doc_components.dart :: DocFeatureCard (65-124)
92%: docs_tracing_page :: _CodeBlock (766-792) ~ doc_components.dart :: DocCodeBlock (127-153)
92%: security_page :: _WarningAlert (645-676) ~ security_page :: _DangerAlert (678-709)
```

---

## Files Involved (by duplicate pair count)

| File | Pairs Involved |
|------|---------------|
| `lib/pages/docs_agents_page.dart` | 78 |
| `lib/pages/docs_quickstart_page.dart` | 76 |
| `lib/pages/docs_alerts_page.dart` | 72 |
| `lib/pages/docs_api_page.dart` | 64 |
| `lib/pages/docs_tracing_page.dart` | 62 |
| `lib/pages/api_toolkit_page.dart` | 46 |
| `lib/pages/security_page.dart` | 38 |
| `lib/pages/status_page.dart` | 26 |
| `lib/pages/docs_observability_page.dart` | 14 |
| `lib/pages/docs_interoperability_page.dart` | 12 |
| `lib/pages/features_page.dart` | 18 |
| `lib/pages/sources_page.dart` | 14 |
| `lib/widgets/docs/doc_components.dart` | 18 |
| `lib/pages/compliance_page.dart` | 10 |
| `lib/pages/eu_ai_act_page.dart` | 8 |
| Other pages (8 generic shells) | ~28 each at 78% |
| `lib/widgets/common/buttons.dart` | 6 |
| `lib/widgets/sections/hero_section.dart` | 1 |
| `lib/widgets/sections/social_proof_section.dart` | 1 |
