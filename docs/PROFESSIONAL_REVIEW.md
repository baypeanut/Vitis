# Vitis: Professional Strategic & Technical Review

**Perspectives:** Wharton MBA (business/product), MIT-trained SWE (architecture/code), 2026 tech roadmap  
**Scope:** Full codebase + schema + docs review  
**Date:** 2026

---

## Executive Summary

Vitis positions itself as a **Social Wine Journal**: log tastings, rate wines, discover via feed, save to wishlist. The product doctrine (tastings = truth, wishlist = intent, feed = growth) is sound. The codebase is generally clean and MVVM-aligned. Gaps cluster around: **growth loops**, **monetization readiness**, **data differentiation**, **schema cleanup**, and **2026 tech adoption**.

---

## 1. BUSINESS & PRODUCT (Wharton Lens)

### 1.1 Strengths

| Area | Observation |
|------|-------------|
| **Clear positioning** | Social Wine Journal vs generic social network - correct. |
| **Source-of-truth clarity** | Tastings = events, Wishlist = intent. Avoids semantic confusion. |
| **Quiet Luxury** | Minimal UI, serif fonts, burgundy accent - differentiated. |
| **Trust hints** | "You often save wines from Alex" - people-first discovery signal. |

### 1.2 Gaps & Recommendations

| Gap | Why It Matters | Recommendation |
|-----|----------------|----------------|
| **No onboarding value prop** | Users may not understand why to sign up. | Add a 2-3 step onboarding carousel explaining: "Log wines, discover taste-alikes, build your palate." |
| **"Curated by" is vague** | Feed header does not signal "your network" vs "everyone". | Consider "For You" / "Following" or "Explore" / "Your Circle" for clearer mental model. |
| **No monetization surface** | No paywall, premium tier, or commerce hook. | Introduce a lightweight premium concept: e.g. "Taste Profile Insights" (grape/region breakdown) behind paywall. |
| **Wishlist has no downstream action** | Users save wines but no reminder or purchase intent. | Add "Buy" / "Find near you" link (Vivino-style) or "Remind me to try" with optional date. |
| **Rated count is passive** | Profile "Rated" is a number only. | Make it tappable to Cellar (already done) but add a visual "progress" feel, e.g. "12 wines logged" with subtle milestone (10, 25, 50). |
| **No invite / referral loop** | Growth is organic only. | Add "Invite a friend" from Profile with share sheet and optional deep link. |
| **Following empty state is static** | "Follow people to see their tastings" - no discovery. | Suggest 3-5 accounts to follow (e.g. top tasters, verified sommeliers) or "People you might like". |

### 1.3 Competitive Moats (Missing or Weak)

| Moat | Current State | Suggestion |
|------|---------------|------------|
| **Data moat** | Tastings are generic; no structured palate profile. | Persist aggregate palate (preferred regions, avg rating by category) and use for personalization. |
| **Social graph** | Follow/unfollow only. | Add "taste-alike" score: users with similar ratings on overlapping wines. |
| **Wine catalog** | OFF-only; no proprietary data. | Consider partnership with wine database (Wine-Searcher, Vivino) for richer metadata and purchase links. |

---

## 2. APP USAGE & UX

### 2.1 Strengths

| Area | Observation |
|------|-------------|
| **Add Wine flow** | Search -> Rate+Notes -> Cheers. Single screen for rating + notes reduces friction. |
| **Cellar filters** | Newest / Highest Rated, All / 8+ / 9+ - useful. |
| **Wishlist from Feed** | Bookmark on feed row; optimistic update. |
| **Trust hint** | Subtle, non-gamified. |
| **Category tabs** | Red/White/Rose/Sparkling - clear mental model. |

### 2.2 Gaps & Recommendations

| Gap | Impact | Recommendation |
|-----|--------|----------------|
| **No offline support** | Poor experience in cellar/restaurant. | Cache last N tastings; allow offline log with sync on reconnect. |
| **Timestamp format** | `compactTimestamp` shows "Jan 28, 2026" - no time. | For recent (< 24h) show "2h ago" or "9:42 PM"; for older keep date. |
| **Want to Try full list** | Profile "Want to Try" section exists but no header button to open full list on own profile. | Wire `onWantToTryTap` from ProfileView to navigate to WantToTryView. |
| **Notification tap does nothing** | Tapping a notification row only dismisses sheet. | Navigate to the relevant tasting/activity or profile. |
| **No haptic on key actions** | Cheers, wishlist toggle could use light haptic. | Add `UIImpactFeedbackGenerator(.light)` on success (already on wishlist toggle from profile). |
| **Search no barcode** | OFF supports barcode; Vitis does not expose it. | Add barcode scanner for "Add by label" - high value in restaurant context. |
| **Delete tasting** | Swipe to delete in Cellar; no confirmation. | Consider soft confirm for accidental swipes. |
| **Empty Cellar** | "Add wines you've tasted" - good. | Add "Browse popular" or "Try a sample" to reduce cold start. |

### 2.3 Accessibility

| Gap | Recommendation |
|-----|----------------|
| No VoiceOver labels on key actions | Add `.accessibilityLabel` and `.accessibilityHint` on Cheers, wishlist, delete. |
| Rating slider | Ensure slider is fully accessible (e.g. `.accessibilityValue` with "8.5 out of 10"). |
| Color contrast | Verify burgundy on white meets WCAG AA. |

