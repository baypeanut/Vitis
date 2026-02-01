# Vitis Codebase Audit

**Date:** 2026  
**Scope:** Full audit for Big Tech-level maintainability  
**Approach:** Inventory, dead code, source-of-truth mismatches, concurrency, error handling

---

## 1. REPO MAP (Architecture Inventory)

### Services
| Service | Responsibility | Key Files |
|---------|----------------|-----------|
| AuthService | Session, profile fetch, password recovery | AuthService.swift |
| CellarService | Wishlist (cellar_items), rankings (legacy), fetch/add/remove | CellarService.swift |
| DevSignupService | Dev mock signup | DevSignupService.swift |
| DevLoginService | Dev mock login | DevLoginService.swift |
| FeedService | Global/Following feed, cache, realtime, delete activity | FeedService.swift |
| NotificationService | Fetch, mark read, create like/comment notifications | NotificationService.swift |
| OnboardingService | Step validation, profile upsert | OnboardingService.swift |
| ProfileService | Username check, taste profile, last activity, rankings count | ProfileService.swift |
| ProfileStore | Current user profile cache, @Observable | ProfileStore.swift |
| SocialService | Likes, comments, follow/unfollow, counts | SocialService.swift |
| TastingService | Create/delete tastings, fetch user tastings, feed integration | TastingService.swift |
| WineSearchService | OFF API search, pagination | WineSearchService.swift |
| WineService | DB wine fetch, upsert from OFF | WineService.swift |
| AnalyticsService | Fire-and-forget event tracking (stub) | AnalyticsService.swift |
| AvatarStorageService | Avatar upload | AvatarStorageService.swift |
| FeedCache | Disk cache for feed items | FeedCache.swift |

### ViewModels
| ViewModel | State Ownership | Key State |
|-----------|-----------------|-----------|
| FeedViewModel | items, wishlistWineIds, wishlistSourceUserIds, tab | FeedView |
| CellarViewModel | tastings, groupedTastings, sortOption, ratingFilter | CellarView |
| AddWineViewModel | results, dbWines, query, pagination | AddWineSheet |
| ProfileViewModel | profile, tastings, wishlistPreview, myWishlistWineIds | ProfileView, UserProfileView |
| EditProfileViewModel | Form fields | EditProfileView |
| OnboardingViewModel | Step state | OnboardingFlowView |
| DevLoginViewModel | Dev login | DevLoginView |

### Major Views/Screens
| View | Purpose |
|------|---------|
| RootView | Auth gate, TabView (Cellar, Social, Profile) |
| CellarView | My Cellar (tastings by category) |
| SocialView | Feed (Global/Following) + notification bell |
| FeedView | Feed list, notification sheet |
| ProfileView | Own profile |
| UserProfileView | Other user profile (with UserCellarView, CommentSheet) |
| UserProfileViewContent | Same, for navigation push |
| AddWineSheet | Search → Rate+Notes → Save |
| TastingRateView | Rating slider + notes chips + Cheers |
| WantToTryView | Full wishlist (from Profile) |
| UserCellarView | Other user's tasting list (from Profile) |
| CommentSheetView | Comments (Profile/Notifications only, not Feed) |
| NotificationsView | Standalone notifications (not in tab bar; used from Social bell) |

### Data Models / DTOs
| Model | Purpose |
|-------|---------|
| Wine | Core wine entity |
| Tasting | Rating + notes, linked to activity_feed |
| CellarItem | Wishlist/had from cellar_items |
| FeedItem | Feed display (from feed_with_details) |
| FeedRowPayload | Supabase decode for feed |
| Profile | User profile |
| RankingItem | Legacy rankings (Elo) |
| CommentCheers | Legacy comments_cheers table (unused in Swift) |
| OFFProduct | OFF API product |
| NotificationItem | Notification display |

### Caches
| Cache | Key | Purpose |
|-------|-----|---------|
| FeedCache | feed_global_v4, feed_following_v4 | Instant feed load |

### Database / RPC
| RPC/Table | Purpose |
|-----------|---------|
| feed_following | Following tab feed |
| check_username_available | Signup validation |
| upsert_wine_from_off | Add wine from OFF |
| feed_with_details | View for Global feed, activity fetch |
| tables: wines, profiles, tastings, activity_feed, cellar_items, likes, comments, notifications, follows, rankings, comparisons | Schema |
| duel_next_pair | Legacy RPC (not called from Swift) |

