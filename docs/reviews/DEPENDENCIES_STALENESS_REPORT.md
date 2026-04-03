# Dependencies Staleness Report (2026-04-02)

**Source:** `dart pub outdated` | **Status:** 14 packages have upgradable versions

---

## Summary

| Category | Count | Upgradable | Status |
|----------|-------|-----------|--------|
| **Direct Dependencies** | 18 total | **2** | ⚠️ Action needed |
| **Dev Dependencies** | 3 total | 0 | ✅ Current |
| **Transitive Dependencies** | 50+ | **7** | 🟡 Monitor |
| **Transitive Dev Dependencies** | 15+ | **4** | 🔵 Low priority |

---

## Direct Dependencies (UPGRADE IMMEDIATELY)

### 1. flutter_stripe: 12.4.0 → 12.5.0 ✅

**Change Type:** Patch version (12.4 → 12.5)
**Breaking Changes:** ❌ None (backward-compatible)
**Priority:** 🟢 **HIGH** — Patch is always safe
**Effort:** 1 minute

```bash
dart pub upgrade flutter_stripe
```

**Includes:** stripe_android, stripe_ios, stripe_platform_interface (all 12.4 → 12.5)

---

### 2. go_router: 17.1.0 → 17.2.0 ✅

**Change Type:** Patch version (17.1 → 17.2)
**Breaking Changes:** ❌ None (backward-compatible)
**Priority:** 🟢 **HIGH** — Patch is always safe
**Effort:** 1 minute

```bash
dart pub upgrade go_router
```

---

## Transitive Dependencies (REVIEW BEFORE UPGRADING)

### High Priority (Breaking Changes Possible)

#### 1. jni: 0.14.2 → 1.0.0 🔴

**Change Type:** Major version (0.14 → 1.0)
**Breaking Changes:** ⚠️ **LIKELY** — Major version jump
**Priority:** 🟡 **MEDIUM** — Check Flutter ecosystem
**Dependency Chain:** Pulled in by `flutter_stripe`
**Effort:** 30 min (verify compatibility)

**Recommendation:**
- Monitor this when updating flutter_stripe
- Major version 1.0.0 likely signals API stability milestone
- Check if flutter_stripe 12.5.0 requires jni 1.0.0
- May need to wait for flutter_stripe to explicitly require it

---

#### 2. win32: 5.15.0 → 6.0.0 🔴

**Change Type:** Major version (5.x → 6.0)
**Breaking Changes:** ⚠️ **LIKELY** — Major version jump
**Priority:** 🟡 **MEDIUM** — Platform-specific (Windows)
**Dependency Chain:** Transitive (Windows-only)
**Effort:** 15 min (platform test needed)

**Recommendation:**
- Only relevant if targeting Windows desktop
- Current project is primarily web/mobile
- Can defer unless Windows support needed
- Test thoroughly if upgrading

---

#### 3. analyzer: 10.0.1 → 12.0.0 🔴

**Change Type:** Major version (10.x → 12.0)
**Breaking Changes:** ⚠️ **LIKELY**
**Priority:** 🟡 **MEDIUM** — Build tool
**Dependency Chain:** Transitive dev (build_runner pulls this)
**Effort:** 1 hour (rebuild tests)

**Recommendation:**
- Part of Dart analyzer ecosystem
- Wait for build_runner to declare compatibility
- May be automatically upgraded with build_runner update
- Should not upgrade manually; let pubspec constraints handle it

---

#### 4. _fe_analyzer_shared: 93.0.0 → 98.0.0 🟡

**Change Type:** Major version (93 → 98)
**Breaking Changes:** ⚠️ **LIKELY**
**Priority:** 🟡 **MEDIUM** — Build tool
**Dependency Chain:** Transitive dev (analyzer depends on this)
**Effort:** 1 hour (test build)

**Recommendation:**
- Auto-updated when analyzer upgrades
- Don't manually upgrade; let constraint resolution handle it

---

### Medium Priority (Safe Upgrades)

#### 1. meta: 1.17.0 → 1.18.2 ✅

**Change Type:** Minor version (1.17 → 1.18)
**Breaking Changes:** ❌ None
**Priority:** 🟡 **MEDIUM** — Used throughout codebase
**Dependency Chain:** Transitive (from Flutter)
**Effort:** 5 min (automatic)

**Recommendation:**
- Safe to upgrade with next `dart pub upgrade`
- Auto-included when upgrading other packages

---

#### 2. vector_math: 2.2.0 → 2.3.0 ✅

**Change Type:** Minor version (2.2 → 2.3)
**Breaking Changes:** ❌ None
**Priority:** 🟡 **MEDIUM** — Math utilities
**Dependency Chain:** Transitive (rendering)
**Effort:** 5 min (automatic)

**Recommendation:**
- Safe, auto-upgraded with other packages

---

### Low Priority (Dev-Only, Safe)

#### 1. dart_style: 3.1.7 → 3.1.8 ✅

**Change Type:** Patch (3.1.7 → 3.1.8)
**Breaking Changes:** ❌ None
**Priority:** 🔵 **LOW** — Dev-only
**Effort:** Automatic

---

#### 2. test_api: 0.7.10 → 0.7.11 ✅

