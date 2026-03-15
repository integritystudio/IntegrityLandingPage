# Widget Duplication Analysis

**Date:** 2026-03-14
**Tool:** `scripts/find_duplication.sh`
**Parameters:** construct=widget, min_similarity=0.7, min_lines=5

## Summary

| Metric | Value |
|--------|-------|
| Total widgets scanned | 251 |
| Duplicate pairs found | 79 |
| 90%+ similar pairs | 0 |
| 80-89% similar pairs | 10 |
| 70-79% similar pairs | 69 |

### Similarity Distribution

```
86% ████  4
85% ███  3
80% ███  3
79% ███████████  11
78% ██████████████████████  22
76% █  1
75% ████  4
74% ████  4
73% ███  3
72% █████  5
71% ███████  7
70% ████████████  12
```

### Progress History

| Metric | 2026-03-09 | 2026-03-12 | 2026-03-14 | Change (total) |
|--------|-----------|-----------|-----------|----------------|
| Widgets scanned | 294 | 249 | 251 | -43 |
| Duplicate pairs | 358 | 86 | 79 | -279 (78% reduction) |
| 100% identical | 27 | 0 | 0 | -27 |
| 90%+ pairs | 86 | 1 | 0 | -86 |

Phase 1 (docs component consolidation) complete. Phase 3 items resolved: `_WarningAlert`/`_DangerAlert` merge (92% pair), and Phase 3a hero consolidation (`_CareersHeroSection`, `_ContactHeroSection`, `features :: _HeroBadge` eliminated via `GradientPillBadge` + `MarketingHeroSection`).

---

## All Findings by Similarity Score

### 86% — Docs page scaffolds

| Pair | Similarity |
|------|-----------|
| `DocsAgentsPage` ~ `DocsObservabilityPage` | 86% |
| `DocsInteroperabilityPage` ~ `DocsObservabilityPage` | 86% |
| `DocsInteroperabilityPage` ~ `DocsTracingPage` | 86% |
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

### 80% — Docs page scaffold (alerts variant)

| Pair | Similarity |
|------|-----------|
| `DocsAlertsPage` ~ `DocsInteroperabilityPage` | 80% |
| `DocsAlertsPage` ~ `DocsObservabilityPage` | 80% |
| `DocsAlertsPage` ~ `DocsTracingPage` | 80% |

Part of the same docs page scaffold pattern as the 86% pairs above.

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

Part of the same docs page scaffold pattern.

---

### 78% — Generic page shells + card patterns

8 pages share an identical Scaffold + SingleChildScrollView + Column pattern (21 pairwise combos):

| File | Widget | Lines |
|------|--------|-------|
| `lib/pages/about_page.dart` | `AboutPage` | 28-40 |
| `lib/pages/careers_page.dart` | `CareersPage` | 12-24 |
| `lib/pages/features_page.dart` | `FeaturesPage` | 13-25 |
| `lib/pages/pricing_page.dart` | `PricingPage` | 18-30 |
| `lib/pages/request_failure_page.dart` | `RequestFailurePage` | 13-25 |
| `lib/pages/request_success_page.dart` | `RequestSuccessPage` | 12-24 |
| `lib/pages/status_page.dart` | `StatusPage` | 16-28 |

Plus 1 cross-page card pair:

| Pair | Similarity |
|------|-----------|
| `sources :: _MethodologyCard` ~ `status :: _TechSection` | 78% |

Boilerplate — low priority since each page shell is only 12-13 lines.

---

### ~~76% — `_TimelineCard` ~ `DocStatCard`~~ — RESOLVED (Phase 3b)

| File | Widget | Lines |
|------|--------|-------|
| ~~`lib/pages/eu_ai_act_page.dart`~~ | ~~`_TimelineCard`~~ | ~~125-165~~ |
| `lib/widgets/docs/doc_components.dart` | `DocStatCard` | 335-388 |

**Status:** Resolved — `_TimelineCard` consolidated into `DocStatCard` via `valueStyle` and `constraints` params (commit `f10c523`, 2026-03-15).

---

### 75% — Button / text button + trust badge variants

| Pair | Similarity |
|------|-----------|
| `AnimatedGradientBorderButton` ~ `AppTextButton` | 75% |
| `GradientButton` ~ `AppTextButton` | 75% |
| `OutlineButton` ~ `AppTextButton` | 75% |
| `TrustBadge` ~ `_TrustIndicator` | 75% |

---

### 74% — Docs page scaffold lower pairs + feature cards

| Pair | Similarity |
|------|-----------|
| `DocsAgentsPage` ~ `DocsAlertsPage` | 74% |
| `DocsAlertsPage` ~ `DocsApiPage` | 74% |
| `DocsAlertsPage` ~ `DocsQuickstartPage` | 74% |
| `features :: _FeatureItem` ~ `status :: _TechSection` | 74% |

---

### 73% — Cross-page card patterns

| Pair | Similarity |
|------|-----------|
| `compliance :: _ResourceLink` ~ `sources :: _MethodologyCard` | 73% |
| `compliance :: _ResourceLink` ~ `status :: _TechSection` | 73% |
| `docs_alerts :: _AlertTypePreview` ~ `status :: _HeroBadge` | 73% |

Semantically different widgets sharing Container + Column + Text patterns. Low priority.

