# Widget Duplication Analysis

**Date:** 2026-03-12
**Tool:** `scripts/find_duplication.sh`
**Parameters:** construct=widget, min_similarity=0.7, min_lines=5

## Summary

| Metric | Value |
|--------|-------|
| Total widgets scanned | 249 |
| Duplicate pairs found | 86 |
| 90%+ similar pairs | 1 |
| 80-89% similar pairs | 7 |
| 70-79% similar pairs | 78 |

### Similarity Distribution

```
92% █  1
86% ██  2
85% ███  3
81% █  1
80% █  1
79% ██  2
78% ██████████████████████████████████████████  42
75% ███  3
74% ████  4
73% ██████  6
72% ████  4
71% █████  5
70% ████████████  12
```

### Progress Since Last Analysis (2026-03-09)

| Metric | 2026-03-09 | 2026-03-12 | Change |
|--------|-----------|-----------|--------|
| Widgets scanned | 294 | 249 | -45 |
| Duplicate pairs | 358 | 86 | -272 (76% reduction) |
| 100% identical | 27 | 0 | -27 |
| 90%+ pairs | 86 | 1 | -85 |

Phase 1 (docs component consolidation) is effectively complete — all 100% identical pairs and nearly all 90%+ pairs have been eliminated.

---

## All Findings by Similarity Score

### 92% — `_WarningAlert` / `_DangerAlert` in security_page

| File | Widget | Lines |
|------|--------|-------|
| `lib/pages/security_page.dart` | `_WarningAlert` | 515-546 |
| `lib/pages/security_page.dart` | `_DangerAlert` | 548-579 |

**Recommendation:** Replace both with a shared `DocCallout` or parameterized alert widget differing only by color/icon.

---

### 86% — Docs page scaffolds

| Pair | Similarity |
|------|-----------|
| `DocsAgentsPage` ~ `DocsObservabilityPage` | 86% |
| `DocsInteroperabilityPage` ~ `DocsObservabilityPage` | 86% |
| `DocsObservabilityPage` ~ `DocsTracingPage` | 86% |

All docs pages share a nearly identical top-level scaffold structure.

**Recommendation:** Extract a `DocsPageScaffold` that accepts title, sections, and navigation config.

---

### 85% — Button variants

| Pair | Similarity |
|------|-----------|
| `AnimatedGradientBorderButton` ~ `GradientButton` | 85% |
| `AnimatedGradientBorderButton` ~ `OutlineButton` | 85% |
| `GradientButton` ~ `OutlineButton` | 85% |

All in `lib/widgets/common/buttons.dart`. These share build method structure but differ in decoration and interaction.

**Recommendation:** Low priority. Could extract a shared `_ButtonBase` with a decoration callback, but the current code is readable.

---

### 81% — `DocStatCard` ~ `_TimelineCard`

| File | Widget | Lines |
|------|--------|-------|
| `lib/pages/eu_ai_act_page.dart` | `_TimelineCard` | 125-165 |
| `lib/widgets/docs/doc_components.dart` | `DocStatCard` | 300-343 |

**Recommendation:** Low priority. Structurally similar card layout but semantically different.

---

### 80% — Hero sections and trust badges

| Pair | Similarity |
|------|-----------|
| `features :: _HeroSection` ~ `status :: _HeroSection` | 80% |
| `hero_section :: _TrustIndicator` ~ `social_proof_section :: _TrustBadge` | 80% |

**Recommendation:** Medium priority. Hero sections follow gradient + title + subtitle + stats pattern. A shared `PageHeroSection` could consolidate these.

---

### 79% — Docs page scaffold pairs

| Pair | Similarity |
|------|-----------|
| `DocsAgentsPage` ~ `DocsApiPage` | 79% |
| `DocsAgentsPage` ~ `DocsInteroperabilityPage` | 79% |
| `DocsAgentsPage` ~ `DocsQuickstartPage` | 79% |
| `DocsAgentsPage` ~ `DocsTracingPage` | 79% |
| `DocsApiPage` ~ `DocsInteroperabilityPage` | 79% |
| `DocsApiPage` ~ `DocsObservabilityPage` | 79% |
| `DocsApiPage` ~ `DocsQuickstartPage` | 79% |
| `DocsApiPage` ~ `DocsTracingPage` | 79% |
| `DocsInteroperabilityPage` ~ `DocsQuickstartPage` | 79% |
| `DocsObservabilityPage` ~ `DocsQuickstartPage` | 79% |
| `DocsQuickstartPage` ~ `DocsTracingPage` | 79% |

