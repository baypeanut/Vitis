# Vitis: Professional Strategic & Technical Review

**Perspectives:** Wharton MBA (business/product), MIT-trained SWE (architecture/code), 2026 tech roadmap  
**Scope:** Full codebase + schema + docs review  
**Date:** 2026 (updated after Want to Try, Notifications bell, Tastes sheet, Taste colors)

---

## Executive Summary

Vitis is a **Social Wine Journal**: log tastings, rate wines, discover via feed, save to wishlist. Product doctrine (tastings = truth, wishlist = intent, feed = growth) is sound. Recent improvements (Want to Try header, notification bell, Taste Profile sheet, wine-type colors) strengthen UX. Gaps cluster around: **growth loops**, **monetization readiness**, **error handling**, **analytics**, and **2026 tech adoption**.

---

## 1. BUSINESS & PRODUCT (Wharton Lens)

### 1.1 Strengths

| Area | Observation |
|------|-------------|
| **Clear positioning** | Social Wine Journal vs generic social network - correct. |
| **Source-of-truth clarity** | Tastings = events, Wishlist = intent. Avoids semantic confusion. |
| **Quiet Luxury** | Minimal UI, serif fonts, burgundy accent - differentiated. |
| **Trust hints** | "You often save wines from Alex" - people-first discovery signal. |
| **Want to Try** | Section on profile, tappable header for full list, toggle from other profiles - discovery loop. |
| **WineCard** | Full page for wine details, ratings, comments - strong engagement surface. |

### 1.2 Gaps & Recommendations

| Gap | Why It Matters | Recommendation |
|-----|----------------|----------------|
| **No onboarding value prop** | Users may not understand why to sign up. | Add 2-3 step carousel: "Log wines, discover taste-alikes, build your palate." |
| **"Global" / "Following" tab labels** | Does not signal "explore" vs "your network". | Consider "Explore" / "Your Circle" or "For You" / "Following". |
| **No monetization surface** | No paywall, premium tier, or commerce hook. | Introduce lightweight premium: e.g. "Taste Profile Insights" (grape/region breakdown) behind paywall. |
| **Wishlist has no downstream action** | Users save wines but no reminder or purchase intent. | Add "Buy" / "Find near you" link or "Remind me to try" with optional date. |
| **Rated count is passive** | Profile "Rated" is a number only. | Make it tappable (already done) and add subtle milestone feel (10, 25, 50 wines). |
| **No invite / referral loop** | Growth is organic only. | Add "Invite a friend" from Profile with share sheet and optional deep link. |
| **Following empty state is static** | "Follow people to see their tastings" - no discovery. | Suggest 3-5 accounts to follow or "People you might like". |

### 1.3 Competitive Moats (Missing or Weak)

| Moat | Current State | Suggestion |
|------|---------------|------------|
| **Data moat** | Tastings are generic; no structured palate profile. | Persist aggregate palate and use for personalization. |
| **Social graph** | Follow/unfollow only. | Add "taste-alike" score: users with similar ratings on overlapping wines. |
| **Wine catalog** | OFF-only; no proprietary data. | Consider partnership (Wine-Searcher, Vivino) for richer metadata and purchase links. |

---

## 2. APP USAGE & UX

### 2.1 Strengths

| Area | Observation |
|------|-------------|
| **Add Wine flow** | Search -> Rate+Notes -> Cheers. Single screen reduces friction. |
| **Cellar filters** | Newest / Highest Rated, All / 8+ / 9+ - useful. |
| **Wishlist from Feed** | Bookmark on feed row; optimistic update. |
| **Trust hint** | Subtle, non-gamified. |
| **Notification bell** | Social tab top-right, badge count, auto mark read on tap. |
| **Tastes as sheet** | Region/Grape drill-down opens as sheet - less disruptive. |
| **Want to Try** | Own profile header opens full list; other profiles show toggle. |
| **Taste Profile colors** | Grapes/Regions use wine-type colors; never black. |

### 2.2 Gaps & Recommendations

| Gap | Impact | Recommendation |
|-----|--------|----------------|
| **No offline support** | Poor experience in cellar/restaurant. | Cache last N tastings; allow offline log with sync on reconnect. |
| **Timestamp format** | `compactTimestamp` shows relative or date - could be richer. | For recent (< 24h) show "2h ago" or "9:42 PM"; for older keep date. |
| **Notification tap** | Tapping a notification row only dismisses sheet. | Navigate to the relevant tasting/activity or profile. |
| **Search no barcode** | OFF supports barcode; Vitis does not expose it. | Add barcode scanner for "Add by label" - high value in restaurant context. |
| **Delete tasting** | Swipe to delete in Cellar; no confirmation. | Consider soft confirm for accidental swipes. |
| **Empty Cellar** | "Add wines you've tasted" - good. | Add "Browse popular" or "Try a sample" to reduce cold start. |

### 2.3 Accessibility

| Gap | Recommendation |
|-----|----------------|
| No VoiceOver labels on key actions | Add `.accessibilityLabel` and `.accessibilityHint` on Cheers, wishlist, delete. |
| Rating slider | Ensure `.accessibilityValue` with "8.5 out of 10". |
| Color contrast | Verify burgundy on white meets WCAG AA. |

---

## 3. 2026 TECHNOLOGY POTENTIAL

### 3.1 AI / ML Opportunities