---

## 3. 2026 TECHNOLOGY POTENTIAL

### 3.1 AI / ML Opportunities

| Opportunity | Feasibility | Impact | Implementation Path |
|-------------|-------------|--------|---------------------|
| **Personalized feed ranking** | Medium | High | Use taste profile + past likes to rank feed. Start with simple "boost from people you often agree with." |
| **"Wines you might like"** | Medium | High | Collaborative filtering on ratings. Requires enough data; start with "Similar to wines you rated 8+" from same region/category. |
| **Smart note suggestions** | Low | Medium | Given wine category, suggest notes based on common patterns. Offline rule-based first. |
| **Tasting summary** | Medium | Medium | "Your 2025: 24 reds, top region Tuscany, avg rating 7.8." Aggregate query + simple UI. |
| **Natural language search** | High effort | Medium | "Show me light reds from Rhone" - requires semantic search (embeddings) or structured filters. |

### 3.2 Platform & Infra

| Technology | Use Case | Notes |
|------------|----------|-------|
| **Swift Concurrency** | Already used (`async/await`). | Ensure full adoption; replace remaining completion handlers. |
| **SwiftData** | Local cache / offline | Could replace FeedCache with SwiftData for richer querying. |
| **Widgets** | Last tasted, wishlist count | High visibility; low implementation cost. |
| **Live Activities** | N/A for wine | Skip. |
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

### 4.2 Gaps (from CODEBASE_AUDIT + this review)

| Gap | Severity | Recommendation |
|-----|----------|----------------|
| **try? swallowing** | P0 | Replace with do/catch on critical paths (Profile load, tastings, taste profile). Preserve last-known-good. |
| **Empty catch {}** | P1 | NotificationsView, FollowersFollowingView, EditProfileView - set errorMessage or log. |
| **Legacy schema** | Low | comparisons, rankings, comments_cheers, duel_next_pair - document as deprecated. Do not delete (migrations). |
| **ProfileStats / RankingItem** | Low | Unused. Safe to delete in future cleanup. |
| **Duplicate category logic** | Low | WineCategoryResolver vs WineColorResolver - consolidate if time permits. |
| **Analytics stub** | Medium | Wire to PostHog/Mixpanel; track funnel (signup, first tasting, first follow). |
| **No E2E tests** | Medium | Add 1-2 critical path E2E (e.g. add wine, view feed). |
| **DEBUG print** | Low | Replace with `Logger` for production-safe logs. |

### 4.3 Schema Observations

| Table | Observation |
|-------|-------------|
| **tastings** | Core; well-structured. Consider `tasted_at` as separate from `created_at` for "when did I drink" vs "when did I log". |
| **cellar_items** | Had vs Wishlist; `source_user_id` for trust. Good. |
| **activity_feed** | `tasting_id` for deterministic join - correct. Legacy types (rank_update, duel_win) still in constraint. |
| **comments_cheers** | Unused (likes + comments used). Legacy. |
| **wines** | OFF-driven. category CHECK allows only Red, White, Sparkling, Rose - no Orange. Consider extending. |

### 4.4 Security & Privacy

| Area | Observation |
|------|-------------|
| **RLS** | Properly scoped; own-user policies. |
| **Dev mock** | Hardcoded UUID in schema - document that each dev replaces. |
| **Secrets** | SupabaseConfig gitignored - good. |
| **PII in analytics** | AnalyticsService does not send PII - good. |

---

## 5. PRIORITIZED ROADMAP

### Immediate (0–2 weeks)

1. Wire `onWantToTryTap` so own profile opens WantToTryView.
2. Fix empty catch blocks (PR2 from audit).
3. Improve timestamp: "2h ago" for recent, date for older.
4. Wire AnalyticsService to one provider.

### Short-term (1–2 months)

1. Onboarding carousel with value prop.
2. Barcode scan for Add Wine.
3. "People to follow" or suggested accounts on Following empty state.
4. Notification tap navigates to content.

### Medium-term (3–6 months)

1. Offline support for logging tastings.
2. Widget: last tasted wine.
3. Taste profile summary ("Your 2025").
4. Invite/referral flow.

### Long-term (6–12 months)

1. Personalized feed ranking.
2. "Wines you might like" recommendations.
3. Premium tier / paywall.
4. Wine purchase/deep link partnership.

---

## 6. SUMMARY TABLE: "Olsa Daha Iyi"

| Category | Item | Effort | Impact |
|----------|------|--------|--------|
| Product | Onboarding value prop | Low | High |
| Product | Want to Try header button | Low | Medium |
| Product | Suggested accounts (Following empty) | Medium | High |
| Product | Invite/referral | Medium | High |
| UX | Timestamp "2h ago" | Low | Medium |
| UX | Notification tap -> navigate | Low | Medium |
| UX | Barcode scan | Medium | High |
| UX | Offline log + sync | High | High |
| Tech | Analytics provider | Low | High |
| Tech | Widget | Medium | Medium |
| Tech | Fix try? / empty catch | Medium | High |
| Code | Remove legacy schema (or document) | Low | Low |
| Business | Premium tier concept | Medium | High |
| Business | Taste-alike score | High | High |

---

*End of review.*
