# Vitis App Improvement Plan – FAANG-Quality Audit

**Date:** 2026  
**Scope:** End-to-end audit (frontend, backend, DB, auth, safety, design system)  
**Approach:** Rigorous review with actionable P0–P3 items, root causes, and acceptance criteria

---

## Executive Summary

1. **Critical:** Privacy settings (`activity_visibility`, `cellar_visibility`, `wishlist_visibility`) are not enforced server-side. RLS policies allow anyone (or any authenticated user) to read all activity, tastings, and cellar items. Users who set "Friends only" are still exposed in Global feed and via direct queries.

2. **Critical:** Delete account flow lacks re-auth and has UX gaps: no accidental-tap protection before opening the sheet, no cooldown, and destructive actions use bright red instead of muted. DeleteAccountView ignores dark mode.

3. **High:** `dev_accounts` table has RLS disabled. If deployed, this is a production safety risk.

4. **High:** Feed (`feed_with_details`, `feed_following`) and cellar/wishlist queries do not filter by privacy. All filtering is done client-side in ProfileViewModel, so API/DB consumers can bypass it.

5. **Medium:** Phone OTP flow has no resend cooldown UI, no Twilio-supported-country validation, and no SIM-swap/security guidance. SMS is handled by Supabase Auth (Twilio or configured provider).

---

## A) Fix Now (P0/P1)

### A1. Privacy not enforced in RLS – activity, cellar, wishlist

**Tags:** [DB/SQL], [RLS], [Safety], [Backend]  
**Severity:** P0  
**Impact:** Users who set "Friends only" for activity, cellar, or wishlist are exposed. Anyone can read all activity via `activity_feed` or `feed_with_details`, all cellar items via `cellar_items`, and all tastings. Client-side filtering in ProfileViewModel does not protect against direct API/DB access.

**Root cause:** RLS policies:
- `activity_feed`: `SELECT USING (true)`
- `tastings`: `tastings_select_public` `USING (true)`
- `cellar_items`: `cellar_items_select_all` `USING (auth.uid() IS NOT NULL)` (any auth user sees all rows)
- `feed_with_details` view inherits from `activity_feed` and `tastings` – no privacy filter
- `feed_following` RPC joins `feed_with_details` – no `activity_visibility` check

**Fix approach:**
1. Replace `activity_feed` SELECT policy with one that joins `profiles` and applies `activity_visibility`:
   - `everyone` → visible to all
   - `friends` → visible only if `is_mutual_friend(auth.uid(), activity_feed.user_id)` OR `auth.uid() = activity_feed.user_id`
2. Replace `cellar_items_select_all` with policies that:
   - For own rows: `user_id = auth.uid()`
   - For others: join `profiles`, check `cellar_visibility` / `wishlist_visibility` and `is_mutual_friend(auth.uid(), user_id)` where status = 'wishlist'
3. Update `feed_with_details` or create a new RPC `feed_global_filtered` that filters activity by `activity_visibility` before returning.
4. Update `feed_following` to filter by `activity_visibility` for each followed user.

**Acceptance criteria:**
- User A sets `activity_visibility = 'friends'`. User B (not mutual) cannot see A's activity in Global feed or via direct `activity_feed` SELECT.
- User A sets `wishlist_visibility = 'friends'`. User B (not mutual) cannot see A's wishlist via `cellar_items` SELECT.
- Unit tests or manual verification with two accounts.

---

### A2. Delete account: no re-auth, accidental tap, dark mode

**Tags:** [Auth], [Safety], [UI/UX], [Design system]  
**Severity:** P1  
**Impact:** Account can be deleted without re-authentication (session hijack risk). User can accidentally tap "Delete Account" and land on the confirmation sheet. DeleteAccountView uses light-theme-only colors in dark mode. Destructive button uses bright red instead of design-system muted red.

**Root cause:**
- `AuthService.deleteAccount()` calls `supabase.rpc("delete_current_user")` with no re-auth step.
- ProfileSettingsView: "Delete Account" row navigates directly to DeleteAccountView on tap (no intermediate confirmation).
- DeleteAccountView: uses `VitisTheme.background`, `Color(white: 0.97)`, `Color.red`; no `@Environment(\.colorScheme)`.