---

### 72% — Misc structural similarity

| Pair | Similarity |
|------|-----------|
| `comparison :: _DifferentiatorCard` ~ `status :: _HealthComponentChip` | 72% |
| ~~`docs_interop :: _HeroSection` ~ `docs_tracing :: _HeroSection`~~ | ~~72%~~ | **Resolved** — Phase 2 (`DocsHeroSection` extraction) |
| `docs_alerts :: _ChannelCard` ~ `sources :: _MethodologyCard` | 72% |
| `docs_alerts :: _AlertTypePreview` ~ `docs_quickstart :: _StepPreview` | 72% |
| `features :: _FeatureItem` ~ `sources :: _MethodologyCard` | 72% |

---

### 71% — Lower similarity pairs

| Pair | Similarity |
|------|-----------|
| ~~`careers :: _CareersHeroSection` ~ `contact :: _ContactHeroSection`~~ | ~~71%~~ | **Resolved** — Phase 3a (`GradientPillBadge` + `MarketingHeroSection`) |
| `docs_alerts :: _AlertTypeCard` ~ `docs_alerts :: _ChannelCard` | 71% |
| `docs_alerts :: _AlertTypePreview` ~ `status :: _HealthComponentChip` | 71% |
| `docs_quickstart :: _HealthMetricCard` ~ `features :: _FeatureItem` | 71% |
| `docs_tracing :: _Timeline` ~ `doc_components :: DocNumberedList` | 71% |
| `sources :: _MethodologyCard` ~ `status :: _StatusChip` | 71% |
| `status :: _StatusChip` ~ `status :: _TechSection` | 71% |

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
| `docs_quickstart :: _HealthMetricCard` ~ `sources :: _MethodologyCard` | 70% |
| `eu_ai_act :: _ChecklistItem` ~ `features :: _QueryCard` | 70% |
| ~~`features :: _HeroBadge`~~ ~ `status :: _HealthComponentChip` | ~~70%~~ | **Partially resolved** — `features :: _HeroBadge` replaced by `GradientPillBadge` (Phase 3a) |
| `sources :: _MethodologyCard` ~ `doc_components :: DocFeatureCard` | 70% |

---

## Prioritized Action Plan

### ~~Phase 2: Docs page scaffold (eliminates ~18 pairs)~~ — DONE

1. ~~**Extract `DocsPageScaffold`**~~ — DONE (commit `93c1099`). Shared scaffold for all 7 docs pages
2. ~~**Extract `DocsHeroSection`**~~ — DONE (commit `8879e7d`). Removed 7 duplicate `_HeroSection` classes

### ~~Phase 3: Cross-page patterns (eliminates ~5 pairs)~~ — DONE

3. ~~**Merge `_WarningAlert` / `_DangerAlert`** in security_page~~ — DONE (eliminated 92% pair)
4. ~~**Extract `PageHeroSection`** — shared hero for features/status and other pages~~ — DONE (Phase 3a: `GradientPillBadge` extracted, `_CareersHeroSection`/`_ContactHeroSection`/`_HeroBadge` eliminated)
5. ~~**Consolidate `_StatCard` / `_StatBadge` variants** with `DocStatCard`~~ — DONE (Phase 3b, commit `f10c523`). `_TimelineCard` and `_StatBadge` consolidated; `about_page::_StatCard` and `social_proof_section::_StatCard` kept (structurally too different)

### Phase 4: Low priority (cosmetic)

5. **Button base extraction** — optional refactor of `buttons.dart`
6. **Trust badge consolidation** — merge `_TrustIndicator` and `_TrustBadge`
7. **Page shell extraction** — optional for 7 generic page scaffolds

---

## Estimated Impact

| Phase | Pairs Eliminated | Files Modified | Risk | Status |
|-------|-----------------|----------------|------|--------|
| Phase 2 | ~18 | 7 docs pages + 2 new widgets | Medium | **DONE** |
| Phase 3 | ~5 | ~4 pages | Low | **DONE** |
| Phase 4 | ~10 | ~4 files | Low (cosmetic) | Open |
| **Total done** | **~23 of 79** | | | |

---

## Files Involved (by duplicate pair count)

| File | Pairs Involved |
|------|---------------|
| `lib/pages/docs_quickstart_page.dart` | 14 |
| `lib/pages/docs_agents_page.dart` | 12 |
| `lib/pages/docs_tracing_page.dart` | 13 |
| `lib/pages/docs_api_page.dart` | 11 |
| `lib/pages/docs_alerts_page.dart` | 14 |
| `lib/pages/docs_observability_page.dart` | 10 |
| `lib/pages/docs_interoperability_page.dart` | 10 |
| `lib/pages/status_page.dart` | 12 |
| `lib/pages/features_page.dart` | 10 |
| `lib/pages/sources_page.dart` | 7 |
| `lib/pages/contact_page.dart` | 8 |
| `lib/widgets/common/buttons.dart` | 6 |
| `lib/widgets/docs/doc_components.dart` | 3 |
| `lib/pages/eu_ai_act_page.dart` | 3 |
| `lib/pages/compliance_page.dart` | 2 |
| `lib/pages/comparison_page.dart` | 2 |
| `lib/pages/careers_page.dart` | 2 |
| Other pages (generic shells) | 1-2 each |
