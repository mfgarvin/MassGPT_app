# Introibo — Session History

Chronological change log, moved out of `CLAUDE.md` to keep that file lean. This is historical context; the authoritative "how things work now" lives in `CLAUDE.md` and the source. Entries are append-only and may describe code that was later changed or removed.

## Session Log: 2026-01-01

Changes made during initial setup session:

1. **Created CLAUDE.md** - This documentation file

2. **Added dev location override** (`lib/pages/find_parish_near_me_page.dart`)
   - Added `kDevLocation` constant using `kDebugMode` from `flutter/foundation.dart`
   - Modified `_getUserLocation()` to check for dev override before calling Geolocator
   - Enables map testing on Linux desktop without GPS hardware

3. **Fixed OSM tile warnings** (`lib/pages/find_parish_near_me_page.dart`)
   - Removed `{s}` subdomain placeholder from tile URL
   - Removed `subdomains: ['a', 'b', 'c']` parameter
   - Fixes flutter_map warnings about deprecated OSM subdomain usage

4. **Environment setup**
   - Installed Flutter via snap
   - Installed Android Studio and SDK via snap
   - Configured Flutter to use Android SDK at `~/Android/Sdk`
   - Accepted Android licenses

## Session Log: 2026-01-02

Changes made to fix Android build:

1. **Upgraded Android Gradle Plugin** (`android/settings.gradle`)
   - AGP 7.3.0 → 8.6.0
   - Required for compatibility with modern Flutter and Kotlin versions

2. **Upgraded Kotlin version** (`android/settings.gradle`)
   - Kotlin 2.0.21 → 2.1.0
   - Cleaned up commented-out version lines

3. **Updated Java compatibility** (`android/app/build.gradle`)
   - Java 8 → Java 17 (required by AGP 8.x)
   - Updated `sourceCompatibility`, `targetCompatibility`, and `jvmTarget`

4. **Fixed AndroidManifest.xml** (`android/app/src/main/AndroidManifest.xml`)
   - Removed deprecated `package` attribute from `<manifest>` tag
   - Namespace is now defined only in `build.gradle` via `namespace` property

### UI Redesign (2026-01-02)