Part of the same docs page scaffold pattern as the 86% pairs above.

---

### 78% — Generic page shells

8 pages share an identical Scaffold + SingleChildScrollView + Column pattern:

| File | Widget | Lines |
|------|--------|-------|
| `lib/pages/about_page.dart` | `AboutPage` | 28-40 |
| `lib/pages/careers_page.dart` | `CareersPage` | 12-24 |
| `lib/pages/contact_page.dart` | `ContactPage` | 21-35 |
| `lib/pages/features_page.dart` | `FeaturesPage` | 13-25 |
| `lib/pages/pricing_page.dart` | `PricingPage` | 18-30 |
| `lib/pages/request_failure_page.dart` | `RequestFailurePage` | 13-25 |
| `lib/pages/request_success_page.dart` | `RequestSuccessPage` | 12-24 |
| `lib/pages/status_page.dart` | `StatusPage` | 15-27 |

All 28 pairwise combinations are 78% similar. This is boilerplate — low priority since each page is only 12-13 lines and the structure is Flutter-idiomatic.

---

### 75% — Button / text button variants

| Pair | Similarity |
|------|-----------|
| `AnimatedGradientBorderButton` ~ `AppTextButton` | 75% |
| `GradientButton` ~ `AppTextButton` | 75% |
| `OutlineButton` ~ `AppTextButton` | 75% |

Same button family as the 85% pairs above.

---

### 74% — Docs page scaffold lower pairs

| Pair | Similarity |
|------|-----------|
| `DocsAgentsPage` ~ `DocsAlertsPage` | 74% |
| `DocsAlertsPage` ~ `DocsApiPage` | 74% |
| `DocsAlertsPage` ~ `DocsQuickstartPage` | 74% |

---

### 73% — Cross-page card and component patterns

| Pair | Similarity |
|------|-----------|
| `compliance :: _ResourceLink` ~ `sources :: _MethodologyCard` | 73% |
| `compliance :: _ResourceLink` ~ `status :: _TechSection` | 73% |
| `docs_agents :: _StatBadge` ~ `security :: _StatCard` | 73% |
| `docs_tracing :: _Timeline` ~ `doc_components :: DocNumberedList` | 73% |
| `eu_ai_act :: _TimelineCard` ~ `security :: _StatCard` | 73% |
| `sources :: _MethodologyCard` ~ `doc_components :: DocFeatureCard` | 73% |

Semantically different widgets sharing Container + Column + Text patterns. Low priority.

---

### 72% — Misc structural similarity

| Pair | Similarity |
|------|-----------|
| `comparison :: _DifferentiatorCard` ~ `status :: _HealthComponentChip` | 72% |
| `docs_interop :: _HeroSection` ~ `docs_tracing :: _HeroSection` | 72% |
| `docs_alerts :: _ChannelCard` ~ `sources :: _MethodologyCard` | 72% |
| `docs_alerts :: _AlertTypePreview` ~ `docs_quickstart :: _StepPreview` | 72% |

---

### 71% — Lower similarity pairs

| Pair | Similarity |
|------|-----------|
| `careers :: _CareersHeroSection` ~ `contact :: _ContactHeroSection` | 71% |
| `docs_alerts :: _AlertTypeCard` ~ `docs_alerts :: _ChannelCard` | 71% |
| `docs_alerts :: _AlertTypePreview` ~ `status :: _HealthComponentChip` | 71% |
| `docs_quickstart :: _HealthMetricCard` ~ `features :: _FeatureItem` | 71% |
| `sources :: _MethodologyCard` ~ `status :: _StatusChip` | 71% |

---

### 70% — Threshold pairs

