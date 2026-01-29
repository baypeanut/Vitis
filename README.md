# Vitis

A wine logging and rating iOS app built with SwiftUI and Supabase. Users search for wines, rate them (1.0-10.0), add optional tasting notes, and share their tastings in a social feed.

---

## Table of Contents

1. [What is Vitis?](#what-is-vitis)
2. [Tech Stack](#tech-stack)
3. [Architecture Overview](#architecture-overview)
4. [Project Structure](#project-structure)
5. [Setup Instructions](#setup-instructions)
6. [Database Schema](#database-schema)
7. [Key Features & User Flows](#key-features--user-flows)
8. [Code Structure Deep Dive](#code-structure-deep-dive)
9. [Running & Debugging](#running--debugging)
10. [Common Tasks](#common-tasks)
11. [Important Concepts](#important-concepts)

---

## What is Vitis?

Vitis is an iOS app for wine enthusiasts to:
- **Log wines**: Search for wines (via Open Food Facts API), rate them 1.0-10.0, add optional tasting notes
- **Track history**: View your tasting history in "My Cellar" with ratings, notes, and timestamps
- **Social feed**: See what wines others have tasted, cheer (like) and comment on their posts
- **Profile**: View your own and others' profiles with tasting history

**Design philosophy**: Quiet Luxury - minimal, clean UI with white backgrounds, burgundy (#4A0E0E) accents, serif fonts for wine names, lots of whitespace.

---

## Tech Stack

- **Frontend**: SwiftUI (iOS 17+)
- **Backend**: Supabase (PostgreSQL database, Auth, Storage)
- **Wine Search**: Open Food Facts API (world.openfoodfacts.org)
- **Architecture**: MVVM (Model-View-ViewModel)
- **State Management**: SwiftUI `@Observable` / `@State` / `@Binding`
- **Networking**: Supabase Swift SDK (PostgREST client)

---

## Architecture Overview

### MVVM Pattern

- **Models** (`Vitis/Models/`): Data structures (Wine, Tasting, Profile, FeedItem, etc.)
- **Views** (`Vitis/Features/`): SwiftUI views (CellarView, FeedView, ProfileView, etc.)
- **ViewModels** (`*ViewModel.swift`): Business logic, state management, API calls
- **Services** (`Vitis/Services/`): API clients (TastingService, FeedService, AuthService, etc.)

### Data Flow

```
User Action → View → ViewModel → Service → Supabase API → Database
                ↓
            Update State → View Re-renders
```

### Key Services

- **TastingService**: Create/fetch tastings (wine logs with rating + notes)
- **FeedService**: Fetch social feed (only "had wine" activities)
- **AuthService**: Authentication, profile management
- **WineService**: Upsert wines from Open Food Facts
- **WineSearchService**: Search wines via OFF API
- **SocialService**: Likes (Cheers), comments, follows

---

## Project Structure

```
Vitis/
├── Vitis/
│   ├── Core/                    # App-wide config
│   │   ├── AppConstants.swift   # Bundle ID, auth flags, debug UUIDs
│   │   └── SupabaseConfig.swift  # Supabase URL + anon key (gitignored)
│   │
│   ├── Models/                  # Data models
│   │   ├── Wine.swift           # Wine entity
│   │   ├── Tasting.swift        # Tasting log (rating + notes)
│   │   ├── Profile.swift        # User profile
│   │   ├── FeedItem.swift       # Feed display model
│   │   └── ...
│   │
│   ├── Services/                # API clients
│   │   ├── TastingService.swift # Create/fetch tastings
│   │   ├── FeedService.swift    # Fetch feed
│   │   ├── AuthService.swift    # Auth + profile
│   │   ├── WineService.swift    # Upsert wines
│   │   └── ...
│   │
│   ├── Features/                # Feature modules
│   │   ├── Cellar/              # My Cellar (tasting history)
│   │   │   ├── CellarView.swift
│   │   │   ├── CellarViewModel.swift
│   │   │   ├── AddWineSheet.swift      # Multi-step: Search → Rate → Notes
│   │   │   ├── TastingRateView.swift   # Rating slider
│   │   │   └── NotesSelectView.swift   # Notes chips
│   │   │
│   │   ├── Social/              # Social feed
│   │   │   ├── FeedView.swift
│   │   │   ├── FeedViewModel.swift
│   │   │   ├── FeedItemView.swift
│   │   │   └── CommentSheetView.swift
│   │   │
│   │   ├── Profile/             # User profiles
│   │   │   ├── ProfileView.swift
│   │   │   ├── ProfileViewModel.swift
│   │   │   └── ...
│   │   │
│   │   ├── Auth/                # Authentication
│   │   │   └── ...
│   │   │
│   │   └── Root/                # Root navigation
│   │       └── RootView.swift   # Auth gate + TabView
│   │
│   ├── Themes/                  # Design system
│   │   └── VitisTheme.swift     # Colors, fonts, timestamps
│   │
│   └── VitisApp.swift           # App entry point
│
├── supabase/
│   ├── setup_schema.sql         # Complete database schema (run once)
│   └── migrations/              # Incremental migrations
│       └── 20250228000000_tastings.sql
│
└── docs/
    └── SETUP.md                 # Collaboration setup guide
```

---

## Setup Instructions

### Prerequisites

- macOS with Xcode 15+ (iOS 17+ target)
- Supabase account (free tier works)
- Git

### Step 1: Clone the Repository

```bash
git clone https://github.com/baypeanut/Vitis.git
cd Vitis
```

### Step 2: Open in Xcode

1. Open `Vitis.xcodeproj` in Xcode
2. Wait for Swift Package Manager to resolve dependencies (Supabase SDK, etc.)
   - If it doesn't auto-resolve: **File → Packages → Resolve Package Versions**

### Step 3: Configure Supabase

1. **Create Supabase project** (if you don't have one):
   - Go to [supabase.com](https://supabase.com) → New Project
   - Note your **Project URL** and **anon (public) key**

2. **Set up config file**:
   ```bash
   cd Vitis/Core
   cp SupabaseConfig.example.swift SupabaseConfig.swift
   ```
   Open `SupabaseConfig.swift` and replace:
   - `YOUR_PROJECT_REF` → Your Supabase project URL (e.g., `https://xxxxx.supabase.co`)
   - `YOUR_ANON_KEY` → Your anon public key

   **Important**: `SupabaseConfig.swift` is gitignored. Never commit it.

### Step 4: Set Up Database

1. Open Supabase Dashboard → **SQL Editor**
2. Run `supabase/setup_schema.sql` (copy entire file, paste, Run)
   - This creates all tables, views, RLS policies, functions
   - Creates `tastings` table, updates `activity_feed`, `feed_with_details` view

3. **Verify tables exist**:
   - Go to **Table Editor** → You should see: `wines`, `tastings`, `activity_feed`, `profiles`, `likes`, `comments`, `follows`, etc.

### Step 5: Run the App

1. In Xcode, select **Vitis** scheme and **iPhone Simulator** (e.g., iPhone 17)
2. Press **Cmd+R** (or click Run)
3. App should launch and show main tabs (Cellar, Social, Profile)

### Step 6: Test the Flow

1. **Add a wine**:
   - Tap **Cellar** tab → Tap **+** button
   - Search for a wine (e.g., "chardonnay")
   - Select a wine → Rate it (1.0-10.0 slider) → Add notes (optional) → Tap **Cheers**
   - Wine should appear in "My Cellar" with rating, notes, timestamp

2. **Check feed**:
   - Tap **Social** tab → Should show "had wine" posts
   - Tap **Cheers** or **Comment** to interact

3. **View profile**:
   - Tap **Profile** tab → See your tasting history in "Recent Activity"

---

## Database Schema

### Core Tables

#### `public.wines`
- Wine catalog (from Open Food Facts)
- Columns: `id`, `name`, `producer`, `vintage`, `variety`, `region`, `label_image_url`, `category`, `off_code`
- No RLS (public read)

#### `public.tastings` ⭐ **Main table for wine logs**
- User's wine tasting logs
- Columns:
  - `id` (UUID, PK)
  - `user_id` (UUID, FK → auth.users)
  - `wine_id` (UUID, FK → wines)
  - `rating` (double, 1.0-10.0)
  - `note_tags` (text[], optional)
  - `created_at` (timestamptz)
  - `source` (text, nullable)
- RLS: Users can manage own tastings; public read for feed

#### `public.activity_feed`
- Social feed activities
- Columns: `id`, `user_id`, `activity_type` (`'had_wine'`, `'rank_update'`, `'new_entry'`, `'duel_win'`), `wine_id`, `target_wine_id`, `content_text`, `created_at`
- RLS: Public read, users insert own
- **Note**: Feed now only shows `activity_type = 'had_wine'`

#### `public.profiles`
- User profiles
- Columns: `id` (matches auth.users.id), `username`, `full_name`, `avatar_url`, `bio`, `instagram_url`, taste snapshot fields, `weekly_goal`
- RLS: Public read, users update own

#### `public.likes` / `public.comments`
- Social interactions (Cheers/Likes and Comments on feed items)
- Reference `activity_feed.id`

#### `public.follows`
- User follows (follower_id → followed_id)

### Views

#### `public.feed_with_details`
- Joined view: `activity_feed` + `profiles` + `wines` + `tastings`
- Includes: `tasting_note_tags`, `tasting_rating`, `wine_region`, `wine_category`
- Used by `FeedService` to fetch feed

### Functions

#### `public.feed_following(p_follower_id, p_limit, p_offset)`
- Returns feed items from users you follow
- Filters: `WHERE activity_type = 'had_wine'`

### RLS (Row-Level Security)

- **Authenticated users**: Can read/write own data (tastings, profiles, etc.)
- **Public read**: Feed, profiles, tastings (for social feed)
- **Dev mock**: When `auth.uid() IS NULL`, allows operations for a developer-specific UUID (configured in `setup_schema.sql`). Each developer should use their own UUID from their Supabase project.

---

## Key Features & User Flows

### 1. Add Wine & Rate Flow

**Path**: Cellar → + → Search → Select → Rate → Notes → Save

1. User taps **+** in Cellar tab
2. `AddWineSheet` opens → Search wines (OFF API)
3. User selects a wine → `WineService.upsertFromOFF` creates/updates wine in DB
4. `TastingRateView` shows:
   - Wine info (producer, name, vintage, region)
   - Rating slider (1.0-10.0, step 0.1)
   - Wine glass icon as thumb (tinted by category: red/white/rose/sparkling)
5. User taps **Next** → `NotesSelectView` shows:
   - Category-based chips (e.g., Red: "Blackberry", "Cherry", "Vanilla", etc.)
   - User selects 0+ notes
   - **Cheers** button (saves) or **Skip** (saves without notes)
6. `TastingService.createTasting`:
   - Inserts row into `tastings` table
   - Inserts row into `activity_feed` (`activity_type = 'had_wine'`, notes in `content_text`)
7. Sheet closes → Cellar refreshes → New tasting appears at top

### 2. Social Feed Flow

**Path**: Social tab → Global/Following tabs → Feed items

1. `FeedView` loads → `FeedViewModel.refresh()`
2. `FeedService.fetchGlobal()` or `fetchFollowing()`:
   - Queries `feed_with_details` view
   - Filters: `WHERE activity_type = 'had_wine'`
   - Orders by `created_at DESC`
3. For each item, fetches:
   - Like counts (`SocialService.fetchLikeCounts`)
   - Comment counts (`SocialService.fetchCommentCounts`)
   - User's liked status (`SocialService.fetchLikedActivityIDs`)
4. `FeedItemView` renders:
   - Statement: "Mert had 2019 Chardonnay." (name in serif, burgundy)
   - **Rating and country**: "8.0 · Chile" (left-aligned, rating in burgundy)
   - **Notes**: "Vanilla, Floral" (if available, left-aligned, gray)
   - **Date/time**: "Jan 29 · 9:53 AM" (right-aligned, gray)
   - Wine thumbnail (icon tinted by category: red/white/rose/sparkling)
   - **Cheers** and **Comment** buttons
5. User taps **Cheers** → `SocialService.toggleLike` → Updates local state
6. User taps **Comment** → `CommentSheetView` opens → Shows comments with timestamps

### 3. My Cellar Flow

**Path**: Cellar tab → List of tastings

1. `CellarView` loads → `CellarViewModel.load()`
2. `TastingService.fetchTastings(userId:)`:
   - Queries `tastings` table
   - Joins `wines` for wine details
   - Orders by `created_at DESC`
3. Each row shows:
   - Producer (serif, gray)
   - Wine name (serif, black)
   - Vintage (if available)
   - Rating (e.g., "8.5") + Notes (e.g., "· Berry, vanilla")
   - Timestamp (e.g., "Jan 28 · 9:42 PM")
4. Swipe to delete → `TastingService.deleteTasting` → Removes from list

### 4. Profile Recent Activity Flow

**Path**: Profile tab → Recent Activity tab

1. `ProfileView` loads → `ProfileViewModel.load()`
2. `TastingService.fetchTastings(userId:)` → `recentTastings`
3. `ProfileContentView` renders:
   - "Mert had 2019 Chardonnay."
   - Rating + notes line (e.g., "8.0 · Vanilla, Floral")
   - Timestamp (e.g., "Jan 29 · 9:53 AM")

---

## Code Structure Deep Dive

### Models

#### `Tasting.swift`
```swift
struct Tasting: Identifiable {
    let id: UUID
    let userId: UUID
    let wineId: UUID
    let rating: Double          // 1.0-10.0
    let noteTags: [String]?     // Optional array
    let createdAt: Date
    let source: String?         // "search" or future "barcode"
    let wine: Wine              // Embedded wine details
}
```

#### `Wine.swift`
```swift
struct Wine: Identifiable {
    let id: UUID
    let name: String
    let producer: String
    let vintage: Int?
    let variety: String?
    let region: String?
    let labelImageURL: String?
    let category: String?       // "Red", "White", "Rose", "Sparkling"
}
```

#### `FeedItem.swift`
- Display model for feed
- Contains: user info, wine info, activity type, notes (from `contentText`), rating (`tastingRating`), region (`wineRegion`), category (`wineCategory`), cheers/comment counts
- Properties:
  - `tastingRating: Double?` - Rating (1.0-10.0) for `had_wine` activities
  - `wineRegion: String?` - Wine country/region (e.g., "Chile", "Tuscany")
  - `wineCategory: String?` - Wine category ("Red", "White", "Rose", "Sparkling") - used for icon tinting

### Services

#### `TastingService`
- **`createTasting(userId:wineId:rating:noteTags:source:)`**:
  - Inserts into `tastings` table
  - Inserts into `activity_feed` (`had_wine`)
  - Returns `Tasting` with embedded `Wine`
- **`fetchTastings(userId:limit:offset:)`**:
  - Queries `tastings` + `wines` join
  - Returns `[Tasting]` ordered by `created_at DESC`

#### `FeedService`
- **`fetchGlobal(limit:offset:)`**:
  - Queries `feed_with_details` view
  - Filters: `activity_type = 'had_wine'`
  - Returns `[FeedItem]`
- **`fetchFollowing(limit:offset:)`**:
  - Calls `feed_following` RPC function
  - Returns feed from users you follow (filtered to `had_wine`)

#### `WineService`
- **`upsertFromOFF(product:)`**:
  - Calls `upsert_wine_from_off` RPC
  - Creates/updates wine in `wines` table
  - Returns `Wine`

#### `WineSearchService`
- **`search(query:)`**:
  - Calls Open Food Facts API (`world.openfoodfacts.org/cgi/search.pl`)
  - Returns `[OFFProduct]`

### ViewModels

#### `CellarViewModel`
- **State**: `tastings: [Tasting]`, `isLoading`, `errorMessage`, `needsAuth`, `currentUserId`
- **Methods**:
  - `load()`: Fetches tastings via `TastingService`
  - `removeTasting(_:)`: Deletes tasting

#### `FeedViewModel`
- **State**: `items: [FeedItem]`, `tab` (global/following), `isLoading`, `errorMessage`, `currentUserId`
- **Methods**:
  - `refresh()`: Fetches feed, enriches with likes/comments
  - `cheer(_:)`: Toggles like
  - `statementParts(for:)`: Builds "Mert had X." statement

#### `AddWineViewModel`
- **State**: `query`, `results: [OFFProduct]`, `isLoading`, `isUpserting`
- **Methods**:
  - `search()`: Debounced OFF search
  - `upsert(product:)`: Creates/updates wine

### Views

#### `CellarView`
- Header: "My Cellar" + **+** button
- List of `Tasting` rows (rating, notes, timestamp)
- Empty state: "Your cellar is empty. Add wines you've tasted."
- Swipe to delete

#### `AddWineSheet`
- Multi-step flow via `TastingFlowStep` enum:
  - `.search`: Search bar + results list
  - `.rating(Wine)`: `TastingRateView`
  - `.notes(Wine, Double)`: `NotesSelectView`
- On save: Calls `TastingService.createTasting`

#### `TastingRateView`
- Wine info display
- Custom slider: Wine glass icon thumb, category-tinted
- Rating value display (e.g., "8.5")
- **Next** button

#### `NotesSelectView`
- Chip-based selection
- Category-based notes (`TastingNotes.notesForCategory`)
- **Cheers** button (wine glass icon) + **Skip**

#### `FeedView`
- Global/Following tabs
- List of `FeedItemView`
- Pull-to-refresh
- Realtime subscription (new activities)

#### `FeedItemView`
- Statement: "Mert had 2019 Chardonnay." (name in serif, burgundy)
- For `had_wine` activities, shows detailed info:
  - **Rating and country**: "8.0 · Chile" (rating in burgundy, country in gray)
  - **Notes**: "Vanilla, Floral" (if available, in gray)
  - **Date/time**: "Jan 29 · 9:53 AM" (right-aligned, gray)
- Wine thumbnail:
  - Wine glass icon (if no label image) tinted by category:
    - Red: dark red tint
    - White: light yellow/beige tint
    - Rose: light pink tint
    - Sparkling: light gray tint
  - Typography: Producer (serif, gray), Wine name (serif, black), Vintage (serif, gray)
- **Cheers** / **Comment** buttons

---

## Running & Debugging

### Run in Simulator

1. Open Xcode → Select **Vitis** scheme
2. Select simulator (e.g., **iPhone 17**)
3. Press **Cmd+R** or click **Run**

### Debug Mode

- **Auth bypass**: `AppConstants.authRequired = false` (default)
  - App skips login, uses dev account from `DevSignupService` or real session
- **Dev mock user**: Each developer configures their own UUID in `setup_schema.sql`
  - RLS policies allow the configured UUID when `auth.uid() IS NULL`
  - No hardcoded UUIDs in code - each developer uses their own Supabase user

### Common Issues

**"Invalid Supabase URL or anon key"**
- Check `SupabaseConfig.swift` exists and has correct values
- Verify Supabase project is active

**"new row violates row-level security policy"**
- Ensure `setup_schema.sql` was run (RLS policies must exist)
- Check if you're using dev mock user correctly
- Verify `tastings` table has `tastings_select_public` policy

**Feed is empty**
- Check `activity_feed` table has rows with `activity_type = 'had_wine'`
- Verify `feed_with_details` view exists and joins correctly
- Check `FeedService.fetchGlobal` filters correctly

**Rating/country not showing in feed**
- Verify `feed_with_details` view includes `tasting_rating` and `wine_region` columns
- Check `FeedRowPayload` has `tastingRating` and `wineRegion` properties
- Ensure `FeedItem.from(row:)` maps these correctly
- Verify `FeedItemView.hadWineDetails` is rendered for `activityType == .hadWine`

**Icon tint not working**
- Check `FeedItem.wineCategory` is populated from `FeedRowPayload.wineCategory`
- Verify `FeedItemView.categoryColor(for:)` function handles category strings correctly
- Ensure wine glass icon uses `categoryColor(for: category)` instead of fixed color

**Build errors**
- Clean build folder: **Product → Clean Build Folder** (Cmd+Shift+K)
- Reset packages: **File → Packages → Reset Package Caches**
- Resolve packages: **File → Packages → Resolve Package Versions**

---

## Common Tasks

### Add a New Feature

1. **Database**: Add table/column in `setup_schema.sql` + migration
2. **Model**: Create model in `Vitis/Models/`
3. **Service**: Create service in `Vitis/Services/` (API calls)
4. **ViewModel**: Create ViewModel (state + business logic)
5. **View**: Create SwiftUI view
6. **Wire up**: Add to navigation/routing

### Update Database Schema

1. Edit `supabase/setup_schema.sql`
2. Create migration: `supabase/migrations/YYYYMMDDHHMMSS_description.sql`
3. Run migration in Supabase SQL Editor
4. Update app models/services if needed

### Debug API Calls

- Check Supabase Dashboard → **Logs** → **API Logs**
- Check **Table Editor** to see if rows were inserted
- Use `print()` statements in ViewModels (remove for production)

### Test Social Features

- Create multiple users (via Auth → Users or dev signup)
- Have one user follow another
- Create tastings from different users
- Check feed shows correct items

---

## Important Concepts

### Authentication Modes

**Production mode** (`AppConstants.authRequired = true`):
- Users must sign up/login
- Real Supabase Auth sessions
- RLS uses `auth.uid()`

**Dev mode** (`AppConstants.authRequired = false`):
- No login required
- Uses developer's own UUID (configured in `setup_schema.sql`)
- RLS policies allow `auth.uid() IS NULL AND user_id = <developer's UUID>`
- Each developer should replace the placeholder UUID in `setup_schema.sql` with their own

### Row-Level Security (RLS)

PostgreSQL feature enforced by Supabase:
- Policies define who can SELECT/INSERT/UPDATE/DELETE
- Example: `tastings_select_own` allows `auth.uid() = user_id`
- `tastings_select_public` allows `true` (anyone can read)

### Feed Architecture

- **Source of truth**: `tastings` table
- **Feed display**: `activity_feed` table (denormalized for performance)
- **View**: `feed_with_details` joins everything
- **Flow**: Create tasting → Insert into `tastings` + `activity_feed` → Feed queries `feed_with_details`

### Wine Search Flow

1. User types query → `AddWineViewModel.search()`
2. `WineSearchService.search(query:)` → Calls OFF API
3. Returns `[OFFProduct]` → Displayed in list
4. User selects → `WineService.upsertFromOFF(product:)` → Creates/updates `wines` table
5. Returns `Wine` → Used in tasting flow

### Date/Time Formatting

- **Format**: "MMM d · h:mm a" (e.g., "Jan 28 · 9:42 PM")
- **Function**: `VitisTheme.compactTimestamp(_ date: Date)`
- **Used in**: Comments, Cellar rows, Profile activity

### Design System

- **Colors**: `VitisTheme.accent` (#4A0E0E burgundy), `background` (white), `secondaryText` (gray)
- **Fonts**: 
  - Serif for wine names (`wineNameFont()`) - used in Cellar, Feed thumbnails
  - Serif for producers (`producerSerifFont()`) - subtle gray
  - SF Pro for UI (`uiFont()`) - buttons, metadata, timestamps
- **Spacing**: Generous padding (24pt horizontal, 16-32pt vertical)
- **No em dashes**: Use hyphens (-) in strings
- **Icon tinting**: Wine glass icons tinted by category (red/white/rose/sparkling) without text labels

---

## File Reference Quick Guide

| File | Purpose |
|------|---------|
| `VitisApp.swift` | App entry point, initializes Supabase |
| `RootView.swift` | Auth gate, shows TabView or Onboarding |
| `ContentView.swift` | Main TabView (Cellar, Social, Profile) |
| `CellarView.swift` | My Cellar - tasting history list |
| `AddWineSheet.swift` | Multi-step: Search → Rate → Notes → Save |
| `TastingRateView.swift` | Rating slider (1.0-10.0) |
| `NotesSelectView.swift` | Notes chip selection |
| `FeedView.swift` | Social feed (Global/Following) |
| `FeedItemView.swift` | Single feed item display (rating, country, notes, date/time) |
| `ProfileView.swift` | User profile (own or other) |
| `TastingService.swift` | Create/fetch tastings |
| `FeedService.swift` | Fetch feed (global/following) |
| `WineService.swift` | Upsert wines from OFF |
| `AuthService.swift` | Authentication, profile management |
| `VitisTheme.swift` | Design system (colors, fonts, timestamps) |
| `TastingNotes.swift` | Category-based tasting notes (Red/White/Rose/Sparkling) |
| `setup_schema.sql` | Complete database schema |

---

## Recent Changes & Implementation Details

### Feed Display Enhancements (January 2026)

**What changed:**
- Feed items now show detailed information matching Cellar view
- Rating, country (region), tasting notes, and date/time are displayed for `had_wine` activities
- Wine glass icons are tinted by category (red/white/rose/sparkling) without text labels
- Typography updated: wine names use serif fonts, producers use serif with gray color

**Technical details:**

1. **FeedItem model updates**:
   - Added `tastingRating: Double?` - Rating from `tastings` table
   - Added `wineRegion: String?` - Region from `wines` table
   - Added `wineCategory: String?` - Category for icon tinting

2. **FeedRowPayload updates**:
   - Maps `tasting_rating` and `wine_region` from `feed_with_details` view
   - Maps `wine_category` for icon tinting

3. **FeedItemView updates**:
   - New `hadWineDetails` view component:
     - First line: Rating (burgundy) · Country (gray) - left-aligned
     - Second line: Notes (gray) - left-aligned
     - Date/time (gray) - right-aligned
   - `categoryColor(for:)` function:
     - Red: `Color(red: 0.7, green: 0.1, blue: 0.1)`
     - White: `Color(red: 0.95, green: 0.9, blue: 0.7)`
     - Rose: `Color(red: 0.95, green: 0.7, blue: 0.7)`
     - Sparkling: `Color(white: 0.95)`
   - Wine thumbnail typography:
     - Producer: `VitisTheme.producerSerifFont()` (serif, gray)
     - Wine name: `VitisTheme.wineNameFont()` (serif, black)
     - Vintage: `VitisTheme.detailFont()` (serif, gray)

4. **Database updates**:
   - `feed_with_details` view includes `tasting_rating`, `wine_region`, `wine_category`
   - `activity_feed` constraint updated to include `'had_wine'` activity type

**Visual format example:**
```
Ahmet Dericioglu had Chardonnay.
8.0 · Chile                    Jan 29 · 9:53 AM
Vanilla, Floral
[Wine thumbnail with tinted icon]
[Cheers] [Comment]
```

---

## Next Steps for New Engineers

1. **Read this README** (you're doing it!)
2. **Set up local environment** (follow Setup Instructions)
3. **Run the app** and test the flow (Add wine → Rate → Notes → Save)
4. **Explore the code**:
   - Start with `RootView.swift` → `ContentView.swift` → `CellarView.swift`
   - Follow the flow: `AddWineSheet` → `TastingRateView` → `NotesSelectView` → `TastingService`
   - Check `FeedItemView.hadWineDetails` to see how feed items are rendered
5. **Check Supabase Dashboard**:
   - Table Editor → See `tastings`, `activity_feed`, `wines` tables
   - SQL Editor → Run queries to inspect data
   - Verify `feed_with_details` view includes `tasting_rating`, `wine_region`, `wine_category`
6. **Read existing code**:
   - Models: `Tasting.swift`, `Wine.swift`, `FeedItem.swift`, `FeedRowPayload.swift`
   - Services: `TastingService.swift`, `FeedService.swift`
   - Views: `CellarView.swift`, `FeedView.swift`, `FeedItemView.swift`

---

## Questions?

- **Database issues**: Check `supabase/setup_schema.sql` and Supabase Dashboard
- **Build errors**: Clean build folder, reset packages
- **API errors**: Check Supabase Dashboard → Logs
- **UI questions**: Check `VitisTheme.swift` for design system

---

**Last updated**: January 29, 2026  
**Version**: Post-refactor (tastings-based, no duel/comparison)  
**Latest changes**: Feed display enhancements (rating, country, notes, date/time, icon tinting, typography)