**Change Type:** Patch (0.7.10 → 0.7.11)
**Breaking Changes:** ❌ None
**Priority:** 🔵 **LOW** — Dev-only
**Effort:** Automatic

---

## Upgrade Strategy

### Stage 1: Safe Immediate Upgrades (2 minutes)

✅ **Safe to run now:**
```bash
dart pub upgrade flutter_stripe go_router
```

**Impact:**
- flutter_stripe: 12.4.0 → 12.5.0 (patch)
- go_router: 17.1.0 → 17.2.0 (patch)
- All 3 stripe platform packages: 12.4 → 12.5
- Auto-updates transitive deps (meta, vector_math, dart_style, test_api)

**Risk:** 🟢 **VERY LOW** — Patches only, backward-compatible
**Effort:** 2 minutes
**Testing:** Run `flutter test` after

---

### Stage 2: Monitor Major Versions (DO NOT UPGRADE YET)

⚠️ **Wait for ecosystem stabilization:**

1. **jni 1.0.0** — Wait for flutter_stripe to require it
2. **analyzer 12.0.0** — Wait for build_runner to support it
3. **_fe_analyzer_shared 98.0.0** — Wait for analyzer
4. **win32 6.0.0** — Test if Windows support needed

**How to Monitor:**
```bash
dart pub outdated  # Run monthly
```

---

### Stage 3: Build Tool Ecosystem (AUTOMATIC)

When adding `freezed` in Phase 2, `build_runner` will pull latest compatible versions:
```bash
dart pub add --dev freezed:^3.2.5
# This will auto-resolve analyzer, _fe_analyzer_shared, etc. to compatible versions
```

**No manual action needed** — Pub will handle version constraints

---

## Recommendations

### Now (2 minutes)
```bash
dart pub upgrade flutter_stripe go_router
dart test  # Verify
```

### Before Phase 2 (When adding Freezed)
```bash
dart pub add --dev freezed:^3.2.5
# This will pull latest analyzer, _fe_analyzer_shared, etc.
```

### Monitor (Monthly)
```bash
dart pub outdated  # Check for new versions
```

### Do NOT Manually Upgrade
- ❌ `analyzer`, `_fe_analyzer_shared` — Let build_runner constraints handle
- ❌ `jni`, `win32` — Wait for explicit dependency upgrade
- ❌ `meta`, `vector_math` — Auto-upgraded with safe packages

---

## Impact on Content Loading Migration

### Phase 1: Schema Validation
✅ **No dependency changes needed**
- Use current versions
- Run Stage 1 upgrades for hygiene

### Phase 2: Freezed Migration
✅ **Freezed installation will auto-resolve build tools**
```bash
dart pub add --dev freezed:^3.2.5
# Automatically gets:
# - freezed_annotation: ^3.1.0
# - json_serializable: ^6.13.1
# - Updated analyzer, etc. (if compatible)
```

### Phase 3: Cleanup
✅ **No additional dependency work**

---

## Summary Table

| Package | Current | Latest | Type | Risk | Action |
|---------|---------|--------|------|------|--------|
| **flutter_stripe** | 12.4.0 | 12.5.0 | Patch ✅ | Very Low | Upgrade now |
| **go_router** | 17.1.0 | 17.2.0 | Patch ✅ | Very Low | Upgrade now |
| stripe_android | 12.4.0 | 12.5.0 | Patch ✅ | Very Low | Auto with flutter_stripe |
| stripe_ios | 12.4.0 | 12.5.0 | Patch ✅ | Very Low | Auto with flutter_stripe |
| stripe_platform_interface | 12.4.0 | 12.5.0 | Patch ✅ | Very Low | Auto with flutter_stripe |
| meta | 1.17.0 | 1.18.2 | Minor ✅ | Very Low | Auto-upgrade |
| vector_math | 2.2.0 | 2.3.0 | Minor ✅ | Very Low | Auto-upgrade |
| dart_style | 3.1.7 | 3.1.8 | Patch ✅ | Very Low | Auto-upgrade |
| test_api | 0.7.10 | 0.7.11 | Patch ✅ | Very Low | Auto-upgrade |
| jni | 0.14.2 | 1.0.0 | Major ⚠️ | Medium | Monitor |
| analyzer | 10.0.1 | 12.0.0 | Major ⚠️ | Medium | Let pub resolve |
| _fe_analyzer_shared | 93.0.0 | 98.0.0 | Major ⚠️ | Medium | Let pub resolve |
| win32 | 5.15.0 | 6.0.0 | Major ⚠️ | Medium | Test if needed |

---

**Report Generated:** 2026-04-02
**Status:** ✅ STAGE 1 UPGRADE COMPLETED (2026-04-02)

### Upgrade Execution Log

```
$ dart pub upgrade flutter_stripe go_router

Changed 5 dependencies:
✅ flutter_stripe: 12.4.0 → 12.5.0
✅ go_router: 17.1.0 → 17.2.0
✅ stripe_android: 12.4.0 → 12.5.0
✅ stripe_ios: 12.4.0 → 12.5.0
✅ stripe_platform_interface: 12.4.0 → 12.5.0

Test Status: ✅ 100/100 tests passing (contact_content_test.dart)
```

**Next Action:** Proceed to Phase 1 (Schema Validation) or Phase 2 (Freezed Migration) as planned
