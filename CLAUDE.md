# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MassGPT is a Flutter mobile application for finding Catholic parishes and mass times. It supports searching parishes by name/city/zip and locating nearby parishes using GPS with an interactive map.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Run app in debug mode
flutter run

# Build for platforms
flutter build apk      # Android
flutter build ios      # iOS
flutter build web      # Web
```

## Architecture

### Core Structure
- `lib/main.dart` - Entry point, app theme configuration, HomePage widget
- `lib/globals.dart` - Global state with ParishService singleton
- `lib/models/parish.dart` - Parish data model with JSON deserialization
- `lib/services/parish_service.dart` - Parish data loading from local JSON asset

### Pages
- `lib/pages/research_parish_page.dart` - Search UI with real-time filtering
- `lib/pages/find_parish_near_me_page.dart` - Map view with GPS location
- `lib/pages/parish_detail_page.dart` - Individual parish details

### Data
- `data/parishes.json` - Local parish dataset (~80+ parishes with coordinates)
- Data loaded via `rootBundle.loadString('data/parishes.json')`

### Key Dependencies
- `flutter_map` + `latlong2` - OpenStreetMap-based mapping
- `geolocator` + `permission_handler` - GPS location with permissions

### Theme Colors
- Primary: `#003366` (dark blue)
- Accent: `#FFA500` (orange)
- Text: `#FFFDD0` (cream)