**Fix approach:**
1. Add re-auth before delete: prompt for password (email) or re-send OTP (phone), verify session, then call `delete_current_user`.
2. Add intermediate confirmation: tapping "Delete Account" shows an alert/sheet ("Are you sure? This action cannot be undone.") with Cancel and "Continue" before opening DeleteAccountView.
3. Add `@Environment(\.colorScheme)` to DeleteAccountView; use `VitisTheme.background(for:)`, `VitisTheme.secondaryElevated(for:)` for inputs, `VitisTheme.dangerMuted(for:)` for the delete button background.
4. Add "Data deletion consequences" copy: "Your profile, tastings, ratings, follows, and all associated data will be permanently removed. This cannot be undone."

**Acceptance criteria:**
- User must re-authenticate (password or OTP) before delete executes.
- Two-step flow: Settings → tap Delete Account → intermediate confirmation → DeleteAccountView → type DELETE → Delete.
- DeleteAccountView renders correctly in dark mode with muted destructive styling.
- Copy clearly explains consequences.

---

### A3. dev_accounts RLS disabled

**Tags:** [DB/SQL], [RLS], [Safety]  
**Severity:** P1  
**Impact:** If `dev_accounts` is ever used in production or exposed, any client could read/write all rows. Schema comment says "RLS disabled for test phase."

**Root cause:** `ALTER TABLE public.dev_accounts DISABLE ROW LEVEL SECURITY` in setup_schema.sql.

**Fix approach:**
1. Enable RLS: `ALTER TABLE public.dev_accounts ENABLE ROW LEVEL SECURITY;`
2. Add policy: `FOR ALL USING (false)` so no role can access in production, OR restrict to `auth.uid() IS NULL` and specific dev-only checks.
3. Better: gate usage behind `AppConstants.authRequired = false` and document that this table must never be used when auth is required. Add a migration that enables RLS and adds a deny-all policy for production safety.

**Acceptance criteria:**
- RLS enabled on `dev_accounts`.
- No anonymous or authenticated user can SELECT/INSERT/UPDATE/DELETE without explicit dev-only policy (or deny-all in production).

---

### A4. Feed and cellar ignore privacy at query level

**Tags:** [Backend], [RLS], [DB/SQL]  
**Severity:** P1  
**Impact:** Even if RLS is fixed, `feed_with_details` is a view that does not apply `activity_visibility`. FeedService fetches from this view directly. CellarService fetches by `user_id` and relies on RLS – but current RLS allows all. Feed_following RPC also does not filter by activity_visibility.

**Root cause:**
- `feed_with_details` selects from `activity_feed` and `tastings` with no join to `profiles` for visibility.
- `feed_following` joins `feed_with_details` with `follows` but does not filter by `profiles.activity_visibility`.

**Fix approach:**
1. Create RPC `feed_global_filtered(p_viewer_id uuid, p_limit int, p_offset int)` that:
   - Joins activity_feed with profiles
   - Filters: `activity_visibility = 'everyone'` OR (`activity_visibility = 'friends'` AND `is_mutual_friend(p_viewer_id, activity_feed.user_id)`)
2. Create RPC `feed_following_filtered` that applies the same visibility logic for each followed user's activity.
3. Update FeedService to call these RPCs instead of querying `feed_with_details` directly.
4. Ensure cellar RLS (from A1) is applied so CellarService queries automatically respect visibility.

**Acceptance criteria:**
- Global feed returns only activity from users with `activity_visibility = 'everyone'` or mutual-friend visibility.
- Following feed returns only activity from followed users who allow the viewer (everyone or mutual).
- Cellar/wishlist fetches for other users respect `cellar_visibility` and `wishlist_visibility`.

---

### A5. Notifications: mark all read without limit, no idempotency

**Tags:** [Backend], [DB/SQL], [Performance]  
**Severity:** P2  
**Impact:** `markAllAsRead` runs `UPDATE notifications SET is_read = true WHERE recipient_id = uid` with no limit. For users with thousands of notifications, this could be slow. No explicit idempotency (calling twice is fine, but no batching or rate consideration).

**Root cause:** `NotificationService.markAllAsRead()` executes a bulk UPDATE with no pagination or batch size.

**Fix approach:**
1. Add a batch limit (e.g., 500) and run multiple UPDATEs if needed, or use a single UPDATE with a subquery `WHERE id IN (SELECT id FROM notifications WHERE recipient_id = uid AND is_read = false LIMIT 500)` in a loop until no rows affected.
2. Alternatively, if Postgres handles large updates well, document and add a simple `LIMIT` to avoid runaway updates. Supabase/Postgres may handle this; verify with load testing.
3. Add idempotency: ensure `markAsRead(notificationId)` and `markAllAsRead` are safe to call multiple times (they are; UPDATE is idempotent).