---

## 2. DEAD CODE & LEGACY DETECTION

| Item | Why Dead | Evidence | Risk | Proposed Action |
|------|----------|----------|------|-----------------|
| NotesSelectView | Replaced by merged TastingRateView | Never referenced (AddWineSheet uses TastingRateView) | Low | Delete |
| CellarService.fetchMyRanking | Rankings/duel removed; Cellar uses TastingService | No caller; CellarViewModel uses TastingService | Low | Delete |
| ProfileService.fetchRankingsCount | Profile uses TastingService.fetchTastingsCount | No caller; ProfileViewModel uses fetchTastingsCount | Low | Delete |
| FeedService.fetchActivityForUser | Profile uses TastingService + allTastings | No caller | Low | Delete |
| SocialService.fetchCommentCounts | Comments removed from Feed; FeedItem has no commentCount | No caller | Low | Delete |
| CommentCheers model | App uses likes + comments tables; comments_cheers is legacy | No Swift reference | Low | Keep (DB table exists); add deprecation comment |
| duel_next_pair RPC | Duel removed | No Swift RPC call | Low | Do not touch (schema); document as legacy |
| comparisons table | Duel; no Swift insert/select | Only in schema, duel_next_pair | Low | Do not touch (schema) |
| rankings table | Profile "Rated" = tastings count; rankings unused | fetchMyRanking dead; ProfileService.fetchRankingsCount dead | Med | Optional: document; rankings used by duel_next_pair |
| ActivityType.rankUpdate, .newEntry, .duelWin | Feed filters to had_wine only | Still in enum; feed filters | Low | Keep (schema supports; legacy feed rows may exist) |
| NotificationsView | Removed from tab bar; notifications in Social bell | RootView has no Notifications tab | Med | If never navigated to, consider delete or keep for direct nav |
| ProfileContentView "Want to Try" header button | onWantToTryTap exists but ProfileView does not pass it | ProfileView has no showWantToTry, no onWantToTryTap | Med | Restore wiring if Want to Try full list is desired from own profile |

---

## 3. MISMATCHED SOURCE OF TRUTH

| Mismatch | Current Behavior | Why Incorrect/Fragile | Minimal Fix |
|----------|------------------|------------------------|-------------|
| rankingsCount vs tastings | ProfileViewModel.rankingsCount = TastingService.fetchTastingsCount; label "Rated" | Variable name misleading; "Rated" is correct | Rename rankingsCount → ratedCount (optional) |
| Two category resolvers | WineCategoryResolver (category string for grouping), WineColorResolver (Color for display) | Duplicate grape/category heuristics; can drift | Consider WineColorResolver as source; WineCategoryResolver could delegate to shared resolution (low priority) |
| Cellar: tastings vs cellar_items | My Cellar = tastings; Wishlist = cellar_items | Clear per product doctrine; no mismatch | None |
| Feed activity types | Only had_wine shown; rank_update, duel_win exist in schema | Legacy; feed filters correctly | None |

---

## 4. CONCURRENCY + STATE SAFETY AUDIT

| Risk | Location | Issue | Severity | Suggested Fix |
|------|----------|-------|----------|---------------|
| ViewModel in body | FeedView, CellarView, AddWineSheet, etc. | `@State private var viewModel = X()` — SwiftUI may recreate on body re-eval | P1 | Use `@State` with `@Observable` (iOS 17+); ensure no init in body. Current pattern is acceptable for @Observable. |
| try? swallowing errors | ProfileViewModel, FeedViewModel, FeedService, etc. | `(try? await X()) ?? []` — failures become empty; no user feedback | P0 | For critical paths, use do/catch and set errorMessage; for non-critical (e.g. wishlist sources), keep try? but document |
| refresh clearing state | FeedViewModel.refresh | loadFromCache() at start; items replaced only on success | OK | Correct (no clear-before-fetch) |
| catch {} empty | NotificationsView.load, FollowersFollowingView, EditProfileView | Silent failure; user sees stale/empty | P1 | At minimum set errorMessage or log |
| ProfileViewModel try? | fetchTastings, fetchTasteProfile | try? swallows; newTastings/newTasteProfile stay nil | P1 | Use do/catch; preserve last-known-good |
| Cancellation mutating | Various | isCancellation checks prevent some; ensure no state write after cancel | P2 | Audit Task cancellation in refresh paths |
| AuthRecoveryState @ObservedObject | RootView | Shared singleton; fine | OK | None |

