# Vitis: Comprehensive Strategic & Technical Review

**Perspectives:** Wharton MBA (business/product), MIT Senior SWE (architecture/code), 2026 tech roadmap  
**Scope:** Full codebase, schema, user flows, growth, monetization, and technical debt  
**Date:** February 2026 (post: Want to Try tab, RLS hardening, warning fixes)

---

## Executive Summary

Vitis is a **Social Wine Journal** with a clear product doctrine: tastings = truth, wishlist = intent, feed = growth. Recent security fixes (auth.uid()-only writes, RLS hardening) and UX polish (Want to Try as tab, Save/Want to Try labels) strengthen the foundation. Gaps cluster around: **growth loops**, **error resilience**, **analytics**, **localization**, **2026 tech adoption**, and **documentation drift**.

---

## 1. BUSINESS & PRODUCT (Wharton Lens)

### 1.1 Strengths

| Area | Observation |
|------|-------------|
| **Clear positioning** | Social Wine Journal, not generic social. Correct wedge. |
| **Source-of-truth clarity** | Tastings = events, Wishlist = intent. Avoids semantic confusion. |
| **Quiet Luxury** | Minimal UI, serif fonts, burgundy accent. Differentiated. |
| **Trust hints** | "You often save wines from Alex" – people-first discovery. |
| **Want to Try** | Tab on profile, full list with search, Save from other profiles. |
| **WineCard** | Full page with ratings, comments, wishlist toggle. Strong engagement surface. |

### 1.2 Gaps & Recommendations

| Gap | Why It Matters | Recommendation |
|-----|----------------|----------------|
| **No onboarding value prop** | Users may not understand why to sign up. | Add 2-3 step carousel: "Log wines, discover taste-alikes, build your palate." |
| **"Global" / "Following" tab labels** | Does not signal "explore" vs "your network". | Consider "Explore" / "Your Circle" or "For You" / "Following". |
| **No monetization surface** | No paywall, premium tier, or commerce hook. | Introduce lightweight premium: e.g. "Taste Profile Insights" behind paywall. |
| **Wishlist has no downstream action** | Users save wines but no reminder or purchase intent. | Add "Buy" / "Find near you" link or "Remind me to try" with optional date. |
| **Rated count is passive** | Profile "Rated" is a number. | Already tappable. Add subtle milestone feel (10, 25, 50 wines). |
| **No invite / referral loop** | Growth is organic only. | Add "Invite a friend" from Profile with share sheet and deep link. |
| **Following empty state is static** | "Follow people to see their tastings" – no discovery. | Suggest 3-5 accounts to follow or "People you might like". |

### 1.3 Competitive Moats (Missing or Weak)

| Moat | Current State | Suggestion |
|------|---------------|------------|
| **Data moat** | Tastings are generic; no structured palate profile. | Persist aggregate palate; use for personalization. |
| **Social graph** | Follow/unfollow only. | Add "taste-alike" score: users with similar ratings on overlapping wines. |
| **Wine catalog** | OFF-only; no proprietary data. | Consider partnership (Wine-Searcher, Vivino) for metadata and purchase links. |

---

## 2. APP USAGE & UX

### 2.1 Strengths

| Area | Observation |
|------|-------------|
| **Add Wine flow** | Search -> Rate+Notes -> Cheers. Single screen, low friction. |
| **Cellar filters** | Newest / Highest Rated, All / 8+ / 9+. Useful. |
| **Wishlist from Feed** | Bookmark on feed row; optimistic update. |
| **Trust hint** | Subtle, non-gamified. |
| **Profile tabs** | Recently | Taste | Want to Try. Clear hierarchy. |
| **Want to Try** | Tab content, Open full list, context menu for remove. |
| **Notifications** | Dedicated tab; standalone view. |

### 2.2 Gaps & Recommendations