Complete UI redesign inspired by [Shadow60539/travel_app](https://github.com/Shadow60539/travel_app):

1. **Added `google_fonts` dependency** (`pubspec.yaml`)
   - Clean Lato typography throughout the app

2. **New color scheme** (`lib/main.dart`)
   - Changed from dark blue background to light off-white theme
   - Teal (`#3F95A1`) as primary accent color
   - Dark blue (`#003366`) as secondary color
   - White cards with subtle shadows

3. **Redesigned HomePage** (`lib/main.dart`)
   - Header with app title and church icon
   - "Discover" section label
   - Two large action cards with icons, subtitles, and arrow indicators
   - Info card showing coverage area (80+ parishes)

4. **Redesigned ResearchParishPage** (`lib/pages/research_parish_page.dart`)
   - Modern rounded search bar with shadow
   - Empty state with icon and instructions
   - Parish cards showing name, address, and first mass time
   - Result count display

5. **Redesigned FindParishNearMePage** (`lib/pages/find_parish_near_me_page.dart`)
   - Full-screen map with floating back button
   - Info card overlay: "Parishes Near You"
   - Custom user location marker (teal dot with glow)
   - Custom parish markers (blue circles with church icon)
   - Modern bottom sheet when tapping a parish

6. **Redesigned ParishDetailPage** (`lib/pages/parish_detail_page.dart`)
   - Collapsing SliverAppBar with gradient header
   - Card-based layout for all info sections
   - Consistent styling with rounded corners and shadows

### HomePage Search & Quick Access (2026-01-02)

Enhanced HomePage with inline search and quick access buttons:

1. **Replaced "Research a Parish" card with search bar** (`lib/main.dart`)
   - Inline search with autocomplete dropdown (up to 5 results)
   - Debounced search (200ms) for smooth typing
   - Results show parish name, city, and ZIP code
   - Tapping a result navigates directly to ParishDetailPage
   - "No parishes found" message when no matches

2. **Added "Looking for" quick access section**
   - 4 quick access buttons in a row:
     - Mass Times (teal)
     - Confession (dark blue)
     - Adoration (orange)
     - Parish Details (purple)
   - Each button has icon, label, and colored background
   - Placeholder onTap handlers for future functionality

3. **HomePage layout order**
   - Header (MassGPT title + church icon)
   - Subtitle
   - Search Parishes section with autocomplete
   - Looking for section (4 quick buttons)
   - Nearby Parishes section (horizontal scrolling list)
   - Info section (coverage area)

### Nearby Parishes List (2026-01-02)

Replaced "Find a Parish Near Me" card with a horizontal scrolling list of nearby parishes:

1. **Added location functionality to HomePage** (`lib/main.dart`)
   - Added `kDevLocation` constant (mirrors the one in `find_parish_near_me_page.dart`)
   - Added `_getUserLocation()` method with dev override support
   - Added `_calculateDistance()` using Haversine formula (returns miles)
   - Added `_updateNearbyParishes()` to sort and select 10 nearest parishes

2. **New "Nearby Parishes" section**
   - Section header with "View All" button (navigates to map view)
   - Horizontal scrolling `ListView` showing 10 nearest parishes
   - Loading state: spinner with "Finding nearby parishes..." message
   - Error state: "Location unavailable" with "Try Again" button
   - Empty state: "No parishes found nearby" message

3. **`_NearbyParishCard` widget**
   - Fixed width (200px) cards in horizontal scroll
   - Church icon and distance badge (e.g., "1.2 mi") in header
   - Parish name (up to 2 lines) and city
   - First mass time with clock icon at bottom
   - Tapping navigates to `ParishDetailPage`

4. **Removed unused `_ActionCard` class**
   - No longer needed since the action card was replaced with the list

### Quick Access Button Filters (2026-01-02)

Implemented functionality for the four quick access buttons on HomePage:

1. **New `FilteredParishListPage`** (`lib/pages/filtered_parish_list_page.dart`)
   - Reusable page for displaying filtered parish lists
   - `ParishFilter` enum: `massTimes`, `confession`, `all`
   - `SortOrder` enum: `distance`, `alphabetical`
   - Default sort by distance (nearest first)
   - Toggle button to switch between "Nearest" and "A-Z" sorting
   - Distance badges on cards when sorted by distance
   - Shows parish count, times (up to 3 with "+N more" indicator)

2. **Quick access button actions** (`lib/main.dart`)
   - **Mass Times**: Opens `FilteredParishListPage` with mass times filter
   - **Confession**: Opens `FilteredParishListPage` with confession filter
   - **Adoration**: Shows "Coming Soon" bottom sheet (no data yet)
   - **Parish Events**: Shows "Coming Soon" bottom sheet (for future expansion)

3. **Sort toggle feature**
   - Button in top-right shows current sort mode
   - Tapping toggles between distance and alphabetical
   - Distance calculated using Haversine formula
   - Falls back to alphabetical if location unavailable

4. **Reusable `_showComingSoon` method**
   - Generic bottom sheet for "Coming Soon" features
   - Accepts icon, title, message, and accent color
   - Used by Adoration and Parish Events buttons

### App Menu & Settings (2026-01-02)

Added dropdown menu to the church icon in the top-right of HomePage:

1. **PopupMenuButton on church icon** (`lib/main.dart`)
   - Favorites option (heart icon)
   - Settings option (gear icon)
   - Feedback option (feedback icon)

2. **FeedbackPage** (`lib/main.dart`)
   - Full-screen modal overlay with slide-up animation
   - Header showing feedback destination: `feedback@massgpt.org`
   - Optional email field for replies
   - Multi-line feedback text area
   - Submit button with loading state and success notification

3. **SettingsPage** (`lib/main.dart`)
   - Dark mode toggle switch
   - Version info display (1.0.0)
   - Full dark mode support

4. **ThemeNotifier** (`lib/main.dart`)
   - Global `ChangeNotifier` for app-wide theme management
   - `isDarkMode` getter and `toggleTheme()`/`setDarkMode()` methods
   - `MassGPTApp` converted to `StatefulWidget` to listen for theme changes
   - Both light and dark `ThemeData` configured in `MaterialApp`

5. **Dark mode color constants** (`lib/main.dart`)
   - `kBackgroundColorDark`: `#1A1A2E` (dark blue)
   - `kCardColorDark`: `#16213E` (slightly lighter dark blue)

### Favorites Feature (2026-01-02)

Implemented favorites system allowing users to save parishes:

1. **FavoritesManager** (`lib/main.dart`)
   - Global `ChangeNotifier` for managing favorites
   - `isFavorite()`, `toggleFavorite()`, `addFavorite()`, `removeFavorite()` methods
   - Stores favorites by parish name in a `Set<String>`

2. **Star icon on ParishDetailPage** (`lib/pages/parish_detail_page.dart`)
   - Added favorite toggle button in app bar (top-right)
   - Empty star (outline) when not favorited
   - Filled amber star when favorited
   - Listens to `FavoritesManager` for real-time updates

3. **FavoritesPage** (`lib/main.dart`)
   - Full-screen modal showing all favorited parishes
   - Empty state with instructions when no favorites
   - Parish cards with name, city, mass time, and remove button
   - Tapping a card navigates to ParishDetailPage

4. **Persistence with SharedPreferences** (`lib/main.dart`, `pubspec.yaml`)
   - Added `shared_preferences: ^2.2.2` dependency
   - `FavoritesManager.init()` loads favorites from storage on app start
   - Favorites saved automatically when modified
   - Favorites persist across app restarts

### Dark Mode Support (2026-01-02)

Added comprehensive dark mode support throughout the app:

1. **HomePage** (`lib/main.dart`)
   - Added `themeNotifier` listener to `_HomePageState`
   - Theme-aware color getters: `_isDark`, `_backgroundColor`, `_cardColor`, `_textColor`, `_subtextColor`
   - Updated all section headers, subtitles, and info cards

2. **Search bar and autocomplete** (`lib/main.dart`)
   - Input text, hints, and clear button use theme colors
   - Search results dropdown adapts to dark mode
   - Dividers and icons use appropriate colors

3. **Quick access buttons** (`lib/main.dart`)
   - `_QuickAccessButton` reads theme from `themeNotifier`
   - Card background and label text adapt to theme

4. **Nearby parishes list** (`lib/main.dart`)
   - `_NearbyParishCard` accepts theme colors as parameters
   - Loading, error, and empty states use theme colors

5. **Coming soon dialogs** (`lib/main.dart`)
   - Card background, title, and message use theme colors

6. **FeedbackPage** (`lib/main.dart`)
   - App bar, labels, inputs, and hints adapt to theme

7. **SettingsPage** (`lib/main.dart`)
   - Already had full dark mode support

8. **FavoritesPage** (`lib/main.dart`)
   - Already had full dark mode support

9. **ParishDetailPage** (`lib/pages/parish_detail_page.dart`)
   - Added `themeNotifier` listener
   - Background, cards, and all text adapt to theme
   - All helper widgets (`_InfoCard`, `_ScheduleCard`, `_ContactRow`) accept theme colors

### Tap-to-Action for Contact Info (2026-01-02)

Added interactive actions for address, phone, and website on ParishDetailPage:

1. **url_launcher dependency** (`pubspec.yaml`)
   - Enables launching external URLs for maps, calls, and websites

2. **Address Card** (`lib/pages/parish_detail_page.dart`)
   - New `_TappableInfoCard` widget with "Get Directions" action button
   - Tapping opens Google Maps with the encoded parish address

3. **Contact Row Actions**
   - New `_TappableContactRow` widget with visual feedback
   - **Phone**: Tapping initiates a phone call via `tel:` URL
   - **Website**: Tapping opens the website in external browser
   - Non-actionable items appear grayed out (no underline/arrow)

4. **Helper methods**
   - `_launchMaps()` - Opens Google Maps search with address
   - `_launchPhone()` - Strips non-digits and launches tel: URL
   - `_launchWebsite()` - Adds https:// if needed, opens in browser

### Parish Images (2026-01-02)

Added support for parish images in the detail page header:

1. **cached_network_image dependency** (`pubspec.yaml`)
   - Efficient image loading with caching and placeholders

2. **Parish model update** (`lib/models/parish.dart`)
   - Added optional `imageUrl` field
   - JSON key: `image_url`

3. **ParishDetailPage header** (`lib/pages/parish_detail_page.dart`)
   - `_buildHeaderBackground()` - Checks for image URL
   - If image exists: Shows cached image with gradient overlay for text readability
   - If no image: Shows placeholder with gradient background and church icon
   - `_buildPlaceholderBackground()` - Reusable placeholder widget

4. **Adding images to parishes**

   To add an image for a parish, add the `image_url` field to the parish entry in `data/parishes.json`:
   ```json
   {
     "name": "Transfiguration",
     "latitude": 41.4771636,
     "longitude": -81.7767796,
     "address": "12608 Madison Avenue",
     "city": "Lakewood, OH",
     "zip_code": "44107",
     "phone": "(216) 521-7288",
     "www": "lakewoodcatholicacademy.com",
     "image_url": "https://example.com/transfiguration-church.jpg",
     "mass_times": ["Sunday: 9:00AM", "Saturday: 4:00PM"],
     "conf_times": ["Saturday: 3:15PM to 3:45PM"]
   }
   ```

   **Image recommendations:**
   - Use HTTPS URLs for security
   - Recommended size: 800x600 pixels or larger
   - Landscape orientation works best with the header layout
   - JPEG format preferred for photos (smaller file size)

### Android URL Launcher Fix (2026-01-02)

Fixed tap-to-action features not working on Android 11+ devices:

1. **AndroidManifest.xml queries** (`android/app/src/main/AndroidManifest.xml`)
   - Added `<queries>` declarations required by Android 11+ (API 30+)
   - `https` / `http` schemes for opening websites
   - `tel` scheme for phone calls (DIAL intent)
   - `geo` scheme for opening maps
   - Without these declarations, `url_launcher` silently fails on newer Android versions

## Future Enhancements

### Google Places API for Parish Images

Consider integrating the Google Places API to automatically fetch real photos of parishes:

1. **Implementation approach**:
   - Use parish name + city to search for the place
   - Fetch place photos using the Place Photos API
   - Cache results to minimize API calls

2. **Requirements**:
   - Google Cloud Platform account
   - Places API enabled
   - API key with appropriate restrictions

3. **Estimated API costs** (as of 2025):
   - Place Search: $17 per 1,000 requests
   - Place Photos: $7 per 1,000 requests

4. **Alternative**: Continue using manual `image_url` entries in parish data for curated, cost-free images

### TODO (Linux): `gen_icons.py --check` passes when it cannot check

Found 2026-08-30 on the Mac. `python3 tool/gen_icons.py --check` prints
`rsvg-convert not found (apt install librsvg2-bin)` and then **exits 0**:

```
$ python3 tool/gen_icons.py --check
rsvg-convert not found (apt install librsvg2-bin)
$ echo $?
0
```

A missing renderer is reported as success, so the check silently verifies
nothing. That is worst on **macOS**, which has no `rsvg-convert` by default and
is the machine release IPAs are built on — so any future release gate wired to
`--check` would be green on exactly the machine where drift ships.

Fix: exit non-zero when the renderer is absent, so "cannot verify" is distinct
from "verified, matches". Worth deciding at the same time whether `--check`
should look for `rsvg-convert` only, or fall back to a macOS-available renderer
(`brew install librsvg` provides it, but requiring a brew package to validate a
release is its own trap).

Unblocked and unrelated to the icon assets themselves, which are correct: the
launch image is generated from the icon vector, the 1024 app icon carries no
alpha, the launch mark does, and `LaunchBackground.colorset` has both light and
dark appearances.

## Session Log: 2026-01-05

### Updated Parish Data Format

Adapted the app to work with a revised `parishes.json` format:

1. **Parish model updates** (`lib/models/parish.dart`)
   - Added `parishId` field for unique parish identifiers
   - Added `adoration: List<String>` for adoration schedules
   - Added `eventsSummary` for upcoming events description
   - Changed JSON key from `www` to `website` (backward compatible)
   - Changed JSON key from `conf_times` to `confessions` (backward compatible)

2. **ParishDetailPage enhancements** (`lib/pages/parish_detail_page.dart`)
   - Added Adoration card (orange accent, sun icon) - only shown when data exists
   - Added Upcoming Events card (purple accent, event icon) - displays `events_summary`

3. **Adoration quick access** (`lib/main.dart`, `lib/pages/filtered_parish_list_page.dart`)
   - Added `ParishFilter.adoration` enum value
   - Connected Adoration button on HomePage to filtered list (no longer "Coming Soon")
   - Parishes with adoration schedules are now filterable and viewable

4. **Data format changes**
   - New JSON uses `website` instead of `www`
   - New JSON uses `confessions` instead of `conf_times`
   - New fields: `parish_id`, `adoration`, `events_summary`
   - Coordinates (`latitude`/`longitude`) are no longer present in the data
   - Map and distance features will need coordinates added to function

## Session Log: 2026-01-06

### Updated Parish Data and Coordinate Parsing

Updated the app to work with new parish data format containing 189 parishes:

1. **New coordinate format support** (`lib/models/parish.dart`)
   - Added `_parseLatitude()` and `_parseLongitude()` helper methods
   - Parses `lonlat` field format: `"longitude,latitude"` (e.g., `"-81.4749273,41.5212583"`)
   - Maintains backward compatibility with separate `latitude`/`longitude` fields
   - Map and distance features now work with the new data format

2. **Parish data update** (`data/parishes.json`)
   - Updated to 189 parishes (up from ~80)
   - New fields: `lonlat`, `bulletin_url`, `timestamp`
   - 188/189 parishes have coordinates
   - Removed `parishes.json.old` backup file

### Bulletin Button Feature

Added ability to view weekly parish bulletins:

1. **Parish model update** (`lib/models/parish.dart`)
   - Added `bulletinUrl` field (optional)
   - Maps from `bulletin_url` JSON key

2. **ParishDetailPage enhancement** (`lib/pages/parish_detail_page.dart`)
   - Added `_launchBulletin()` method to open bulletin URL in external browser
   - Added `_BulletinButton` widget with red accent color and article icon
   - Button appears after address card, before mass times (only if bulletin exists)
   - Opens PDF/bulletin in external browser app

3. **UI design**
   - Red accent color to distinguish from other action buttons
   - Article icon (`Icons.article`) with "Weekly Bulletin" title
   - Subtitle: "View the latest parish bulletin"
   - Open-in-new icon indicates external link

## Session Log: 2026-01-07

### Last Updated Indicator

Added data freshness indicator to parish detail page:

1. **Parish model update** (`lib/models/parish.dart`)
   - Added `lastUpdated` field (`DateTime?`)
   - Added `_parseTimestamp()` to parse `timestamp` JSON field (YYYY-MM-DD format)

2. **ParishDetailPage** (`lib/pages/parish_detail_page.dart`)
   - Added `_formatDate()` method formatting dates as MM-DD-YY
   - Displays "Data last updated: MM-DD-YY" at bottom of detail page

### Data Verification Feedback Form

Added user feedback form for verifying parish data accuracy:

1. **Feedback trigger** (`lib/pages/parish_detail_page.dart`)
   - "Is this information accurate?" button below last updated date
   - Opens bottom sheet with verification form

2. **`_DataFeedbackSheet` widget**
   - Two choice buttons: "Yes, it's accurate" / "No, there's an issue"
   - Issue category chips when reporting problems:
     - Mass Times, Confession Times, Adoration, Address, Phone Number, Website, Other
   - Optional text field for additional details
   - Submit button with loading state

3. **Email integration**
   - Submitting opens email client with pre-filled content
   - Subject: "Data Confirmed: [Parish]" or "Data Issue Report: [Parish]"
   - Body includes parish info, status, issues, and details

### Active Feedback System

Made all feedback forms functional with email integration:

1. **General Feedback** (`lib/main.dart`)
   - FeedbackPage now opens email client on submit
   - Subject: "MassGPT App Feedback"
   - Includes user feedback and optional reply email

2. **Parish Data Verification** (`lib/pages/parish_detail_page.dart`)
   - Opens email with parish details and reported issues
   - All feedback sent to `feedback@massgpt.org`

### Dark Mode for Filtered Lists

Added dark mode support to `FilteredParishListPage`:

1. **Theme integration** (`lib/pages/filtered_parish_list_page.dart`)
   - Added `themeNotifier` listener
   - Background, app bar, and text colors adapt to theme
   - Sort toggle button uses theme colors

2. **`_ParishCard` widget updates**
   - Accepts `cardColor`, `textColor`, `subtextColor` parameters
   - All card elements adapt to dark mode
   - Time chips use theme-aware colors

### About Page

Replaced info tooltip with About page:

1. **Homepage update** (`lib/main.dart`)
   - Changed bottom info section to "About this app" button
   - Tapping opens About page with slide-up animation

2. **`AboutPage` widget** (`lib/main.dart`)
   - App icon, name, and version display
   - Three placeholder cards: About This App, Credits, Contact
   - Full dark mode support
   - TODO comments for user to fill in details later

### Dynamic Parish Data Loading

Changed from static local JSON to dynamic remote loading:

1. **ParishService singleton** (`lib/services/parish_service.dart`)
   - Global `parishService` instance shared across all pages
   - Remote URL: `https://raw.githubusercontent.com/mfgarvin/bulletin/refs/heads/main/export.json`
   - Caches data after first successful load
   - 10-second timeout on network requests
   - Falls back to local `data/parishes.json` if network fails

2. **Updated pages to use service**:
   - `lib/main.dart` - HomePage
   - `lib/pages/research_parish_page.dart` - ResearchParishPage
   - `lib/pages/filtered_parish_list_page.dart` - FilteredParishListPage
   - `lib/pages/find_parish_near_me_page.dart` - FindParishNearMePage

3. **Added `http` package** (`pubspec.yaml`)
   - Version: `^1.2.0`
   - Used for fetching remote JSON data

### Local Caching and Offline Support

Enhanced data loading with local caching and offline handling:

1. **ParishService caching** (`lib/services/parish_service.dart`)
   - Caches parish JSON data locally using SharedPreferences
   - Loads cached data first for instant startup
   - Fetches fresh data from remote URL in background
   - `isUsingCachedData` flag indicates offline mode
   - `requiresInternet` flag for first-run without connection

2. **Removed bundled JSON** (`pubspec.yaml`)
   - `data/parishes.json` no longer bundled with APK
   - Data must be downloaded on first launch
   - Reduces app size and ensures fresh data

3. **"Internet Required" screen** (`lib/main.dart`)
   - `_buildRequiresInternetScreen()` widget
   - Shown on first launch without internet connection
   - WiFi-off icon with explanation message
   - "Try Again" button to retry connection

4. **Offline warning** (`lib/main.dart`)
   - `_showOfflineWarning()` displays orange snackbar
   - Shown when app uses cached data (couldn't reach server)
   - Message: "Offline mode - data may be out of date"

### Android Mailto Fix

Added mailto scheme for email feedback on Android 11+:

1. **AndroidManifest.xml queries**
   - Added `mailto` scheme with `SENDTO` action
   - Allows `url_launcher` to open email apps on Android 11+

## Session Log: 2026-01-07 (Evening)

### Custom Catholic Icons

Added custom SVG icons for Catholic-specific features using the flutter_svg package:

1. **Icon files** (`assets/icons/`)
   - `monstrance.svg` - Eucharistic monstrance icon for Adoration
   - `confession.svg` - Confessional booth icon for Confession/Reconciliation
   - Icons sourced from Noun Project (Ahmad Roaayala and Luis Prado)
   - Attribution text removed from SVG files
   - Cleaned up viewBox dimensions

2. **flutter_svg dependency** (`pubspec.yaml`)
   - Added `flutter_svg: ^2.0.10` for SVG rendering
   - Supports dynamic coloring and sizing

3. **CustomIcon widget** (`lib/widgets/custom_icons.dart`)
   - Centralized widget for rendering SVG icons
   - Factory constructors: `CustomIcon.monstrance()` and `CustomIcon.confession()`
   - Accepts `color` and `size` parameters for flexibility
   - Usage: `CustomIcon.monstrance(color: Colors.orange, size: 28)`

4. **HomePage integration** (`lib/main.dart`)
   - Updated `_QuickAccessButton` to accept `Widget` instead of `IconData`
   - Confession button uses `CustomIcon.confession()` (28px)
   - Adoration button uses `CustomIcon.monstrance()` (28px)
   - Increased icon sizes from 22px to 28px for better visibility

5. **ParishDetailPage integration** (`lib/pages/parish_detail_page.dart`)
   - Updated `_ScheduleCard` to accept `Widget` instead of `IconData`
   - Updated `_TappableInfoCard` to accept `Widget` instead of `IconData`
   - Confession Times card uses `CustomIcon.confession()` (26px)
   - Adoration card uses `CustomIcon.monstrance()` (26px)
   - Increased icon sizes from 20px to 26px for better visibility

6. **Icon size adjustments**
   - HomePage quick access buttons: 28px (27% larger than original 22px)
   - ParishDetailPage schedule cards: 26px (30% larger than original 20px)
   - Improved icon recognizability and visual hierarchy


## Session Log: 2026-01-08

### Nearest & Soonest Sorting

Added intelligent sorting that combines proximity and time to help users find the most convenient parishes:

1. **ScheduleParser utility** (`lib/utils/schedule_parser.dart`)
   - Parses schedule strings like "Sunday: 9:00AM, 11:00AM" into structured data
   - Supports day names (Monday-Sunday) and abbreviations (Mon, Tue, etc.)
   - Handles 12-hour format with AM/PM
   - Correctly converts to 24-hour time (noon, midnight edge cases)
   - Calculates next occurrence of each event from current time
   - `ScheduleEntry` class with `nextOccurrence()` and `minutesUntilNext()` methods
   - `findNextOccurrence()` finds soonest event from a list of schedules

2. **Enhanced FilteredParishListPage** (`lib/pages/filtered_parish_list_page.dart`)
   - Added `SortOrder.nearestAndSoonest` enum value
   - New `_calculateNextOccurrences()` method calculates minutes until next event for each parish
   - New `_calculateCompositeScore()` combines distance and time into a single score:
     - Distance weight: Each mile = ~15 minutes of "cost"
     - Composite score: 40% distance + 60% time priority
     - Lower score = better option (closer and sooner)
   - Updated `_toggleSortOrder()` to cycle through all three modes:
     - Nearest & Soonest → Nearest → A-Z → (repeat)
   - Default sort mode is now `nearestAndSoonest`

3. **UI enhancements**
   - Sort button shows icon and label based on current mode:
     - "Soonest" with schedule icon
     - "Nearest" with location icon
     - "A-Z" with alphabetical icon
   - Parish cards show time until next event when in "Soonest" mode:
     - "45 min" for events within the hour
     - "2h 30m" for events within 24 hours
     - "2 days" or "2d 5h" for events further out
   - Time badges use accent color matching the filter type

4. **Unit tests** (`test/schedule_parser_test.dart`)
   - Comprehensive test suite with 15 test cases
   - Tests parsing single/multiple times, AM/PM conversion
   - Tests noon and midnight edge cases
   - Tests next occurrence calculation across days
   - Tests wrapping to next week when event has passed
   - Tests finding soonest from multiple schedules
   - Tests graceful handling of invalid input

**Example use case:** User needs confession soon. Opens Confession filter, sees parishes sorted by composite score showing "2.1 mi, 45 min" is ranked above "1.5 mi, 2h 30m" because the first has confession starting sooner despite being slightly farther.


## Session Log: 2026-01-08 (App Rename)

### App Renamed: MassGPT → Introibo

Renamed the entire application from "MassGPT" to "Introibo" throughout the codebase:

1. **User-facing strings** (14 occurrences across 4 files)
   - `lib/main.dart` - App title, class names (`MassGPTApp` → `IntroiboApp`), window title, first-launch message, HomePage title, feedback email subject, email signatures, About page title and description
   - `lib/pages/parish_detail_page.dart` - Data feedback email signature
   - `README.md` - Project title, git repository URLs
   - `CLAUDE.md` - Project overview description

2. **Package identifiers** (all platforms)
   - `pubspec.yaml` - Package name: `massgpt_app_o1_preview` → `introibo`
   - `android/app/build.gradle` - namespace and applicationId: `com.example.massgpt_app_o1_preview` / `com.example.mass_gpt` → `com.example.introibo`
   - `android/app/src/main/AndroidManifest.xml` - android:label: `massgpt_app_o1_preview` → `Introibo`
   - `android/app/src/main/kotlin/` - Moved MainActivity.kt to new package structure (`com.example.introibo`)
   - `ios/Runner/Info.plist` - CFBundleDisplayName: `Massgpt App O1 Preview` → `Introibo`, CFBundleName: `massgpt_app_o1_preview` → `introibo`
   - `ios/Runner.xcodeproj/project.pbxproj` - PRODUCT_BUNDLE_IDENTIFIER: `com.example.massgptAppO1Preview` → `com.example.introibo`

3. **Test files**
   - `test/schedule_parser_test.dart` - Updated import path to use new package name (`package:introibo/...`)

4. **Cleanup**
   - Removed unused `lib/globals.dart` file that was causing build errors

5. **Intentionally preserved**
   - Email address remains `feedback@massgpt.org` (not changed to match app name)
   - Parish data source URL unchanged

**Verification:**
- `flutter pub get` completed successfully
- `flutter analyze` completed with 0 errors (112 info-level warnings for style/deprecations)
- All MassGPT references removed except for the preserved email address


## Session Log: 2026-01-11

### Sort Toggle Bug Fix

Fixed a bug where the sort toggle button in `FilteredParishListPage` would not cycle back to "Soonest" after reaching "A-Z".

1. **Root Cause** (`lib/pages/filtered_parish_list_page.dart:192-198`)
   - `_calculateCompositeScore()` used `double.infinity.toInt()` as a fallback value
   - In Dart, calling `.toInt()` on `double.infinity` throws: `Unsupported operation: Infinity or NaN toInt`
   - This exception occurred inside `_applySorting()`, which was called within `setState()`
   - The exception silently prevented the UI from updating, even though the state variable was being set correctly

2. **Fix**
   - Changed null handling to check for `null` directly instead of using `double.infinity.toInt()`
   - Before: `final minutes = _minutesUntilNext[parish.name] ?? double.infinity.toInt();`
   - After: `final minutes = _minutesUntilNext[parish.name];` with explicit null check

3. **Lesson learned**
   - Exceptions thrown inside `setState()` can silently break UI updates
   - Debug prints may show correct state changes while UI remains stale due to subsequent exceptions

### Enhanced "Soonest" Sorting with Distance Cap

Replaced composite scoring with a simpler distance-cap approach for the "Soonest" sort mode:

1. **Distance cap sorting** (`lib/pages/filtered_parish_list_page.dart`)
   - Within 10 miles: sorted by time (soonest event first)
   - Beyond 10 miles: pushed to bottom, sorted by distance
   - Configurable via `_distanceCapMiles` constant

2. **Human-friendly time badges**
   - Replaced "2h 30m" style with natural language descriptors
   - Labels: "Starting soon", "Within the hour", "This morning/afternoon/evening", "Tonight", "Tomorrow morning/afternoon/evening/night", "In 2 days", "In X days"

3. **"Show more" button**
   - Parishes more than 2 days out are hidden by default in "Soonest" mode
   - "Show X more parishes" button appears at bottom to reveal them
   - Resets when switching sort modes

### Time-Based Filter Feature

Added filter button to search for events by day and time of day:

1. **Filter UI** (`lib/pages/filtered_parish_list_page.dart`)
   - Filter button next to sort button (highlights when active)
   - Bottom sheet with filter options
   - "Clear" button to reset all filters

2. **Filter options**
   - **When**: Any day, Today, Tomorrow, This week
   - **Time of day**: Any time, Morning (5am-12pm), Afternoon (12pm-5pm), Evening (5pm-9pm)
   - **Day of week**: Sun, Mon, Tue, Wed, Thu, Fri, Sat (multi-select)

3. **Filter enums**
   - `DayFilter`: any, today, tomorrow, thisWeek
   - `TimeOfDayFilter`: any, morning, afternoon, evening, night

4. **Filter logic**
   - Uses `ScheduleParser` to parse schedule strings
   - Checks if any schedule entry matches all active filters
   - When filters active, 2-day limit is disabled (shows all matching parishes)

## Session Log: 2026-05-27

Major UI refresh pass. Code-health cleanup first, then the full set of UI ideas the user picked from a proposal list (#2 detail, #3 home, #4 map, #5 motion, #1 typography, #6 dark-mode polish).

### Code health (no UI changes)

- `flutter analyze` cleaned from 117 info-level issues to 0. Removed unused `flutter_dotenv` and discontinued `flutter_map_cancellable_tile_provider` deps.
- Fixed busy-wait concurrency bug in `lib/services/parish_service.dart` — `getParishes()` was polling every 50ms while another load was in flight; replaced with a shared `_pendingLoad` Future.
- Bulk-migrated all 92 `Color.withOpacity(x)` calls to `withValues(alpha: x)` for Flutter 3.27+.
- Ran `dart fix --apply`: 23 auto-fixes (super-params, final fields, const constructors, key params).

### #2 Parish detail polish

- New `lib/widgets/stained_glass_header.dart` — `CustomPainter` that draws a deterministic stained-glass abstract from a seed (`parishId ?? name`). 5 jewel-tone palettes (sapphire, burgundy, forest, vespers violet, twilight teal). Uses 4×3 grid-cell triangulation with per-cell random diagonal — gives uniform shards, no slivers.
- Replaces the old flat church-icon placeholder on the detail page header.
- SliverAppBar gained `stretch: true` + `StretchMode.zoomBackground` for over-scroll zoom.
- New `lib/widgets/next_mass_banner.dart` — pinned banner under the address card with a live ticking countdown ("NEXT MASS · Sunday 10:30 AM · in 2h 15m"). Self-tickers every 30 seconds.
- New `lib/widgets/timeline_schedule_card.dart` — replaces the flat `_ScheduleCard` for Mass, Confession, and Adoration. Groups entries into Today / Tomorrow / This week / Beyond sections, each with day chip + time + optional note.
- Schedule parser gained `groupByBucket()` and `UpcomingEntry` helpers.
- Old `_ScheduleCard` class removed from `parish_detail_page.dart`.

### #3 Home page polish

- New `lib/widgets/today_hero_card.dart` — day-aware suggestion card above the search bar. Adapts headline + intent based on weekday and hour: Sunday morning → Mass; Sunday evening → adoration; Saturday morning → confession; Saturday afternoon → vigil Mass; Friday → confession; weekday morning → daily Mass; weekday after 7 PM → adoration. Tap routes to the matching `FilteredParishListPage` via a `HeroIntent` callback. Tints itself per intent (violet for confession, gold for adoration).
- New `lib/widgets/next_mass_tile.dart` — square 1:1 tile with live countdown to the soonest Mass in a list of parishes. Used twice on home page in a 2-column row: "NEXT MASS NEARBY" (`_nearbyParishes`) and "AT A FAVORITE" (`_favoriteParishes`), the favorite slot only appearing when the user has starred at least one parish. Tile now has a full-bleed stained-glass watermark at 30% opacity with a diagonal scrim from the card color for legibility.
- Home page subscribes to `favoritesManager` so the favorites tile reacts instantly to star toggles on the detail page.

### #4 Map view refresh

- Parchment color-matrix `ColorFilter` applied to OSM tiles (warm sepia wash — no new tile provider needed).
- Bottom swipeable `PageView` of the 40 nearest parishes with `viewportFraction: 0.85`. Cards include a stained-glass chip with a matching Hero tag.
- Marker tap ↔ card swipe sync via `MapController` (selected marker enlarges and tints teal; selected card emphasized via padding).
- Old single-modal `_showParishInfo` bottom sheet removed.

### #5 Motion

- Hero animation from each parish card's small stained-glass chip into the full detail-page header. Source: nearby cards in `main.dart`, filtered-list cards in `filtered_parish_list_page.dart`, map carousel cards. Target: `_buildHeaderBackground()` in `parish_detail_page.dart`. Tag helper: `parishHeroTag(seed)` in `stained_glass_header.dart`.
- The animation felt choppy on Linux desktop during testing — deferred verification until APK build on Android. See `~/.claude/projects/.../memory/hero_anim_linux_choppy.md` for optimization candidates if it persists on a real device.

### #1 + #6 Theme + dark mode overhaul

New palette: **warm parchment + oxblood + gold (light) / true black + candlelight gold (dark).**

Constants in `lib/main.dart`:
- `kBackgroundColor = #FAF6EE` — warm cream parchment
- `kBackgroundColorDark = #000000` — true OLED black
- `kPrimaryColor = #8C1F1F` — deep oxblood (light primary)
- `kSecondaryColor = #4A2828` — deep plum
- `kAccentGold = #C9A227`, `kAccentCandlelight = #D4A24A`
- `kCardColor = #FFFCF4`, `kCardColorDark = #14100F`
- `primaryAccentFor({required bool isDark})` helper — returns candlelight gold in dark mode, oxblood in light, since red on near-black is hard to read.

Typography:
- New `lib/theme/app_text.dart` with a unified 7-step scale: `display`, `titleHuge`, `titleLarge`, `titleHero`, `bodyLarge`, `body`, `caption`, `label`, `kicker`. Reach for these instead of inline `GoogleFonts.x(fontSize: …)` calls.
- Bulk-migrated all 152 `GoogleFonts.lato(...)` calls to `GoogleFonts.inter(...)` for body.
- Cormorant Garamond reserved for display: app title, section headings, card titles, parish names, hero card headline.
- `MaterialApp` theme `textTheme` wired to `GoogleFonts.interTextTheme()`.

Dark mode propagation:
- `parish_detail_page.dart` reads `Theme.of(context).colorScheme.primary` in helper widgets (`_TappableContactRow`, `_BulletinButton`, feedback chip) so accents shift to candlelight gold automatically in dark mode.
- SliverAppBar background, back/star icons, NextMassBanner accent all use `primaryAccentFor(isDark: ...)` or `Theme.of(context).colorScheme.primary`.
- HomePage quick-access buttons: Mass=oxblood/candlelight (theme-aware), Confession=violet `#5E3370`, Adoration=gold, Parish Events=plum.

### Range-aware schedule parsing

- `lib/utils/schedule_parser.dart` now recognizes "X to Y", "X until Y", "X-Y", "X–Y", "X—Y" connectors and merges adjacent times into a single `ScheduleEntry` with optional `endHour`/`endMinute`. Previously, "Tuesday: 3:00PM to 3:30PM" rendered as two separate rows.
- `UpcomingEntry.timeLabel` renders ranges as "3:00 – 3:30 PM" (drops the redundant meridiem when both endpoints share it).
- Time slot in `TimelineScheduleCard` widened from 78 to 128 px to fit ranges.

### Bulletin scraper handoff doc

- `docs/bulletin_scraper_notes.md` — field-by-field observations and a proposed structured JSON shape for the scraper project at `mfgarvin/bulletin`. To be handed to the Claude working on that repo. Key asks: emit `{day, start, end, note}` structured entries, 24-hour HH:MM, ISO day names, drop the `lonlat` combined string in favor of numeric lat/lon, per-section timestamps.

## Session Log: 2026-05-27 (Stained Glass Pass)

The original triangulated-mosaic painter was replaced with a quarry-window inspired one after researching how Gothic stained glass is actually structured (rhombic "quarry" panes tiled in a half-step grid + leaded cames + occasional roundels framed by tracery).

### `lib/widgets/stained_glass_header.dart` — full painter rewrite

- **Quarry diamond tessellation** — rhombi (~78% width:height ratio for the traditional Gothic quarry) tiled with alternate-row half-step horizontal offsets. Diamond size scales proportionally to the canvas shortest side (`shortSide / 3.4`, clamped to 28–80 px).
- **Central roundel** — circular medallion in upper-third of header (auto-omitted on chips < 90px). Filled with a radial gradient toward `palette[3]` (gold), divided into 8 alternating wedges, finished with a small inner-hub jewel and a 4.5px lead-came ring around the perimeter. Diamonds whose centers fall inside the roundel are skipped; diamonds crossing the boundary are clipped via `Path.combine(PathOperation.difference, …)` so cames terminate cleanly at the medallion edge.
- **Thicker, darker lead** — stroke width 3.0 (was 2.2), color `#050507` at 85% alpha (was `#0A0A0F` at 60%), round caps + joins.
- **Soldered joints** — small filled dots (~2px) stamped at diamond vertices to suggest H-channel cames meeting. De-duped via a half-pixel-precision Set. Joints inside the roundel are skipped so the medallion stays clean.
- **Shared vertex jitter** — `jitterCache` keyed by quantized 0.1px position (`(kx * 100000 + ky)`). Each diamond computes its 4 ideal corners and looks each up; adjacent diamonds sharing a corner get the same jittered offset, keeping edges seamless. Jitter amplitude ±4.5% of diamond height — enough to feel hand-cut, not chaotic.
- **HSL-based color variation** — new `_varyColor(base, rng)` shifts hue ±9°, saturation ±10%, lightness ±9% per shard. Probabilistic color picking (45% mid / 30% deep / 17% bright / 8% accent) replaces position-grid color biasing. Each shard's radial gradient also has a slightly randomized highlight position.
- **Bias gold to the roundel** — field shards almost never use `palette[3]` (gold); gold reserved for the medallion so it remains the focal point.
- **Default `overlayDarken: 0.35 → 0.45`** per audit recommendation — keeps display-size parish-name text ≥4.5:1 contrast against gold-heavy palettes (Vespers Violet was the edge case).

### Resize stability via FittedBox + RepaintBoundary

`StainedGlassHeader` now wraps the `CustomPaint` in:

```dart
ClipRect(
  child: Stack(children: [
    FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: 400, height: 200,  // _refSize matches header aspect
        child: RepaintBoundary(
          child: CustomPaint(painter: _StainedGlassPainter(seed: seed)),
        ),
      ),
    ),
    // …darkening gradient…
  ]),
)
```

The painter always renders at the fixed `400×200` reference; the `FittedBox.cover` scales the rasterized result to fill the parent. SliverAppBar over-scroll stretch now performs a real visual zoom on the painted layer instead of regenerating geometry at the new size. Square chips and watermarks get a center-crop of the same painting, which still includes the roundel.

The 2:1 aspect was chosen deliberately — using a 1:1 reference made `cover` crop half the painting on the 2:1 header, which looked "zoomed in." Matching the header's natural aspect avoids that.

### Bulletin scraper notes

`docs/bulletin_scraper_notes.md` documents observations to hand to the scraper project — most actionably the recommendation to emit structured `{day, start, end, note}` schedule entries so the app can drop its regex-based schedule parser.

### Design audit (background)

Ran a multi-page Material 3 / WCAG 2.2 / Nielsen-heuristics audit via a sub-agent. Key findings:

- Light-mode contrast is excellent everywhere **except gold-on-cream as text** (`#C9A227` on `#FAF6EE` ≈ 2.5:1, fails WCAG AA). Use gold for ornament only in light mode; route accent *text* through oxblood.
- No persistent bottom navigation — Favorites/Settings/Feedback are hidden under the church-icon PopupMenu. Adding a `NavigationBar` would help discoverability.
- `TodayHeroCard` and `NextMassTile` both full-bleed creates two competing hero surfaces on the home page; demoting NextMassTile to its existing `NextMassBanner` shape unless next Mass is within 60 min was the agent's suggestion.
- Cycling 3-state sort button on `FilteredParishListPage` should be a `SegmentedButton` (recognition > recall).

Not addressed in this session — deferred for a follow-up pass.

## Session Log: 2026-05-28 (Design Audit Follow-Through)

Worked through 4 of the 5 deferred audit recommendations (the header-darken bump was done in the earlier stained-glass pass).

### Audit #1: Gold-on-light contrast (WCAG AA fix)

- New constant in `lib/main.dart`: `kAccentGoldDeep = Color(0xFF8C5A14)` — text-safe deep bronze-gold (~5.2:1 on parchment, well clear of AA's 4.5:1).
- New helper `goldTextAccentFor({required bool isDark})` returns `kAccentCandlelight` in dark mode, `kAccentGoldDeep` in light. Drop-in replacement for sites where gold was used as foreground text.
- `kAccentGold` (#C9A227) kept for **ornament only**: stained-glass palettes, large icons (where 3:1 is acceptable), favorite-star.
- Sites updated to route through the helper: Adoration quick-access button, favorites `NextMassTile`, Adoration `TimelineScheduleCard` in detail page, hero-card adoration intent, `FilteredParishListPage` adoration route accent. Removed the previous `Colors.amber.shade800` fallback on the favorites tile (also failed AA).

### Audit #5: Sort toggle → M3 SegmentedButton

`FilteredParishListPage` previously cycled `Soonest → Nearest → A-Z` through a single tap target (Nielsen #6 — recognition vs recall violation). Replaced with `SegmentedButton<SortOrder>`:

- Three labeled segments with matching icons (`Icons.schedule` / `Icons.near_me` / `Icons.sort_by_alpha`).
- Tinted in the page's accent color when selected (`selectedBackgroundColor: widget.accentColor.withValues(alpha: 0.15)`), subtext color when not.
- `showSelectedIcon: false` to avoid a redundant checkmark on top of the segment icon.
- Lives on its own padded row below the count/filter row.
- Removed `_toggleSortOrder`, `_getSortIcon`, `_getSortLabel` — `onSelectionChanged` handles the state transition inline.

### Audit #3: Demote NextMassTile when not imminent

The home page had two full-bleed hero surfaces competing for attention (`TodayHeroCard` + `NextMassTile`). New behavior:

- `NextMassTile` gained a `compact: bool` parameter and a `_buildCompact` branch that renders a ~72 dp full-width banner: accent bar | (kicker / parish name / when·time stack) | countdown chip.
- New static helper `NextMassTile.findSoonestMinutes(parishes)` lets the parent compute imminence without instantiating the widget.
- New `_HomePageState._buildNextMassTiles()` decides layout: if **any** soonest Mass across the two parish lists is ≤ 60 min, render both tiles as side-by-side squares (the existing layout — Mass is starting soon, deserves the spotlight). Otherwise stack both as compact banners.
- Most of the time the home page now has a single dominant surface (`TodayHeroCard`) plus two quieter banners; squares only re-appear when there's something genuinely time-sensitive.

### Audit #2: Bottom NavigationBar

Largest structural change. Promoted Map and Favorites from buried entry points (a "View All" link and a PopupMenu item respectively) into top-level destinations:

- New `RootShell` widget hosts the three tabs in an `IndexedStack` (each tab keeps its state across switches — map zoom and PageView position survive a trip to Home and back). Bottom `NavigationBar` with outline-and-filled icon pairs per M3 convention. Selection indicator and background pick up theme colors.
- `IntroiboApp.home` now points at `RootShell` instead of `HomePage`.
- `HomePage` gained an optional `onSwitchToMap` callback; the "View All" button on the Nearby section calls it instead of pushing a new route. Favorites was removed from the church-icon `PopupMenu`. Unused `_showFavoritesPage()` deleted.
- `FindParishNearMePage` gained `inTab: bool`. When true the floating back-button AppBar is hidden (push-style usage still works for any legacy callers).
- `FavoritesPage` gained `inTab: bool` and an optional `parishes` parameter. When `parishes` is null the page loads its own list via `parishService`. Close icon hidden when `inTab`. Listens to `themeNotifier` directly now so it rebuilds on theme changes in either tab or modal use.

The church-icon PopupMenu is now a slim `Settings / Feedback` only — About remains as the bottom-of-page link.

Deferred for a follow-up: no work on the liturgical-day strip on home or the first-launch chime.

## Session Log: 2026-05-28 (Tweaks Pass)

User scribbled a list of small tweaks. Worked through all ten in one session.

### Home page restructure (`lib/main.dart`)

- **Section reorder.** "Looking for" quick-access row now appears **above** the search bar (formerly below). Section order is: hero card → Looking for → Search → Nearby → Today's Liturgy.
- **Hamburger menu.** Top-right church-icon `PopupMenuButton` swapped for `Icons.menu`. Menu now has four items: Home Parishes, Settings, Feedback, About. Previously the menu was Settings + Feedback only, with Favorites buried in the bottom nav and About living as a card link at the bottom of the page.
- **About link removed from the page.** It's in the hamburger menu now. Its slot at the bottom of the page is occupied by the new liturgical tile.
- **"View All" button on Nearby section removed.** The bottom nav's Map tab covers the same affordance.
- `HomePage.onSwitchToMap` callback removed (was only used by the deleted View All button). `RootShell` updated.

### Favorites → Home Parishes rename (user-facing only)

User requested "home parishes, not favorites." Done as a UI-string-only rename to avoid touching the SharedPreferences key (`favorite_parishes`) — existing user saves are preserved.

- Bottom nav tab label: `Favorites` → `My Parishes` (compact label; the page title is the longer form).
- `FavoritesPage` app bar title: `Favorites` → `Home Parishes`.
- Empty-state copy: "No favorites yet" → "No home parishes yet"; instructional text updated to "Tap the star icon … to mark it as a home parish".
- `NextMassTile` favorite-slot label: `AT A FAVORITE` → `AT A HOME PARISH` (both compact and expanded variants).
- Star icon on `ParishDetailPage` gained a `tooltip:` — "Mark as home parish" / "Remove from home parishes".
- **Class names unchanged** — `FavoritesManager`, `FavoritesPage`, the global `favoritesManager`, `parish_detail_page.dart` imports, etc. all keep their original names. Smaller diff, no rename ripple across the codebase. Renaming the internals is fine to do later if it bothers anyone reading the code.

### Search normalization (`lib/utils/search_normalize.dart`)

New `normalizeForSearch(String)` helper. Lowercases, folds common Latin-extended diacritics (`á → a`, `ñ → n`, etc.), then expands Saint abbreviations:

- `\bsts?\.?\s` → `saints ` (handles "Sts.", "Sts", "St" plural via the `s?`)
- `\bss\.?\s`  → `saints ` (e.g. "Ss. Peter and Paul")
- `\bst\.?\s`  → `saint `

Plural rules run before singular so `\bst\b` doesn't eat `ss` partials. Both query and field run through the helper before `.contains()`. Wired into:

- `HomePage._updateSearchResults` (`lib/main.dart`)
- `ResearchParishPage._updateSearchResults` (`lib/pages/research_parish_page.dart`)

ZIP code matching still uses raw `query` (no normalization).

### Stained glass: more variation (`lib/widgets/stained_glass_header.dart`)

- **Palettes 5 → 10.** Added: emerald & copper, indigo & pearl, crimson & saffron, midnight plum & rose-gold, slate & seafoam. Same `[deep, mid, bright, accent, highlight]` convention as the original five.
- **`_varyColor` HSL jitter widened.** Hue ±9° → **±14°**, saturation ±10% → **±16%**, lightness ±9% → **±11%**. Pushing lightness much further produces muddy / washed-out shards, but the wider hue+sat range noticeably increases per-shard variation while still reading as a coherent palette.

### Liturgical day tile placeholder (`lib/widgets/liturgical_day_tile.dart`)

New widget at the bottom of HomePage (replacing the deleted About link).

- Color swatch (44×44 rounded box with a colored glow shadow) + kicker line ("TODAY · Green · Ordinary Time") + Cormorant Garamond title + italic memorial subtitle + full-width `OutlinedButton` linking to `https://bible.usccb.org/daily-bible-reading`.
- **All data hardcoded.** Marked with `// TODO: replace with real data`. The sample is shaped the way the eventual data source should deliver: liturgical color (hex + name), season, mass title, optional memorial.
- Data source not yet picked. Options to revisit: compute locally (Easter + temporale/sanctorale tables — nontrivial), scrape USCCB daily page (brittle), or find a public liturgical JSON feed.

### Version counter

Semver stays manual in `pubspec.yaml`; build number is derived from `git rev-list --count HEAD` at build time. Currently 43.

- **Android Gradle hook** (`android/app/build.gradle`). New top-level `gitBuildNumber` block runs `git rev-list --count HEAD` at configuration time and assigns to `versionCode`. Falls back to `flutter.versionCode` (from pubspec) when git is unavailable — covers shallow CI checkouts and source-tarball builds.
- **Display layer.** Added `package_info_plus: ^8.0.0` to `pubspec.yaml`. New `lib/utils/app_version.dart` loads `PackageInfo.fromPlatform()` once in `main()` and exposes `AppVersion.version`, `AppVersion.buildNumber`, and `AppVersion.display` (formatted as `"1.0.0 build 43"`).
- **About + Settings updated** to render `AppVersion.display` instead of the hardcoded `1.0.0`.
- **iOS gap.** `Runner.xcodeproj/project.pbxproj` left untouched — programmatic edits there are fragile, and the user is on Linux desktop / Android-only for now. When iOS becomes a target, add a Run Script build phase that runs `git rev-list --count HEAD` and updates `CFBundleVersion` via PlistBuddy, or bump `pubspec.yaml`'s `+N` suffix manually. The Dart display layer is platform-agnostic so it'll Just Work once the iOS native side is wired.

### Cloudflare Worker for feedback (`worker/`)

New subdirectory. The worker is a TypeScript Cloudflare Worker backed by a D1 database. **Not deployed yet** — needs a manual `wrangler login` + D1 create step.

Files:

| File | Purpose |
|------|---------|
| `worker/wrangler.toml` | CF config; `database_id` placeholder until D1 is created |
| `worker/package.json` | Wrangler scripts (`dev`, `deploy`, `db:init`, `db:init-local`, `tail`) |
| `worker/tsconfig.json` | Strict TS, Workers types |
| `worker/schema.sql` | `feedback` + `feedback_rate` tables |
| `worker/src/index.ts` | Handler: `POST /feedback`, `GET /healthz` |
| `worker/README.md` | Step-by-step setup |
| `worker/.gitignore` | `node_modules/`, `.wrangler/`, `.dev.vars` |

D1 schema:

- `feedback (id, created_at, kind, parish_name, parish_id, status, issue_categories, reply_email, body, app_version, build_number, platform, client_ip)`. `kind ∈ {'general', 'parish_data'}`.
- `feedback_rate (client_ip, created_at)` — a write-once ledger for rate limiting. Index on `(client_ip, created_at)`.

Worker behavior:

- Permissive CORS (any origin, POST/OPTIONS).
- Body limit 8 KB, body+kind required, kind whitelist enforced.
- Rate limit: **5 submissions per IP per hour**, enforced by `SELECT COUNT(*) FROM feedback_rate WHERE client_ip = ? AND created_at > datetime('now', '-1 hour')` before insert. Returns 429 if exceeded.
- Returns `{ok: true, id: N}` or `{ok: false, error: "..."}`.

**Setup steps when you pick this up** (also in `worker/README.md`):

```bash
cd worker
npm install
npx wrangler login
npx wrangler d1 create introibo-feedback
# paste returned database_id into wrangler.toml
npm run db:init
npm run deploy
# note the printed URL — that's your endpoint
```

Then either edit `lib/config/feedback_endpoint.dart` and replace the placeholder, or build with `--dart-define=FEEDBACK_ENDPOINT=https://introibo-feedback.<account>.workers.dev/feedback`.

### Feedback wiring (`lib/config/`, `lib/services/`)

- `lib/config/feedback_endpoint.dart` — `kFeedbackEndpoint` const, `String.fromEnvironment('FEEDBACK_ENDPOINT', defaultValue: 'https://introibo-feedback.example.workers.dev/feedback')`. `feedbackEndpointConfigured` getter returns false while the placeholder is in place — submissions short-circuit with a clear "not configured yet" message so it can't silently fail in the field.
- `lib/services/feedback_client.dart` — `submitFeedback({required String kind, required String body, parishName, parishId, status, issueCategories, replyEmail})`. Wraps `http.post`, 12-second timeout, parses `{ok, error}` JSON. Auto-attaches `app_version`, `build_number`, `platform` from `AppVersion` + `dart:io Platform`.
- `FeedbackPage._submitFeedback` (`lib/main.dart`) replaced — was opening `mailto:feedback@massgpt.org`, now POSTs `kind: general`. Header copy changed from "Feedback will be sent to: feedback@massgpt.org" to a generic "Your feedback is sent directly to the Introibo team. Add your email if you'd like a reply." Success snackbar (green), error snackbar (red) on failure.
- `_DataFeedbackSheet._submitFeedback` (`lib/pages/parish_detail_page.dart`) same swap — was opening mailto, now POSTs `kind: parish_data` with the structured `parish_name`, `parish_id`, `status` (`accurate`/`issue`), and `issue_categories` list.
- `url_launcher` import removed from `lib/main.dart` — no longer used there. Still used in `parish_detail_page.dart` for Maps / phone / website / bulletin launching.

### Build / verification

- `flutter analyze`: clean (0 issues) after all edits.
- `flutter build apk` (release): success — `build/app/outputs/flutter-apk/app-release.apk` (54 MB). Build number from git: **43** (current commit count at the time of this session).

### Where to pick up

1. **Deploy the Worker.** Follow `worker/README.md`. Update `lib/config/feedback_endpoint.dart` or use the `--dart-define` build flag.
2. **Wire iOS build number** if/when iOS becomes a target — see "iOS gap" above.
3. **Replace hardcoded liturgy data** in `lib/widgets/liturgical_day_tile.dart` once a data source is chosen.
4. **Optional internal rename**: `FavoritesManager`/`FavoritesPage` → `HomeParishesManager`/`HomeParishesPage` to match the user-facing concept. Pure rename; no behavior change.

## Session Log: 2026-05-28 (Structured export.json migration)

The bulletin scraper was rewritten to emit fully **structured** schedules (see
`EXPORT_SHAPE_CHANGES.md`). Migrated the app off regex string-parsing onto the
pre-parsed shape. No string schedule parsing remains.

### New data shape consumed

- `schedules.mass[]`: `{day, start "HH:MM", mass_date, language, notes}`
- `schedules.confession[]`: `{day, start, end, notes}`
- `schedules.adoration`: `{is_perpetual: bool, times: [{day, start, end, notes}]}`
- `latitude`/`longitude`: plain nullable floats (the `lonlat` combined string is gone)
- Legacy keys (`mass_times`, `confessions`, `conf_times`, `www`, `lonlat`) dropped — the new export emits none of them.

### Code changes

- **`lib/utils/schedule_parser.dart`** — gutted the regex line parser. `ScheduleEntry`
  is now built via `ScheduleEntry.fromJson` / `ScheduleEntry.listFromJson` and carries
  `date` (holiday/one-off), `language`, `note`, plus display getters (`dayLabel`,
  `dayName`, `timeLabel`, `display`, `noteLabel`). `ScheduleParser` keeps occurrence
  math only: `findNextOccurrence`, `minutesUntilNext`, `groupByBucket` — all now take
  `List<ScheduleEntry>`. Dated entries occur on their fixed date; past dated entries are
  filtered out of "next/soonest/buckets" via `isPast()`.
- **`lib/models/parish.dart`** — `massTimes`/`confTimes`/`adoration` are now
  `List<ScheduleEntry>` (field names kept to minimize call-site churn). Added
  `adorationIsPerpetual` and `hasAdoration` getter. lat/lon parsed as nullable floats.
- **Consumers** — `timeline_schedule_card`, `next_mass_banner`, `next_mass_tile`,
  `filtered_parish_list_page` all consume entries directly (no more `parseSchedule`).
  Card/preview sites that showed `massTimes.first` as a string now use `.first.display`
  (e.g. "Sun · 9:00 AM"). The timeline card's note now comes from `entry.noteLabel`
  (language + notes); the raw-line fallback and `_extractNote` were removed.
- **Perpetual adoration** — detail page renders a single "Perpetual Adoration" info
  card; filtered list shows a "Perpetual (24/7)" chip and includes perpetual parishes
  in the adoration filter via `hasAdoration`.
- **`test/schedule_parser_test.dart`** — rewritten to test the structured builder,
  display helpers, dated/holiday handling, and occurrence math (18 tests, all pass).

### Verification

- `flutter analyze`: clean (0 issues).
- `flutter test`: all pass. A throwaway smoke test loaded all 189 parishes from
  `export.demo.json` through `Parish.fromJson` without throwing (50 dated holiday Masses,
  249 confession ranges, 7 perpetual adoration, 186/189 with coords).

### Runtime data source — unchanged (deliberate)

`ParishService` still fetches from the remote
`https://raw.githubusercontent.com/mfgarvin/bulletin/refs/heads/main/export.json`.
The user chose to leave this as-is (assumes the remote will serve the new shape).
**Transition risk:** if the remote still serves the *old* shape, `Parish.fromJson` finds
no `schedules` key and all schedules come back empty. `export.demo.json` (new shape, 189
parishes) is available locally for verification but is intentionally **not** bundled.

## Session Log: 2026-05-28 (Detail/Home tweaks + live liturgy)

Four adjustments after the structured-export migration:

### 1. Mass times: weekend / weekday schedule (not a rolling timeline)

- New `lib/widgets/mass_schedule_card.dart`. Replaces `TimelineScheduleCard` for
  **Mass only** on the detail page (Confession & Adoration keep the timeline view).
- Groups regular (non-dated) Masses into **Weekend** (Sunday + Saturday at/after
  noon = Vigil) and **Weekday** (Mon–Fri + Saturday morning). Rows with identical
  time+note collapse across days, e.g. five entries → one `Mon–Fri · 8:00 AM` row.
- Upcoming dated/holiday Masses (next ~21 days) appear in a separate
  **Upcoming / Special** section labelled by date; past dated Masses stay hidden.
- The live "next Mass" feel is still served by the `NextMassBanner` at the top of
  the page; the card is now the standing schedule reference.

### 2. Hamburger menu: removed "Home Parishes"

- `lib/main.dart` — dropped the `home_parishes` PopupMenuItem + case and the now-unused
  `_showHomeParishesPage()`. Menu is Settings / Feedback / About. Home parishes remain
  reachable via the bottom-nav "My Parishes" tab (so this was redundant).

### 3. Alpha build

- `pubspec.yaml` version `1.0.0+1` → `1.0.0-alpha+1`. `AppVersion.display` therefore
  reads "1.0.0-alpha build N" with no code change (PackageInfo.version carries the
  `-alpha`). Android versionName picks it up; versionCode still git-derived.

### 4. Liturgical day tile → live

- New `lib/services/liturgical_service.dart`, two tiers:
  - **`localToday()`** — offline, deterministic. Computus (Meeus) for Easter, then
    Advent / Christmas / Lent / Easter / Ordinary boundaries → season + liturgical
    color + a generic title ("Thursday in Ordinary Time"). Always available.
  - **`fetchEnriched()`** — best-effort GET to `calapi.inadiutorium.cz` general
    calendar for the precise celebration title + memorial + color; cached per-day in
    SharedPreferences; returns null on failure.
- `lib/widgets/liturgical_day_tile.dart` is now stateful: shows the local baseline
  instantly, then swaps in the enriched result if the fetch succeeds. Never empty.
- **calapi networking note:** that host serves HTTPS over **IPv6 only** — its IPv4
  address (37.157.198.11) refuses :443. Browsers reach it via IPv6 (Happy Eyeballs);
  Dart's `HttpClient` on an IPv6-less network fails (errno 101). Tried forcing IPv4 —
  wrong, since calapi's IPv4 refuses 443 (errno 111). Conclusion: do **not** force a
  family. Enrichment simply no-ops on IPv6-less networks (e.g. this dev box); the local
  baseline covers it. On a normal dual-stack device the enrichment works.

### Verification

- `flutter analyze` clean; `flutter test` 18/18 pass.
- Ran on Linux desktop via the Dart MCP tooling and inspected the widget tree (the MCP
  toolset has no screenshot/tap injection, so verification is tree + logs + runtime
  errors): home renders parishes with `Sun · 9:00 AM`-style mass previews; the liturgy
  tile shows `TODAY · GREEN · ORDINARY TIME` / `Thursday in Ordinary Time`; no runtime
  errors. (Detail-page Mass card + hamburger covered by analyze/compile, not yet eyeballed.)

### Follow-up fixes (same day)

- **Search Saint-matching bug** (`lib/utils/search_normalize.dart`). The old expansion
  used `\bsts?\.?\s`, where `sts?` also matched bare "st" — so "St. Sebastian" queries
  became "saints sebastian" and failed to match "Saint Sebastian". Also the trailing `\s`
  meant a half-typed "st"/"st." never expanded. Rewrote to fold **every** variant
  (`saint`, `saints`, `st`, `st.`, `sts`, `sts.`, `ss`, `ss.`) to a single canonical
  `saint` token via `\b(?:saints?|sts|ss|st)\.?(?=\s|$)`, so singular ↔ plural ↔
  abbreviated all intermatch and partial typing works. `\b` + lookahead leave "street",
  "first", "christ" untouched. New `test/search_normalize_test.dart` (7 tests).
- **Location not refreshing on resume** (`lib/main.dart` HomePage, `lib/pages/find_parish_near_me_page.dart`).
  Location was fetched only in `initState`, so reopening from the background kept a stale
  position until a force-quit. Both states now `with WidgetsBindingObserver` and re-call
  `_getUserLocation()` on `AppLifecycleState.resumed` (silent; map preserves the user's
  pan/zoom since the refresh doesn't move the camera).

### Follow-up tweaks (2026-05-29, pt. 2)

- **calapi over HTTP** — its IPv4 serves only port 80 (443 is IPv6-only), so `_base`
  switched to `http://` + a scoped Android cleartext exception
  (`res/xml/network_security_config.xml`, referenced from the manifest). Confirmed LIVE API
  badge + enriched title on the dev box.
- **Liturgical tile is now the liturgical color** (`liturgical_day_tile.dart`) — the whole
  card is `_day.color`; foreground uses a luminance-based `_onColor` (dark ink on White/
  light colors, near-white otherwise); swatch removed; source badge + readings button
  recolored to stay legible on any color.
- **NextMassTile "not today" handling** (`next_mass_tile.dart`) — when the soonest Mass
  isn't today, the when-line generalizes to a part-of-day phrase ("Tomorrow afternoon")
  instead of an exact time, and the "in Xh" countdown is dropped. New `announceNoMoreToday`
  flag (set on the nearby tile in `main.dart`) shows a **"No more today"** chip in that case.
  Today's behavior (exact time + live countdown) is unchanged.

Note: the Flutter widget-inspector (`get_widget_tree`) repeatedly served **stale/cached
frames** this session — don't trust it for verifying async swaps or fresh rebuilds; confirm
via a direct probe, a unit test, or the user.

## Session Log: 2026-06-07 (Language badges, context-aware detail, Worker deployed)

- **Mass language badges.** `ScheduleEntry` gained `languageBadge` (ES/PL/HR/LA…),
  `isEnglish`/`isSpanish`/`isOtherLanguage`. Badges render in the Mass card, Next Mass
  banner, and filtered-list chips via a shared `LanguageBadge`; Mass search gained a
  Spanish / other-language filter.
- **Context-aware detail page.** `ParishDetailPage` takes an optional focus; arriving
  from a Mass/Confession/Adoration search auto-scrolls to that card and flashes a gold
  highlight (~2.5s).
- **Feedback Worker deployed** to `introibo-feedback.mfgarvin.workers.dev` (D1-backed);
  `feedback_endpoint.dart` points at it, so submissions went live. No secrets committed.
- `worker/logs.sh` — interactive D1 viewer (menu + `recent`/`show <id>`/`stats`
  one-shots), resolving the pinned local wrangler and falling back to npx.
- **This file was split out of `CLAUDE.md`** in the same commit (1323 lines removed
  from the always-loaded context file) and finally tracked in git.

## Session Log: 2026-07-21 (Rename to ParishFinder, home parishes, feedback monitoring)

Six weeks after the last session; four separate pieces of work.

- **Home parishes quick launcher.** A horizontal row of saved-parish cards on Home,
  each with its own next-Mass line (`_HomeParishCard`); the standalone next-mass tile
  became nearby-only. Dropped the liturgy tile's LIVE/BUILT-IN source badge — it was a
  testing aid that shipped by accident.
- **Rename Introibo → ParishFinder**, in two tiers: display + code (app title, pubspec
  name, `IntroiboApp` → `ParishFinderApp`, docs), then app identity (Android
  applicationId/namespace/Kotlin package, iOS bundle id + display name, map tile UA).
  Deliberately **not** renamed: the Cloudflare Worker and its D1 (the shipped app points
  at the `introibo-feedback` URL), and this log, which records the earlier
  MassGPT → Introibo rename as it happened.
- **Feedback monitoring.** The Worker gained a Basic-Auth `/admin` dashboard
  (self-contained HTML, filter/search/expand, theme-aware), an `/admin/data` JSON feed,
  and a `scheduled()` Cron handler posting a daily Discord digest (~8am ET) with a
  one-line heartbeat on quiet days. Constant-time password compare; admin routes are not
  CORS-open; secrets set out-of-band via `wrangler secret put`.
- **QA + iOS docs.** `docs/QA_SPEC.md` (hand-off checklist for a lighter model),
  `docs/ios-mac-setup.md`, `docs/feedback-test-plan.md`, and `worker/test-feedback.sh`
  (contract tests for `POST /feedback`; rows carry a `[[QA-SONNET]]` marker because
  submissions hit the **live** D1). iOS config: git-derived build number Run Script, ATS
  cleartext exception, location usage strings.

## Session Log: 2026-07-22 (Armature glass redesign + hero flight fixes)

The per-parish generative stained glass was rebuilt, and two Hero bugs behind it were
found only on a real device.

- **Armature painter.** Replaced the jittered quarry tiling with a Chartres-style panel:
  deep field, faint diaper lattice, corner quatrefoil fleurons, and a centre roundel of
  eight wedges offset by half a wedge so *accent glass* — not a lead line — sits on the
  vertical and reads as an upright cross. Two rules the geometry must keep obeying:
  nothing rotates randomly, and every size is **composed, not cropped** (the old
  `FittedBox` over a fixed 400×200 reference meant a 44px chip was a centre-crop of a
  wide render).
- **Patron-inferred palettes.** 28 palettes (12 pale) across 9 hue families, up from 10
  flat jewel tones; family inferred from what the parish is named after, steered by
  national tradition. 188/189 real names match. **Geometry seed and patron are separate**
  — widgets seed geometry with `parishId ?? name`, and 181 of 189 parishes have an opaque
  id like "0689", so inferring the patron from the seed would have mis-coloured 142 of
  189. Seeds use a stable FNV-1a hash, not `String.hashCode`, which Dart doesn't
  guarantee across VM versions.
- **Hero flight, two bugs.** MaterialApp's default `MaterialRectArcTween` swept the chip
  along a curve, so it read as flying in from off-screen (fixed with a plain `RectTween`);
  and the parish name lived inside the Hero subtree, which renders in the Navigator
  overlay with no Material ancestor — that's what drew the yellow double underline across
  the title mid-flight.
- **Duplicate hero tags across live tabs.** `RootShell`'s `IndexedStack` keeps all three
  tabs alive, so Home's nearby row and the Map carousel both rendered the same parish's
  chip with the same tag; the flight could start from the *offstage* one, parked at the
  bottom of the screen. Fixed with `HeroMode(enabled: i == _index)`. **Debug builds assert
  on the duplicate tag; release builds strip the assert and silently pick one** — which is
  why this only ever appeared on an installed APK.
- Also: first-run data disclaimer + out-of-diocese notice (60mi radius, data-driven),
  a 19px overflow fix in the home-parish card, and `docs/design-language.md` rewritten
  for the new construction.

## Session Log: 2026-07-22 (Favorites keying, schedule readability, versioning)

Reported bugs plus a versioning pass. All device-unverified at time of writing.

- **Home parishes were keyed by parish *name*.** The diocese has six name collisions
  (two "Saint Francis de Sales", three "Saint Mary", …), so favoriting one favorited all
  of them. `FavoritesManager` now keys by `parish_id`, falling back to
  `name|city|address` for the 8 records with no id. The SharedPreferences key
  (`favorite_parishes`) is unchanged and `migrateLegacyKeys()` upgrades old bare-name
  saves on first parish load — an ambiguous legacy name resolves to the first match,
  because the old save simply doesn't record which parish was meant.
- **Weekend Masses sorted by clock time**, burying a 4:30 PM Saturday vigil below the
  9:00 AM Sunday Masses. The Weekend section now sorts by day-then-time; the Weekday
  section still sorts by time, which is correct there.
- **Long schedule notes were unreadable** — a single ellipsized line in the row's
  leftover ~120px, and some notes run past 100 characters. Notes ≤28 chars stay inline;
  longer ones get a full-width line under the time, untruncated. Same treatment in the
  confession/adoration timeline card.
- **Versioning hardened.** The pubspec `+N` is now a committed *floor* rather than a
  fallback: builds take `max(commit count, floor)`, so a squash-merge or rebase that
  shortens history can't hand Play a lower versionCode. A **release** build that can't
  read the commit count now fails loudly instead of silently shipping build 1; debug
  builds still fall back. New `tool/release.sh` (`beta`/`release`/`patch`/`minor`/
  `major`/`show`, `--dry-run`, `--no-tag`) bumps the version, commits, and tags — it
  also keeps the floor in step with the commit count, which is what makes the floor
  meaningful. Note there is **no JVM on the dev box**, so the Gradle change is unverified
  until an APK build runs.
- **`invite_feedback` support.** New `Parish.inviteFeedback` (from the export field,
  true for 13 of 189 parishes whose schedule was never machine-verified from a bulletin)
  drives an `InviteFeedbackCard` under the next-Mass banner, opening the existing
  feedback sheet. Gold, phrased as an invitation rather than a warning — the parish isn't
  at fault. Defaults to false when the key is absent, which matters for JSON cached
  before the field existed. Note the local `export.demo.json` predates the field;
  `../bulletin-v2/export.json` is the current shape.