**Worst issue example (P0):**

```swift
// ProfileViewModel.load() - tastings fetch
if let tastings = try? await TastingService.fetchTastings(userId: uid) {
    newTastings = tastings
}
// On failure: newTastings stays nil, we never assign. But we have:
if let t = try? await ProfileService.fetchTasteProfile(...) { ... }
// So on network error, we might leave profile/tastings in inconsistent state.
// Fix: do { newTastings = try await ... } catch { errorMessage = ...; /* keep old */ }
```

---

## 5. ERROR HANDLING & LOGGING CONSISTENCY

| Item | Current State | Recommendation |
|------|---------------|----------------|
| User-facing errors | ErrorMessage.userFacing(for:) used in many places | Keep; ensure all catch paths use it |
| Mixed language | AuthService, OnboardingService had Turkish; mostly fixed | Verify no remaining Turkish |
| NSError domains | WineSearchService, etc. use custom domains | OK for now |
| print() | #if DEBUG print in various places | Replace with os.Logger or structured logger for production |
| try? | 50+ usages | Document which are intentional (non-critical) vs should propagate |

**Minimal standard:**
- Use `ErrorMessage.userFacing(for: error)` for all user-visible errors.
- Avoid `catch {}`; at least set a generic error state.
- For DEBUG prints, consider `Logger(subsystem: "com.ahmet.vitis", category: "Feed").debug("...")`.

---

## 6. OUTPUT

### A) Executive Summary – Top 5 Blockers

1. **Silent error swallowing (try?)** – Profile load, wishlist, taste profile can fail with no user feedback. Corrupts trust.
2. **Dead service methods** – fetchMyRanking, fetchRankingsCount, fetchActivityForUser, fetchCommentCounts add maintenance load and confusion.
3. **Dead views** – NotesSelectView unused; NotificationsView may be orphaned.
4. **Empty catch blocks** – NotificationsView, FollowersFollowingView, EditProfileView hide failures.
5. **Misleading naming** – rankingsCount is actually tasting count; legacy ActivityType/rankings remain in schema without clear deprecation docs.

### B) PR Plan

**PR1: Dead code removal + model cleanup (safest)**  
- Scope: Delete NotesSelectView. Delete fetchMyRanking, fetchRankingsCount, fetchActivityForUser, fetchCommentCounts. Add deprecation comment to CommentCheers.  
- Files: NotesSelectView.swift (delete), CellarService, ProfileService, FeedService, SocialService  
- Risk: Low  
- Verification: Build, run, confirm no regressions.

**PR2: Service error handling (stop swallowing)**  
- Scope: ProfileViewModel – do/catch for fetchTastings, fetchTasteProfile; set errorMessage on failure; preserve last-known-good. Replace empty catch {} with error state in NotificationsView, FollowersFollowingView, EditProfileView.  
- Files: ProfileViewModel, NotificationsView, FollowersFollowingView, EditProfileView  
- Risk: Medium (may surface previously hidden errors)  
- Verification: Simulate network failure; confirm user sees message, state not wiped.

**PR3: Concurrency/state fixes**  
- Scope: Ensure no state mutation after Task cancel in refresh paths. Add loadId/guard pattern where missing.  
- Files: FeedViewModel, ProfileViewModel, CellarViewModel  
- Risk: Low  
- Verification: Cancel during load; confirm no crash or corrupt state.

**PR4: Duplicated logic (optional, minimal)**  
- Scope: Only if time permits. Consider WineCategoryResolver delegating to shared type resolution used by WineColorResolver.  
- Risk: Medium (refactor)  
- Verification: Unit tests for WineCategoryResolver.

### C) Do Not Touch List

- TastingService, Tasting model – core, stable  
- FeedViewModel refresh/cache flow – correct pattern  
- CellarViewModel load (preserves state on error)  
- AuthService session flow  
- WineColorResolver – used widely, correct  
- Supabase schema (comparisons, rankings, duel_next_pair) – legacy but required by migrations; do not delete  
- CommentSheetView, Comment flow in Profile/Notifications – still used  
- AddWineSheet, TastingRateView – recently refactored, stable