| Opportunity | Feasibility | Impact | Implementation Path |
|-------------|-------------|--------|---------------------|
| **Personalized feed ranking** | Medium | High | Use taste profile + past likes to rank feed. Start with "boost from people you often agree with." |
| **"Wines you might like"** | Medium | High | Collaborative filtering on ratings. Start with "Similar to wines you rated 8+" from same region/category. |
| **Smart note suggestions** | Low | Medium | Given wine category, suggest notes based on common patterns. Offline rule-based first. |
| **Tasting summary** | Medium | Medium | "Your 2025: 24 reds, top region Tuscany, avg rating 7.8." Aggregate query + simple UI. |
| **Natural language search** | High effort | Medium | "Show me light reds from Rhone" - requires semantic search (embeddings) or structured filters. |

### 3.2 Platform & Infra

| Technology | Use Case | Notes |
|------------|----------|-------|
| **Swift Concurrency** | Already used (`async/await`). | Ensure full adoption; replace remaining completion handlers. |
| **SwiftData** | Local cache / offline | Could replace FeedCache with SwiftData for richer querying. |
| **Widgets** | Last tasted, wishlist count | High visibility; low implementation cost. |
| **App Intents** | "Log wine" shortcut | Siri: "Add Chardonnay to Vitis" - could open Add Wine with prefill. |
| **Vision / ML (on-device)** | Label recognition | Scan wine label -> suggest wine. Requires custom Core ML model or API. |

### 3.3 Backend / Data

| Technology | Use Case | Notes |
|------------|----------|-------|
| **Supabase Edge Functions** | Compute-heavy logic | Move trust-hint calc, feed ranking to edge if needed. |
| **Supabase Realtime** | Already used for feed inserts. | Extend to wishlist sync across devices. |
| **pgvector** | Semantic search | If adding "wines like X", embeddings in pgvector. |
| **PostHog / Mixpanel** | Analytics | AnalyticsService is stub; wire to one provider for funnels. |

---

## 4. CODE QUALITY & ARCHITECTURE

### 4.1 Strengths

| Area | Observation |
|------|-------------|
| **MVVM** | Clear separation; ViewModels own state. |
| **Services** | TastingService, FeedService, CellarService - single responsibility. |
| **Theme** | VitisTheme centralizes colors, fonts, timestamps. |
| **ErrorMessage** | Centralized user-facing errors. |
| **Load ID pattern** | ProfileViewModel uses loadId to avoid stale writes. |
| **FeedCache** | Instant load; preserves last-known-good on failure. |

### 4.2 Gaps (Prioritized)

| Gap | Severity | Recommendation |
|-----|----------|----------------|
| **try? swallowing errors** | P0 | ProfileViewModel: fetchTastings, fetchTasteProfile - use do/catch, set errorMessage, preserve last-known-good. |
| **Empty catch {}** | P1 | FeedView.openNotificationSheet, EditProfileView, FollowersFollowingView, NotificationsView, PhotoStepView - set errorMessage or log. |
| **Analytics stub** | P1 | Wire to PostHog/Mixpanel; track funnel (signup, first tasting, first follow). |
| **Legacy schema** | Low | comparisons, rankings, duel_next_pair - document as deprecated. Do not delete. |
| **Duplicate category logic** | Low | WineCategoryResolver vs WineColorResolver - consolidate if time permits. |
| **No E2E tests** | Medium | Add 1-2 critical path E2E (add wine, view feed). |
| **DEBUG print** | Low | Replace with `Logger` for production-safe logs. |

### 4.3 Schema Observations

| Table | Observation |
|-------|-------------|
| **tastings** | Core; well-structured. Consider `tasted_at` as separate from `created_at` for "when did I drink" vs "when did I log". |
| **cellar_items** | Had vs Wishlist; `source_user_id` for trust. Good. |
| **activity_feed** | `tasting_id` for deterministic join - correct. Legacy types (rank_update, duel_win) still in constraint. |
| **wines** | OFF-driven. category CHECK: Red, White, Sparkling, Rose - no Orange. Consider extending. |
| **comparisons, rankings** | Legacy (duel); no Swift insert. Keep for migrations. |

### 4.4 Dead / Orphaned Code

| Item | Status | Action |
|------|--------|--------|
| NotificationsView | No longer in tab bar; notifications via Social bell | Keep for possible direct nav; or delete if unused. |
| duel_next_pair RPC | No Swift call | Document as legacy. |
| comparisons, rankings tables | Legacy | Document; do not delete. |

---

## 5. PRIORITIZED ROADMAP

### Immediate (0-2 weeks)

1. Fix empty catch blocks and try? on critical paths (ProfileViewModel, FeedView).
2. Wire AnalyticsService to one provider (PostHog/Mixpanel).
3. Notification tap navigates to content.

### Short-term (1-2 months)

1. Onboarding carousel with value prop.
2. Barcode scan for Add Wine.
3. "People to follow" or suggested accounts on Following empty state.
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

## 6. SUMMARY TABLE: "Olsa Daha Iyi"

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
| Code | Remove or document legacy schema | Low | Low |
| Business | Premium tier concept | Medium | High |
| Business | Taste-alike score | High | High |

---

*End of review. Last updated after push: Want to Try, Notifications bell, Tastes sheet, Taste Profile colors, Recent Activity sort, setup_schema consolidation.*