| Gap | Impact | Recommendation |
|-----|--------|----------------|
| **No offline support** | Poor in cellar/restaurant. | Cache last N tastings; allow offline log with sync on reconnect. |
| **Search no barcode** | OFF supports barcode; Vitis does not. | Add barcode scanner for "Add by label" – high value in restaurant. |
| **Delete tasting** | Swipe to delete in Cellar; no confirmation. | Consider soft confirm for accidental swipes. |
| **Empty Cellar** | "Add wines you've tasted" – good. | Add "Browse popular" or "Try a sample" to reduce cold start. |
| **Notification tap** | Tapping a notification only dismisses. | Navigate to relevant tasting/activity or profile. |

### 2.3 Accessibility

| Gap | Recommendation |
|-----|----------------|
| VoiceOver labels | Add `.accessibilityLabel` and `.accessibilityHint` on Cheers, wishlist, delete. |
| Rating slider | Ensure `.accessibilityValue` with "8.5 out of 10". |
| Color contrast | Verify burgundy on white meets WCAG AA. |

---

## 3. 2026 TECHNOLOGY POTENTIAL

### 3.1 AI / ML Opportunities

| Opportunity | Feasibility | Impact | Path |
|-------------|-------------|--------|------|
| **Personalized feed ranking** | Medium | High | Taste profile + past likes. Start with "boost from people you often agree with." |
| **"Wines you might like"** | Medium | High | Collaborative filtering on ratings. Similar to wines rated 8+ from same region. |
| **Smart note suggestions** | Low | Medium | Category-based note suggestions. Rule-based first. |
| **Tasting summary** | Medium | Medium | "Your 2025: 24 reds, top region Tuscany, avg 7.8." |
| **Natural language search** | High effort | Medium | "Show me light reds from Rhone" – embeddings or structured filters. |

### 3.2 Platform & Infra

| Technology | Use Case | Notes |
|------------|----------|-------|
| **Swift Concurrency** | Already used (async/await). | Full adoption; replace completion handlers. |
| **SwiftData** | Local cache / offline | Replace FeedCache with SwiftData for richer querying. |
| **Widgets** | Last tasted, wishlist count | High visibility; low cost. |
| **App Intents** | "Log wine" shortcut | Siri: "Add Chardonnay to Vitis" – open Add Wine with prefill. |
| **Vision / ML** | Label recognition | Scan wine label -> suggest wine. Core ML or API. |

### 3.3 Backend / Data

| Technology | Use Case | Notes |
|------------|----------|------|
| **Supabase Edge Functions** | Compute-heavy | Trust-hint calc, feed ranking. |
| **Supabase Realtime** | Already used. | Extend to wishlist sync across devices. |
| **pgvector** | Semantic search | "Wines like X" – embeddings. |
| **PostHog / Mixpanel** | Analytics | AnalyticsService is stub; wire to provider. |

---

## 4. CODE QUALITY & ARCHITECTURE

### 4.1 Strengths

| Area | Observation |
|------|-------------|
| **MVVM** | Clear separation; ViewModels own state. |
| **Services** | TastingService, FeedService, CellarService – single responsibility. |
| **Theme** | VitisTheme centralizes colors, fonts, timestamps. |
| **ErrorMessage** | Centralized user-facing errors. |
| **Load ID pattern** | ProfileViewModel uses loadId to avoid stale writes. |
| **FeedCache** | Instant load; preserves last-known-good on failure. |
| **Security** | CellarService uses auth.uid() only for writes; RLS enforces owner-only. |

### 4.2 Gaps (Prioritized)

| Gap | Severity | Recommendation |
|-----|----------|----------------|
| **try? swallowing errors** | P0 | ProfileViewModel: fetchTasteProfile uses try?; on failure taste profile stays stale. Use do/catch, set errorMessage, preserve last-known-good. |
| **Empty catch {}** | P1 | PhotoStepView.loadPickedImage, others – set errorMessage or log. |
| **Analytics stub** | P1 | Wire to PostHog/Mixpanel; track funnel (signup, first tasting, first follow). |
| **Turkish strings in AuthService** | P1 | Sign-up error messages in Turkish. Localize to English (or use localized strings). |
| **Legacy schema** | Low | comparisons, rankings, duel_next_pair – document as deprecated. Do not delete. |
| **Duplicate category logic** | Low | WineCategoryResolver vs WineColorResolver – consolidate if time permits. |
| **DEBUG print** | Low | Replace with `Logger` for production-safe logs. |

