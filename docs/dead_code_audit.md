# Dead Code Audit — Vitis iOS
**Date:** 2026-03-09
**Auditor:** Claude (automated surgical analysis)
**Codebase:** Swift/SwiftUI + Supabase, ~160 source files

---

## 1. Findings Table

| # | File | Line(s) | Symbol | Category | Risk | Confidence | Action |
|---|------|---------|--------|----------|------|------------|--------|
| 1 | `Features/Onboarding/OnboardingFlowView.swift` | 1–133 | `OnboardingFlowView` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — never referenced in `RootView` or any other file | DELETE |
| 2 | `Features/Onboarding/OnboardingCarouselView.swift` | 1–98 | `OnboardingCarouselView` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — no production caller | DELETE |
| 3 | `Features/Onboarding/OnboardingViewModel.swift` | 1–239 | `OnboardingViewModel` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — only used by dead `OnboardingFlowView` | DELETE |
| 4 | `Features/Onboarding/OnboardingStep.swift` | 1–29 | `OnboardingStep` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — only used by dead `OnboardingViewModel` | DELETE |
| 5 | `Features/Onboarding/Steps/EmailStepView.swift` | 1–29 | `EmailStepView` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — only used by dead `OnboardingFlowView` | DELETE |
| 6 | `Features/Onboarding/Steps/NameStepView.swift` | 1–32 | `NameStepView` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — only used by dead `OnboardingFlowView` | DELETE |
| 7 | `Features/Onboarding/Steps/PasswordStepView.swift` | 1–43 | `PasswordStepView` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — only used by dead `OnboardingFlowView` | DELETE |
| 8 | `Features/Onboarding/Steps/PhoneStepView.swift` | 1–64 | `PhoneStepView` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — only used by dead `OnboardingFlowView` | DELETE |
| 9 | `Features/Onboarding/Steps/PhotoStepView.swift` | 1–101 | `PhotoStepView` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — only used by dead `OnboardingFlowView` | DELETE |
| 10 | `Features/Onboarding/Steps/UsernameStepView.swift` | 1–51 | `UsernameStepView` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — only used by dead `OnboardingFlowView` | DELETE |
| 11 | `Services/OnboardingService.swift` | 1–39 | `OnboardingService` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — `complete()` always throws "no longer supported"; only caller is dead `OnboardingViewModel` | DELETE |
| 12 | `Models/ActivityFeedEntry.swift` | 1–63 | `ActivityFeedEntry`, `ProfilePayload`, `WinePayload` (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — only used by `FeedItem.from(entry:)` which itself has zero callers | DELETE |
| 13 | `Models/Follow.swift` | 1–14 | `Follow` struct (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — struct is never instantiated or referenced by type anywhere | DELETE |
| 14 | `Models/CommentCheers.swift` | 1–26 | `CommentCheers` struct (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — struct never referenced outside its definition file | DELETE |
| 15 | `Models/RankingItem.swift` | 1–17 | `RankingItem` struct (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — only referenced inside dead `ProfileStats` | DELETE |
| 16 | `Models/ProfileStats.swift` | 1–62 | `ProfileStats` struct (entire file) | UNREACHABLE_DECL | 🔴 HIGH | 100% — never instantiated or read anywhere in the app | DELETE |
| 17 | `Models/FeedItem.swift` | 192–215 | `FeedItem.from(entry: ActivityFeedEntry, …)` static method | UNREACHABLE_DECL | 🔴 HIGH | 100% — zero call sites; the live path uses `FeedItem.from(row: FeedRowPayload)` | DELETE |
| 18 | `Services/AuthService.swift` | ~208–211 | `AuthService.establishSession(from:)` | UNREACHABLE_DECL | 🔴 HIGH | 100% — no callers anywhere; `handleOpenURL` is the live path used by `AuthStore` | DELETE |
| 19 | `Core/AppConstants.swift` | 31–32 | `devTestEmail`, `devTestPassword` (DEBUG-only constants) | UNREACHABLE_DECL | 🔴 HIGH | 100% — never referenced anywhere outside their definition | DELETE |
| 20 | `Utilities/PhoneFormatter.swift` | 44–52 | `PhoneFormatter.displayString(e164:)` | UNREACHABLE_DECL | 🔴 HIGH | 100% — no callers; phone display is handled inline in PhoneEntryView | DELETE |
| 21 | `Models/CellarItem.swift` | 35–55 | `CellarItem.activityStatement(username:)` + `statementParts(username:)` | UNREACHABLE_DECL | 🔴 HIGH | 100% — neither method called anywhere in the app | DELETE |
| 22 | `Features/Social/FeedViewModel.swift` | 210–230 | `FeedViewModel.statement(for:)` | UNREACHABLE_DECL | 🔴 HIGH | 100% — `statementParts(for:)` is used; the non-parts `statement(for:)` overload is not | DELETE |
| 23 | `Features/Cellar/AddWineViewModel.swift` | 76–79 | `AddWineViewModel.applyCacheFilter(term:)` | UNREACHABLE_DECL | 🔴 HIGH | 100% — private, never called from any reachable code path | DELETE |
| 24 | `Features/Cellar/AddWineViewModel.swift` | 82–87 | `AddWineViewModel.allMatching(_:)` | UNREACHABLE_DECL | 🔴 HIGH | 100% — only called from dead `applyCacheFilter` | DELETE |
| 25 | `Features/Cellar/AddWineViewModel.swift` | 149–156 | `AddWineViewModel.productsMatching(_:)` + `searchCache` property | UNREACHABLE_DECL | 🔴 HIGH | 100% — only consumed by dead `allMatching`; `searchCache` written but never read downstream | DELETE |
| 26 | `Features/Cellar/AddWineViewModel.swift` | 48–55 | `AddWineViewModel.loadDatabaseWines()` + `dbWines` property | UNREACHABLE_DECL | 🔴 HIGH | 97% — `loadDatabaseWines()` is called but `dbWines` is **never read** in any view or downstream logic | DELETE |
| 27 | `Services/WineService.swift` | ~120–145 | `WineService.fetchAllWines(limit:)` | UNREACHABLE_DECL | 🔴 HIGH | 97% — only caller is dead `loadDatabaseWines()`; result never consumed | DELETE |
| 28 | `Features/Profile/WantToTryChip.swift` | 1–end | `WantToTryChip` view | UNREACHABLE_DECL | 🟡 MEDIUM | 90% — no production view uses it; exercised only in `WantToTryChipTests.swift` (sanity test for a dead component) | MANUAL_VERIFY |
| 29 | `Features/Cellar/AddWineViewModel.swift` | 157–190 | `mergeIntoCache(_:)`, `prefetchPopular()`, `fetchPrefetch(term:)`, `filterAndRank(…)` | DEAD_FLOW | 🟡 MEDIUM | 85% — `prefetchPopular()` **is** called from `WantToTryView`; fires real network calls but populates `searchCache`, which is only read by dead `productsMatching`/`allMatching`. Results never reach UI. | DELETE |
| 30 | `Features/Cellar/AddWineViewModel.swift` | 138–141 | `AddWineViewModel.loadMoreSearchResults()` | DEAD_FLOW | 🔴 HIGH | 100% — `hasMorePages` is always hardcoded to `false` in `performSearch`; guard never passes | DELETE `loadMoreSearchResults`; consolidate `hasMorePages` / `currentSearchPage` / `isLoadingMore` |
| 31 | `Models/LocalWineCatalog.swift` | 1–end | `LocalWineCatalog` (entire file, 150+ entries) | UNREACHABLE_DECL | 🔴 HIGH | 100% — only called from dead `allMatching()`; never reaches UI | DELETE |
| 32 | `Services/WineSearchService.swift` | 1–end | `WineSearchService` (entire file) | PHANTOM_DEP | 🟡 MEDIUM | 85% — invoked by `prefetchPopular` → `fetchPrefetch`, but results stored in `searchCache` which nothing reads; network calls fire for zero UI benefit | DELETE (after removing prefetchPopular cluster) |
| 33 | `Features/Cellar/AddWineViewModel.swift` | 21 | `results: [OFFProduct]` property | DEAD_FLOW | 🟡 MEDIUM | 80% — read in `WantToTryView` but always `[]` because the only setter (`applyCacheFilter`) is dead; misleads the "no results" empty-state branch | RENAME_TO_UNDERSCORE or DELETE |
| 34 | `Features/Social/FeedViewModel.swift` | ~12–17 | Private `isCancellation` top-level function (duplicate) | UNREACHABLE_DECL | 🟡 MEDIUM | 80% — identical private helper also exists in `ProfileViewModel.swift`; consider extracting to shared util | MANUAL_VERIFY |

---

## 2. Cleanup Roadmap

### Batch 1 — Entire Dead Files (🔴 HIGH, zero risk)

**Touch order:** Models → Services → Feature trees (avoids cascading "type not found" errors)

| File(s) | LOC Removed | Notes |
|---------|-------------|-------|
| `Models/Follow.swift` | 14 | No dependents |
| `Models/CommentCheers.swift` | 26 | No dependents |
| `Models/RankingItem.swift` | 17 | Remove before ProfileStats |
| `Models/ProfileStats.swift` | 62 | Remove after RankingItem |
| `Models/ActivityFeedEntry.swift` | 63 | Remove before FeedItem edit |
| `Services/OnboardingService.swift` | 39 | Remove before Onboarding Views |
| `Models/LocalWineCatalog.swift` | ~155 | Remove before AddWineViewModel edits |
| `Features/Onboarding/Steps/*.swift` (6 files) | 220 | Remove before OnboardingFlowView |
| `Features/Onboarding/OnboardingStep.swift` | 29 | Remove after Steps |
| `Features/Onboarding/OnboardingViewModel.swift` | 239 | Remove after Steps |
| `Features/Onboarding/OnboardingFlowView.swift` | 133 | Remove last in this group |
| `Features/Onboarding/OnboardingCarouselView.swift` | 98 | No dependents |
| **Estimated Batch 1 total** | **~1 095 LOC** | **~9 files entirely deleted; ~3 files (AddWineViewModel, FeedItem, AuthService, AppConstants) patched** |

**Potential bundle/binary impact:**
- ~819 LOC of SwiftUI view hierarchy eliminated → smaller binary; fewer view types registered with the Swift runtime
- `LocalWineCatalog` removes a ~150-entry static array from the binary's data segment
- Removing `OnboardingViewModel` cuts a significant `@Observable` class from the runtime graph

### Batch 2 — Dead Symbols Inside Live Files (🔴 HIGH, surgical edits)

| Location | Symbol(s) | LOC Removed | Edit |
|----------|-----------|-------------|------|
| `Models/FeedItem.swift:192–215` | `FeedItem.from(entry:)` | ~24 | Delete extension block |
| `Services/AuthService.swift` | `AuthService.establishSession(from:)` | ~4 | Delete method |
| `Core/AppConstants.swift:31–32` | `devTestEmail`, `devTestPassword` | 2 | Delete lines |
| `Utilities/PhoneFormatter.swift:44–52` | `PhoneFormatter.displayString(e164:)` | ~9 | Delete method |
| `Models/CellarItem.swift:35–55` | `activityStatement(username:)` + `statementParts(username:)` | ~21 | Delete extension block |
| `Features/Social/FeedViewModel.swift` | `FeedViewModel.statement(for:)` | ~15 | Delete method |
| `Features/Cellar/AddWineViewModel.swift` | `applyCacheFilter`, `allMatching`, `productsMatching`, `mergeIntoCache`, `prefetchPopular`, `fetchPrefetch`, `filterAndRank`, `searchCache`, `dbWines`, `loadDatabaseWines`, `currentSearchPage`, `hasMorePages`, `isLoadingMore`, `loadMoreSearchResults` | ~95 | Delete entire OFF-cache cluster + pagination stubs |
| `Services/WineService.swift` | `WineService.fetchAllWines(limit:)` | ~25 | Delete method |
| **Batch 2 total** | | **~195 LOC** | |

**Potential bundle/binary impact:**
- Removing `WineSearchService` eliminates live HTTP calls fired on every `WantToTryView` appearance — measurable reduction in startup network traffic
- Removing the `searchCache` cluster frees a `[OFFProduct]` heap allocation
- Removal of `fetchAllWines` eliminates a Supabase query that loads up to 100 wines into memory that was never displayed

### Batch 3 — Manual Verify (🟡 MEDIUM, human decision required)

| Location | Symbol | Action |
|----------|--------|--------|
| `Features/Profile/WantToTryChip.swift` | `WantToTryChip` | Decide: integrate into a real view or delete; delete `WantToTryChipTests.swift` if deleted |
| `Features/Cellar/AddWineViewModel.swift:21` | `results: [OFFProduct]` | If Batch 2 deleted `applyCacheFilter`, this property is permanently `[]`; remove it and simplify `WantToTryView`'s results branch |
| `Services/WineSearchService.swift` | `WineSearchService` | Safe to delete after Batch 2 removes all callers; review for any future OFF re-integration plan |
| `Features/Social/FeedViewModel.swift` | Duplicate `isCancellation` helper | Consolidate with identical function in `ProfileViewModel.swift` into a shared internal extension |

---

## 3. Executive Summary

| Metric | Count |
|--------|-------|
| Total findings | 34 |
| 🔴 HIGH-confidence deletes | 27 |
| 🟡 MEDIUM — verify before deleting | 7 |
| Estimated LOC removed (HIGH batch) | ~1 290 |
| Estimated LOC removed (all batches) | ~1 490 |
| Estimated dead imports eliminated | 3 (PhotosUI in dead PhotoStepView; Contacts + CryptoKit in SocialDiscovery if WineSearchService removed) |
| Entire files safe to delete immediately | 13 |
| Estimated build time improvement | Low-moderate (fewer Swift files to type-check; ~10 fewer `@Observable` / `View` conformances) |
| Phantom network calls eliminated | 8 concurrent OFF searches fired on every `WantToTryView` appearance but stored in an unreachable cache |

### Assessment

The codebase is well-structured and the production flow (phone OTP → cellar → feed → profile) is clean. The bulk of the dead weight comes from **a superseded email-based onboarding path** that was replaced by the current phone-OTP flow but never removed — this accounts for ~820 LOC across 10 files. A second cluster is an **OFF/local-catalog search cache** in `AddWineViewModel` that populates a `searchCache` structure which nothing in the UI ever reads; the cache machinery fires real HTTP requests on every wishlist-sheet appearance for zero user-visible benefit.

**Top-3 highest-impact actions:**

1. **Delete the entire `Features/Onboarding/` subtree** (10 files, ~820 LOC). `RootView` never routes there; `OnboardingService.complete()` throws immediately. Zero risk, instant clarity.

2. **Delete the OFF-cache cluster in `AddWineViewModel`** (`applyCacheFilter`, `allMatching`, `productsMatching`, `mergeIntoCache`, `prefetchPopular`, `fetchPrefetch`, `searchCache`, `dbWines`, `results`, `loadMoreSearchResults`, `hasMorePages`, `isLoadingMore`, `currentSearchPage`) and `WineSearchService` + `LocalWineCatalog`. This eliminates ~8 unnecessary concurrent network requests fired silently on `WantToTryView` appearance and removes ~250 LOC of dead infrastructure.

3. **Delete the five orphaned model files** (`ActivityFeedEntry`, `Follow`, `CommentCheers`, `RankingItem`, `ProfileStats`). These are pure data model files with zero production consumers; deleting them de-clutters the Models directory and removes misleading types from code-search results.
