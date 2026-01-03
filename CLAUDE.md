# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MassGPT is a Flutter mobile application for finding Catholic parishes and mass times in the Cleveland/Akron, Ohio area. It provides two main features:
1. **Research a Parish** - Search parishes by name, city, or ZIP code
2. **Find a Parish Near Me** - Interactive map showing nearby parishes using GPS

## Commands

```bash
flutter pub get              # Install dependencies
flutter analyze              # Run static analysis (uses flutter_lints)
flutter test                 # Run all tests
flutter test test/widget_test.dart  # Run single test file

flutter run                  # Run on default device (Linux desktop in dev)
flutter run -d linux         # Run on Linux desktop
flutter run -d chrome        # Run in Chrome (requires Chrome installed)

flutter build apk            # Build Android APK
flutter build ios            # Build iOS (requires macOS)
flutter build linux          # Build Linux desktop
```

## Architecture

### Application Flow

```
main.dart (MassGPTApp)
    └── HomePage
            ├── "Research a Parish" → ResearchParishPage → ParishDetailPage
            └── "Find a Parish near me" → FindParishNearMePage → ParishDetailPage
```

### Core Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry point, theme config, HomePage with two navigation buttons |
| `lib/globals.dart` | Global ParishService singleton (currently unused - data loaded locally) |
| `lib/models/parish.dart` | Parish data model with `fromJson` factory |
| `lib/services/parish_service.dart` | HTTP-based parish loader (unused - kept for future API integration) |

### Pages

| Page | Purpose |
|------|---------|
| `lib/pages/research_parish_page.dart` | Search UI with debounced text input, filters by name/city/zip |
| `lib/pages/find_parish_near_me_page.dart` | OpenStreetMap view with GPS location and parish markers |
| `lib/pages/parish_detail_page.dart` | Displays parish info: address, mass times, confession times, phone, website |

### Data Flow

Both `ResearchParishPage` and `FindParishNearMePage` load parish data independently from the local JSON asset:
```dart
rootBundle.loadString('data/parishes.json')  // or DefaultAssetBundle.of(context).loadString()
```

The `ParishService` in `lib/services/` exists for future HTTP-based loading but is currently commented out in `main.dart`.

### Data Model

`Parish` class fields:
- `name`, `address`, `city`, `zipCode`, `phone`, `website`
- `massTimes: List<String>` - e.g., `["Sunday: 10:30AM", "Monday: 8:00AM"]`
- `confTimes: List<String>` - confession schedule
- `latitude`, `longitude` - nullable, used for map markers
- `contactInfo` - optional

JSON field mapping: `zip_code`, `www`, `mass_times`, `conf_times`, `contact_info`

### Key Dependencies

- `flutter_map` + `latlong2` - OpenStreetMap tile rendering and coordinates
- `geolocator` + `permission_handler` - GPS location with permission handling
- `flutter_dotenv` - Environment variables (imported but currently unused)

### Theme

Defined as global constants in `main.dart` (inspired by [travel_app](https://github.com/Shadow60539/travel_app)):
- `kBackgroundColor`: `#FEFEFE` (off-white)
- `kPrimaryColor`: `#3F95A1` (teal)
- `kSecondaryColor`: `#003366` (dark blue)
- `kCardColor`: `Colors.white`

Typography uses Google Fonts (Lato) via the `google_fonts` package.

## Development Notes

### Dev Location Override

In `lib/pages/find_parish_near_me_page.dart`, a mock location is used in debug builds to bypass GPS:

```dart
const LatLng? kDevLocation = kDebugMode
    ? LatLng(41.48, -81.78)  // Lakewood, OH
    : null;
```

- In debug mode (`flutter run`): uses mock location, skips Geolocator
- In release builds: uses real GPS
- To test with different locations: change the coordinates
- To test real GPS in debug: set `kDevLocation` to `null`

### OSM Tile Configuration

The map uses OpenStreetMap tiles without subdomains (per OSM guidelines):
```dart
urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
```

### Parish Data

`data/parishes.json` contains ~80+ parishes in Ohio with coordinates. Sample entry:
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
  "mass_times": ["Sunday: 9:00AM", "Saturday: 4:00PM"],
  "conf_times": ["Saturday: 3:15PM to 3:45PM"]
}
```

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