**Acceptance criteria:**
- Mark all read completes in reasonable time for users with 1k+ unread notifications.
- Multiple rapid "Mark all as read" taps do not cause errors or duplicate work.

---

### A6. DeleteAccountView dark mode and destructive styling

**Tags:** [UI/UX], [Design system]  
**Severity:** P2  
**Impact:** In dark mode, DeleteAccountView shows light background, light input field, and bright red button. Inconsistent with design system (muted destructive red).

**Root cause:** Uses `VitisTheme.background`, `Color(white: 0.97)`, `Color.red`; no scheme-aware APIs.

**Fix approach:**
- Add `@Environment(\.colorScheme) private var colorScheme`
- Replace `VitisTheme.background` with `VitisTheme.background(for: colorScheme)`
- Replace input background with `VitisTheme.secondaryElevated(for: colorScheme)` or `VitisTheme.placeholderBackground(for: colorScheme)`
- Replace `Color.red` with `VitisTheme.dangerMuted(for: colorScheme)` for destructive button
- Replace `VitisTheme.secondaryText` with `VitisTheme.secondaryText(for: colorScheme)`
- Replace `VitisTheme.accent` with `VitisTheme.accent(for: colorScheme)`

**Acceptance criteria:**
- DeleteAccountView matches dark mode tokens (background #0E0F11, card #16181C, destructive muted red).
- Destructive actions follow design system (muted red, not accent red).

---

## B) Add / Improve Next (P2+)

### B1. Phone OTP: resend cooldown, country support, SIM swap note

**Tags:** [Auth], [International phone], [UI/UX], [Edge cases]  
**Severity:** P2  
**Impact:** Users can spam "Send code" causing rate limits with no clear feedback. Country picker includes all countries; Supabase/Twilio may not support all. No guidance on SIM swap risk for high-value accounts.

**Root cause:**
- PhoneEntryView and CodeEntryView have no client-side resend cooldown (Supabase may rate limit server-side, but UX is unclear).
- Countries.json is a full list; no validation against Supabase/Twilio supported regions.
- No security copy in phone flows.

**Fix approach:**
1. Add resend cooldown (e.g., 60 seconds) with disabled button and countdown label. Use `AuthService.sendOTP` timestamp stored in AuthStore or ViewState.
2. Document Supabase SMS provider (Twilio or other) supported countries. Optionally filter CountriesStore to supported list, or show a warning for unsupported countries.
3. Add optional helper text: "If you recently changed your phone carrier, your number may not receive codes immediately."
4. Validate E.164 format before sending (already done via PhoneNumberFormatter; ensure edge cases are covered).

**Acceptance criteria:**
- Resend is disabled for 60s after send, with countdown displayed.
- Unsupported country shows a warning or is excluded from picker (configurable).
- SIM-swap note appears in change-phone flow or FAQ.

---

### B2. Settings: Separate Sign Out from Delete Account, add confirmation step

**Tags:** [UI/UX], [Safety]  
**Severity:** P2  
**Impact:** Sign Out and Delete Account are in the same "Danger zone" section. Tapping Delete Account opens the sheet immediately; accidental tap could start the flow.

**Root cause:** ProfileSettingsView groups both in one section; Delete Account row directly sets `showDeleteAccount = true`.

**Fix approach:**
1. Split sections: "Sign Out" in its own section; "Delete Account" in "Danger zone" with distinct visual separation.
2. Add confirmation alert before sheet: "Permanently delete your account? This cannot be undone." with "Cancel" and "Continue" – only "Continue" opens DeleteAccountView.
3. Ensure Delete Account row has `buttonStyle` that prevents accidental activation (e.g., not a large tappable area without confirmation).

**Acceptance criteria:**
- Sign Out and Delete Account are in separate sections.
- Tapping Delete Account shows an alert first; only "Continue" opens the typed-confirmation sheet.

---

### B3. Dark mode consistency across auth and onboarding

**Tags:** [UI/UX], [Design system]  
**Severity:** P2  
**Impact:** PhoneEntryView, EmailLoginSheet, CodeEntryView, DeleteAccountView, and several onboarding steps use `VitisTheme.background` or `Color(white: 0.97)` without `colorScheme`. In dark mode these screens look inconsistent.

**Root cause:** Views use non-scheme-aware colors.

**Fix approach:**
- Audit all auth, onboarding, and settings views for `VitisTheme.background`, `Color(white:`, `Color.red`, `.primary`, etc.
- Add `@Environment(\.colorScheme)` and replace with `VitisTheme.*(for: colorScheme)` or `VitisTheme.textPrimary(for:)` etc.
- Use `VitisTheme.background(for:)`, `VitisTheme.secondaryElevated(for:)`, `VitisTheme.dangerMuted(for:)` consistently.

**Acceptance criteria:**
- All auth, onboarding, settings, and delete flows render correctly in dark mode with design-system tokens.

---

### B4. Observability: audit trail for account changes

**Tags:** [Analytics], [Backend], [Safety]  
**Severity:** P2  
**Impact:** No server-side audit log for account deletion, phone change, or email change. Hard to investigate abuse or user reports.

**Root cause:** No audit table or logging in `delete_current_user` or Supabase Auth hooks.

**Fix approach:**
1. Create `audit_log` table: `id`, `user_id`, `event_type` (e.g., 'account_deleted', 'phone_changed', 'email_changed'), `metadata` (jsonb), `created_at`.
2. Add Supabase Auth hooks or Edge Function to log these events, or call an RPC from the app before/after critical operations (with care for timing and failure cases).
3. Ensure audit table has RLS: only service role or admin can read.

**Acceptance criteria:**
- Account deletion, phone change, and email change events are logged with timestamp and user id.
- Logs are queryable by admins for support/investigation.

---

### B5. Supabase vs Twilio: SMS strategy

**Tags:** [Backend], [Auth], [International phone]  
**Severity:** P3  
**Impact:** App uses Supabase Auth for phone OTP. Supabase delegates SMS to Twilio (or MessageBird, etc.) via Dashboard config. No app-level Twilio integration.

**Root cause:** Architecture uses Supabase Auth; Twilio is provider, not direct dependency.

**Fix approach:**
1. **Recommendation: Keep Supabase Auth.** Moving to direct Twilio adds operational complexity (managing API keys, webhooks, custom OTP verification). Supabase handles rate limiting, retries, and provider config.
2. Document in README/SETUP: "Phone OTP uses Supabase Auth. Configure your SMS provider (Twilio recommended) in Supabase Dashboard → Authentication → Providers → Phone."
3. Cross-reference Countries.json with Twilio supported countries (https://www.twilio.com/docs/phone-numbers/supported-countries). Optionally add a build script or doc that lists supported regions.
4. Cost: Supabase includes limited free SMS; beyond that, Twilio pricing applies. Document expected cost for target regions.

**Acceptance criteria:**
- Documentation clearly states SMS provider configuration and supported regions.
- No unnecessary migration to direct Twilio unless there is a specific deliverability or cost issue.

---

### B6. Feed pagination and image caching

**Tags:** [Performance], [Backend]  
**Severity:** P3  
**Impact:** Feed uses `.range(from: offset, to: offset + limit - 1)` for pagination; good. AsyncImage has no explicit cache policy; relies on URLSession default cache, which may evict aggressively.

**Root cause:** No custom image cache or cache policy.

**Fix approach:**
1. Consider Nuke or Kingfisher for consistent image caching, or use `URLCache` with increased capacity.
2. Add `FeedCache` version bump when schema or API changes (already exists for feed items).
3. Verify feed indexes: `idx_activity_feed_user_created`, `idx_activity_feed_created` – sufficient for pagination.

**Acceptance criteria:**
- Feed scroll remains smooth with 50+ items.
- Wine label images load quickly on revisit without refetch when possible.

---

### B7. Accessibility audit

**Tags:** [Accessibility], [UI/UX]  
**Severity:** P3  
**Impact:** Some buttons and interactive elements may lack `accessibilityLabel` or `accessibilityHint`. Feed items, cellar rows, and action buttons should be fully navigable by VoiceOver.

**Root cause:** Partial coverage; not all views audited for a11y.

**Fix approach:**
1. Run Accessibility Inspector on key flows: Feed, Cellar, Profile, Settings, Delete Account, Phone entry.
2. Add `accessibilityLabel` and `accessibilityHint` where missing.
3. Ensure minimum touch targets (44x44 pt) for all tappable elements.
4. Verify Dynamic Type support where applicable.

**Acceptance criteria:**
- VoiceOver can navigate all critical flows without dead ends.
- Minimum touch targets met.
- No Accessibility Inspector errors for P0/P1 screens.

---

### B8. Notification duplicate prevention

**Tags:** [Backend], [DB/SQL]  
**Severity:** P3  
**Impact:** `createLikeNotification` and `createCommentNotification` are fire-and-forget. If called twice (e.g., retry), duplicate notifications could be created. Unique constraint would prevent this.

**Root cause:** No unique constraint on (recipient_id, actor_id, type, post_id) or similar.

**Fix approach:**
1. Add unique constraint: `UNIQUE (recipient_id, actor_id, type, post_id)` for like; for comment, include `comment_id` in uniqueness.
2. Use `INSERT ... ON CONFLICT DO NOTHING` or handle duplicate key in application.
3. Ensure idempotent behavior: multiple likes from same user on same post should not create multiple notifications.

**Acceptance criteria:**
- Same actor liking the same post twice does not create duplicate notifications.
- Same actor commenting twice creates two notifications (correct behavior).

---

## Top 10 Quick Wins (1–2 days)

1. **DeleteAccountView dark mode** – Add `colorScheme`, use `VitisTheme.*(for:)` and `dangerMuted` for button. [~1 hour]

2. **Settings: confirmation alert before Delete Account sheet** – Add `.confirmationDialog` or `alert` with "Continue" before `showDeleteAccount = true`. [~30 min]

3. **Phone resend cooldown** – Add 60s cooldown with countdown in CodeEntryView/AuthStore. [~2 hours]

4. **Replace em dashes** – Ensure no "—" in UI strings; use "-" per design spec. [~30 min]

5. **Delete account: add "Data deletion consequences" copy** – Expand explanationSection with explicit list. [~15 min]

6. **Auth views dark mode** – PhoneEntryView, CodeEntryView, EmailLoginSheet: add `colorScheme` and scheme-aware colors. [~2 hours]

7. **Split Danger zone** – Move Sign Out to separate section from Delete Account. [~15 min]

8. **dev_accounts RLS** – Enable RLS, add `USING (false)` policy as safety net. [~30 min]

9. **Notification unique constraint** – Add `UNIQUE (recipient_id, actor_id, type, post_id)` for likes; use ON CONFLICT DO NOTHING. [~1 hour]

10. **Document SMS/Twilio setup** – Add section to SETUP.md: Supabase Phone provider config, Twilio supported countries link. [~30 min]

---

## Appendix: Explicit Audit Checklist

| Area | Status | Notes |
|------|--------|-------|
| Dark mode tokens | ✅ Applied | #0E0F11, #16181C, #7A1E2D, #B89B5C |
| Dark mode consistency | ⚠️ Partial | DeleteAccountView, auth views, onboarding need scheme-aware colors |
| Card system | ✅ Unified | cardCornerRadius, cardPadding, cardSpacingVertical |
| Tab bar | ✅ Updated | Lighter, transparent in dark |
| Settings IA | ✅ Good | Profile, Account, Privacy, Preferences, Danger zone |
| Danger zone | ⚠️ Needs work | Sign Out + Delete together; no pre-sheet confirmation |
| Delete account | ⚠️ Incomplete | Typed confirm ✅; re-auth ❌; cooldown ❌; consequences copy ❌ |
| Phone country picker | ⚠️ Unknown | Full Countries.json; Twilio support not validated |
| Phone E.164 | ✅ | PhoneNumberFormatter.toE164 |
| Phone resend | ❌ | No cooldown UI |
| RLS activity_visibility | ❌ | Not enforced |
| RLS cellar_visibility | ❌ | Not enforced |
| RLS wishlist_visibility | ❌ | Not enforced |
| feed_with_details | ❌ | No privacy filter |
| feed_following | ❌ | No privacy filter |
| Mark all read | ⚠️ | No batch limit; verify performance |
| dev_accounts RLS | ❌ | Disabled |
| Cascading deletes | ✅ | ON DELETE CASCADE on FKs |
| Feed indexes | ✅ | idx_activity_feed_created, idx_activity_feed_user_created |
| Analytics | ✅ | PostHog config |
| Audit trail | ❌ | No server-side audit for account changes |