### 4.3 Dead / Orphaned Code

| Item | Status | Action |
|------|--------|--------|
| duel_next_pair RPC | No Swift call | Document as legacy. |
| comparisons, rankings tables | Legacy | Document; do not delete. |
| WantToTryChip | No longer used (tab replaced chip) | Delete or repurpose. |
| PROJE_OZETI.md | Outdated (mentions Duel, 4 tabs) | Update to reflect current app (Cellar, Social, Notifications, Profile; no Duel). |

### 4.4 Schema Observations

| Table | Observation |
|-------|-------------|
| **tastings** | Core; well-structured. Consider `tasted_at` vs `created_at` for "when drank" vs "when logged". |
| **cellar_items** | Had vs Wishlist; source_user_id, source_context for trust. RLS hardened. Good. |
| **activity_feed** | tasting_id for deterministic join. Legacy types (rank_update, duel_win) in constraint. |
| **wines** | OFF-driven. category CHECK: Red, White, Sparkling, Rose – no Orange. |

---

## 5. LOCALIZATION & i18n

| Item | Location | Issue | Fix |
|------|----------|-------|-----|
| AuthService signUp | AuthService.swift:81, 90 | Turkish error messages | Use English or NSLocalizedString |
| OnboardingService | OnboardingService.swift:59 | Turkish comment | Use English |
| PROJE_OZETI.md | Root | Turkish project summary | Keep for Turkish readers; add note "For English see README" |

---

## 6. PRIORITIZED ROADMAP

### Immediate (0-2 weeks)

1. Fix try? on ProfileViewModel.fetchTasteProfile – do/catch, errorMessage.
2. Wire AnalyticsService to one provider (PostHog/Mixpanel).
3. Localize AuthService error messages to English.
4. Update PROJE_OZETI.md or README to reflect current tabs (no Duel).

### Short-term (1-2 months)

1. Onboarding carousel with value prop.
2. Barcode scan for Add Wine.
3. "People to follow" on Following empty state.
4. Offline cache for tastings.

### Medium-term (3-6 months)

1. Widget: last tasted wine.
2. Taste profile summary ("Your 2025").
3. Invite/referral flow.

### Long-term (6-12 months)

1. Personalized feed ranking.
2. "Wines you might like" recommendations.
3. Premium tier / paywall.
4. Wine purchase/deep link partnership.

---

## 7. SUMMARY TABLE: "Olsa Daha Iyi"

| Category | Item | Effort | Impact |
|----------|------|--------|--------|
| Product | Onboarding value prop | Low | High |
| Product | Suggested accounts (Following empty) | Medium | High |
| Product | Invite/referral | Medium | High |
| UX | Notification tap -> navigate | Low | Medium |
| UX | Barcode scan | Medium | High |
| UX | Offline log + sync | High | High |
| Tech | Analytics provider | Low | High |
| Tech | Widget | Medium | Medium |
| Tech | Fix try? / empty catch | Medium | High |
| Code | Remove WantToTryChip or repurpose | Low | Low |
| Code | Localize AuthService strings | Low | Medium |
| Business | Premium tier concept | Medium | High |
| Business | Taste-alike score | High | High |

---

## 8. MANUAL TEST CHECKLIST (Post-Review)

- [ ] Add wine to Had -> appears in Cellar and Feed
- [ ] Add wine to Wishlist -> appears in Want to Try tab
- [ ] Profile Want to Try tab: top 5, Open full list
- [ ] Other user profile: Save adds to my wishlist
- [ ] Cellar RLS: User B cannot delete User A's data
- [ ] Notifications tab loads
- [ ] Comment on tasting -> appears in CommentSheet
- [ ] Taste Profile: Grapes/Regions colored by wine type

---

*End of comprehensive review. Consolidated from CODEBASE_AUDIT, PROFESSIONAL_REVIEW, and fresh analysis. Last updated: February 2026.*