| Pair | Similarity |
|------|-----------|
| `about :: AboutPage` ~ `contact :: ContactPage` | 70% |
| `careers :: CareersPage` ~ `contact :: ContactPage` | 70% |
| `comparison :: _ChoiceCard` ~ `features :: _QueryCard` | 70% |
| `contact :: ContactPage` ~ `features :: FeaturesPage` | 70% |
| `contact :: ContactPage` ~ `pricing :: PricingPage` | 70% |
| `contact :: ContactPage` ~ `request_failure :: RequestFailurePage` | 70% |
| `contact :: ContactPage` ~ `request_success :: RequestSuccessPage` | 70% |
| `contact :: ContactPage` ~ `status :: StatusPage` | 70% |
| `docs_alerts :: DocsAlertsPage` ~ `DocsInteroperabilityPage` | 80% |
| `docs_alerts :: DocsAlertsPage` ~ `DocsObservabilityPage` | 80% |
| `docs_alerts :: DocsAlertsPage` ~ `DocsTracingPage` | 80% |
| `docs_alerts :: _ChannelCard` ~ `doc_components :: DocCodeBlock` | 73% |
| `docs_quickstart :: _HealthMetricCard` ~ `sources :: _MethodologyCard` | 70% |
| `eu_ai_act :: _ChecklistItem` ~ `features :: _QueryCard` | 70% |
| `features :: _FeatureItem` ~ `sources :: _MethodologyCard` | 72% |
| `features :: _FeatureItem` ~ `status :: _TechSection` | 74% |
| `security :: _DangerAlert` ~ `doc_components :: DocInlineWarning` | 74% |
| `security :: _StatCard` ~ `doc_components :: DocStatCard` | 78% |
| `security :: _WarningAlert` ~ `doc_components :: DocInlineWarning` | 77% |
| `sources :: _MethodologyCard` ~ `status :: _TechSection` | 78% |
| `status :: _StatusChip` ~ `status :: _TechSection` | 71% |
| `status :: _TechSection` ~ `doc_components :: DocFeatureCard` | 73% |

---

## Prioritized Action Plan

### Phase 2: Docs page scaffold (next priority — eliminates ~15 pairs)

1. **Extract `DocsPageScaffold`** — shared scaffold for all 7 docs pages (74-86% similar pairs)

### Phase 3: Cross-page patterns (eliminates ~5 pairs)

2. **Merge `_WarningAlert` / `_DangerAlert`** in security_page — 92% similar, single-file refactor
3. **Extract `PageHeroSection`** — shared hero for features/status and other pages
4. **Consolidate `_StatCard` / `_StatBadge` variants** with `DocStatCard`

### Phase 4: Low priority (cosmetic)

5. **Button base extraction** — optional refactor of `buttons.dart`
6. **Trust badge consolidation** — merge `_TrustIndicator` and `_TrustBadge`
7. **Page shell extraction** — optional for 8 generic page scaffolds

---

## Estimated Impact

| Phase | Pairs Eliminated | Files Modified | Risk |
|-------|-----------------|----------------|------|
| Phase 2 | ~15 | 7 docs pages + 1 new scaffold | Medium (new abstraction) |
| Phase 3 | ~5 | ~4 pages | Low (targeted refactors) |
| Phase 4 | ~10 | ~4 files | Low (cosmetic) |
| **Total** | **~30 of 86** | | |

---

## Files Involved (by duplicate pair count)

| File | Pairs Involved |
|------|---------------|
| `lib/pages/docs_quickstart_page.dart` | 16 |
| `lib/pages/docs_agents_page.dart` | 14 |
| `lib/pages/docs_tracing_page.dart` | 14 |
| `lib/pages/docs_api_page.dart` | 13 |
| `lib/pages/docs_alerts_page.dart` | 13 |
| `lib/pages/docs_observability_page.dart` | 10 |
| `lib/pages/docs_interoperability_page.dart` | 10 |
| `lib/pages/status_page.dart` | 10 |
| `lib/pages/security_page.dart` | 8 |
| `lib/pages/features_page.dart` | 8 |
| `lib/pages/contact_page.dart` | 8 |
| `lib/pages/sources_page.dart` | 7 |
| `lib/widgets/common/buttons.dart` | 6 |
| `lib/widgets/docs/doc_components.dart` | 6 |
| `lib/pages/eu_ai_act_page.dart` | 4 |
| `lib/pages/compliance_page.dart` | 3 |
| `lib/pages/comparison_page.dart` | 2 |
| `lib/pages/careers_page.dart` | 2 |
| Other pages (generic shells) | 1-2 each |
