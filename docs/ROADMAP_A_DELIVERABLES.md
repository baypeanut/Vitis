# Roadmap A (MVP + Growth) - Deliverables

## PR1: Reliability Hygiene

### Files Changed
| File | Change |
|------|--------|
| ProfileViewModel.swift | Replaced try? with do/catch for tastings and taste profile; use ErrorMessage.userFacing(for:); preserve last-known-good |
| PhotoStepView.swift | Replaced empty catch with Logger.error |
| EditProfileView.swift | Replaced empty catch with Logger.error |
| FollowersFollowingView.swift | Replaced empty catch with Logger.error + errorMessage; added error banner |
| NotificationsView.swift | Replaced empty catch with Logger.error + errorMessage |
| AuthService.swift | Replaced Turkish error strings with English |
| OnboardingService.swift | Replaced Turkish comment with English |
| OnboardingViewModel.swift | Replaced Turkish "Lütfen tüm..." with "Please fill in all required fields." |
| AuthLoginView.swift | Replaced Turkish validation messages with English |
| ForgotPasswordView.swift | Replaced Turkish validation message with English |

### Manual Test Steps
- [ ] Profile load: Simulate network failure; verify error message appears, existing data preserved
- [ ] Photo picker: Select invalid/corrupt image; verify no crash, Logger logs
- [ ] Followers/Following: Simulate network failure; verify error banner appears
- [ ] Notifications: Simulate network failure; verify error message appears
- [ ] Auth: Sign up with duplicate username; verify English error message

---

## PR2: Analytics + Growth Loop

### Files Changed
| File | Change |
|------|--------|
| Config/Secrets.xcconfig.example | Created template for PostHog keys |
| Config/Vitis.xcconfig | Created; includes Secrets.xcconfig |
| Config/Secrets.xcconfig | Gitignored; user creates from example |
| Core/AnalyticsConfig.swift | Reads PostHog keys from Info.plist |
| Info.plist | Added PostHogAPIKey, PostHogHost (from build settings) |
| project.pbxproj | Added PostHog package, Vitis.xcconfig, Run Script to copy Secrets |
| AnalyticsService.swift | PostHog setup, identify, reset, track events |
| VitisApp.swift | AnalyticsService.setup() in init |
| ProfileStore.swift | identify(userId) on load; reset() on clearForSignOut |
| RootView.swift | reset() on didSignOut |
| OnboardingFlowView.swift | signupStarted() on appear |
| OnboardingViewModel.swift | signupCompleted() after complete |
| AddWineSheet.swift | firstTastingStarted(), firstTastingSaved() |
| FeedViewModel.swift | wishlistSaveFromUser when adding from feed |
| ProfileViewModel.swift | wishlistSaveFromUser when adding from other's wishlist |
| UserProfileView.swift | profileView(), follow() |
| ProfileView.swift | profileView() |
| FollowersFollowingView.swift | follow() |
| WantToTryView.swift | wantToTryOpened() |
| SocialService.swift | fetchSuggestedUsersToFollow() |
| FeedView.swift | Following empty state with "People you might like" list |

### PostHog Sanity Check
1. Create `Config/Secrets.xcconfig` from example; paste real PostHog API key
2. Run app; complete one flow (e.g. add wine, view feed)
3. In PostHog Dashboard: Activity → Live Events
4. Verify events: `feed_view`, `first_tasting_started`, `first_tasting_saved`, `tasting_create`
5. Sign out; verify `$identify` reset (anonymous user)
6. Sign in; verify `$identify` with user id
7. Tap "Want to Try" from profile; verify `want_to_try_opened`
8. Save wine from another user's wishlist; verify `wishlist_save_from_user`

### Manual Test Steps
- [ ] First launch: Carousel or main tabs; verify feed_view in PostHog
- [ ] Add wine: Verify first_tasting_started, first_tasting_saved (if first), tasting_create
- [ ] Follow user: Verify follow event
- [ ] Like: Verify like event
- [ ] Wishlist from feed: Verify wishlist_add, wishlist_save_from_user (when from other's post)
- [ ] Following empty: Verify "People you might like" list appears; tap opens profile

---

## PR3: Onboarding + Premium Slot

### Files Changed
| File | Change |
|------|--------|
| OnboardingCarouselView.swift | Created; 3-screen carousel (Log wines, Discover via friends, Build palate) |
| RootView.swift | Carousel as first screen; onAddFirstTasting opens AddWineSheet |
| ProfileContentView.swift | Taste Profile Insights locked card |
| TasteProfileInsightsLockedSheet.swift | Created; locked state sheet |

### Manual Test Steps
- [ ] First launch: Carousel appears (3 screens, Skip, Continue, "Add your first tasting")
- [ ] Skip: Goes to main tabs (dev) or sign-up (auth required)
- [ ] Add your first tasting (dev): Opens AddWineSheet over main tabs
- [ ] Profile → Taste tab: "Taste Profile Insights" card with lock icon
- [ ] Tap card: Sheet opens "Coming soon"
- [ ] Reset: Delete app or clear UserDefaults "vitis_has_seen_carousel" to replay carousel

---

## Manual Steps Required

1. **PostHog**: Before first build, run:
   ```bash
   cp Vitis/Config/Secrets.xcconfig.example Vitis/Config/Secrets.xcconfig
   ```
   Then paste your PostHog API key in `Secrets.xcconfig` (replace `phc_replace_me`).

2. **Supabase**: Ensure `setup_schema.sql` is run if setting up fresh.

3. **No em dashes** were added in any new UI strings.
