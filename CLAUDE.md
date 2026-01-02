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

Defined in `main.dart:_buildThemeData()`:
- Primary/Background: `#003366` (dark blue)
- Accent/Secondary: `#FFA500` (orange)
- Text: `#FFFDD0` (cream)

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
