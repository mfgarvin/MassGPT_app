# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ParishFinder is a Flutter mobile application for finding Catholic parishes and mass times in the Cleveland/Akron, Ohio area. It provides two main features:
1. **Research a Parish** - Search parishes by name, city, or ZIP code
2. **Find a Parish Near Me** - Interactive map showing nearby parishes using GPS

## Commands

```bash
flutter pub get              # Install dependencies
flutter analyze              # Run static analysis (uses flutter_lints)
flutter test                 # Run all tests
flutter test test/schedule_parser_test.dart  # Run a single test file

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
main.dart (ParishFinderApp)
    └── RootShell (bottom NavigationBar over an IndexedStack — tabs keep state)
            ├── Home tab     → HomePage
            │                    ├── inline search → ParishDetailPage
            │                    ├── "Looking for" quick filters → FilteredParishListPage → ParishDetailPage
            │                    ├── nearby / next-mass tiles → ParishDetailPage
            │                    └── liturgical day tile
            ├── Map tab      → FindParishNearMePage (inTab) → ParishDetailPage
            └── My Parishes  → FavoritesPage (inTab) → ParishDetailPage
```

`ResearchParishPage` still exists as a standalone search page but is no longer the
primary entry point — HomePage has inline search.

### Core Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry point, theme constants, `ThemeNotifier`, `FavoritesManager`, `RootShell` (bottom nav), `HomePage`, and the Settings/Feedback/About/Favorites pages |
| `lib/models/parish.dart` | `Parish` model with `fromJson`; schedules parsed into `ScheduleEntry` lists |
| `lib/services/parish_service.dart` | Remote JSON loader with local cache; global `parishService` singleton |
| `lib/utils/schedule_parser.dart` | Structured `ScheduleEntry` + occurrence math (schedule parser) |
| `lib/services/liturgical_service.dart` | Offline Computus baseline + best-effort calapi enrichment |
| `lib/services/feedback_client.dart` | POSTs feedback to the Cloudflare Worker endpoint |
| `lib/widgets/` | Stained-glass header, mass/timeline schedule cards, next-mass banner/tile, liturgical day tile, custom icons |

### Pages

| Page | Purpose |
|------|---------|
| `lib/pages/parish_detail_page.dart` | Full parish detail: header, schedules, contact, bulletin, feedback |
| `lib/pages/filtered_parish_list_page.dart` | Mass/Confession/Adoration filtered lists with sort + day/time filters |
| `lib/pages/find_parish_near_me_page.dart` | OSM map (Map tab) with GPS, markers, and a swipeable parish carousel |
| `lib/pages/research_parish_page.dart` | Standalone search UI (debounced; name/city/zip) |

### Data Flow

All pages read from the global `parishService` singleton
(`lib/services/parish_service.dart`), which loads cache-then-network:

1. Instant: last-good JSON from SharedPreferences (may be stale → offline warning).
2. Authoritative: fetched from the remote `export.json`, then cached.

```dart
static const _remoteUrl =
    'https://raw.githubusercontent.com/mfgarvin/bulletin/refs/heads/main/export.json';
```

There is no bundled parish data asset — first launch requires a
network connection (an "Internet Required" screen handles that case). Use the local
`export.demo.json` (new shape, 189 records across 184 parishes — refreshed from
live 2026-08-04) for inspection. Records outnumber parishes because a parish with
multiple worship sites gets one record each; `parish_id` is the identity, not
`name` (six names repeat across cities).

### Data Model

`Parish` (`lib/models/parish.dart`) fields:
- `name`, `address`, `city`, `zipCode`, `phone`, `website`
- `parishId` — optional unique identifier
- `massTimes`, `confTimes`, `adoration` — `List<ScheduleEntry>` (pre-parsed; nothing downstream parses schedule strings)
- `adorationIsPerpetual: bool` + `hasAdoration` getter
- `weeksOfMonth` / `excludedWeeks` on `ScheduleEntry` — monthly-ordinal
  recurrence. **Every** recurrence decision goes through
  `ScheduleEntry.occursOn(day)`, which answers dated, weekly and monthly alike;
  answering "is it on today" from `dayOfWeek` alone is wrong for these entries.
  UI that collapses entries sharing a time into one multi-day row must include
  `recurrenceKey` in its grouping key, or a First Friday Mass merges with a
  weekly one and the row claims both happen every week. The ordinal is rendered
  (`ordinalShortLabel`) only where a view asserts a *standing weekly schedule* —
  the Mass card and the A–Z list's `_groupChip` — not on the confession/adoration
  timeline card, whose rows are single upcoming occurrences already bucketed
  through `nextOccurrence`.
- `bulletinUrl`, `eventsSummary`, `imageUrl`, `contactInfo` — optional
- `latitude`, `longitude` — nullable plain floats (now present in the data)
- `lastUpdated` — parsed from the per-record `timestamp`
- `inviteFeedback: bool` — from `invite_feedback`; true (14 parishes as of the 2026-08-04 data) means the schedule was never machine-verified from a bulletin, so `ParishDetailPage` shows an `InviteFeedbackCard` under the next-Mass banner asking the user to confirm or correct the times. Defaults to false if the key is missing (older cached JSON).

JSON comes from the **structured** `export.json` shape:
- `schedules.mass[]`: `{day, start "HH:MM", mass_date, language, notes}`
- `schedules.confession[]`: `{day, start, end, notes}`
- `schedules.adoration`: `{is_perpetual, times: [{day, start, end, notes}]}`
- plain numeric `latitude`/`longitude`, plus `bulletin_url`, `timestamp`, `invite_feedback`
- optional `weeks_of_month` / `excluded_weeks` (`int[]`, domain `1`–`5` and `-1`)
  on any schedule entry: monthly-ordinal recurrence ("First Friday", "Last
  Sunday"). Absent/null/empty all mean *every week* — the app must not
  distinguish them. **Live in the data as of 2026-09-02**: 57 entries across
  40 parishes (mass, confession and adoration alike), values `1` (45), `2`
  (7), `-1` (4) and `3` (1). No `excluded_weeks` in the wild yet. The
  ordinal-recurrence code paths are therefore exercised by real records now,
  not inert.
- Legacy keys (`mass_times`, `confessions`, `conf_times`, `www`, `lonlat`) are gone.

### Key Dependencies

- `flutter_map` + `latlong2` — OpenStreetMap tile rendering and coordinates
- `geolocator` + `permission_handler` — GPS location with permission handling
- `google_fonts` — Inter (body) + Cormorant Garamond (display)
- `flutter_svg` — custom Catholic icons (monstrance, confessional)
- `http` — remote parish data, feedback, liturgy API
- `shared_preferences` — favorites + caches
- `url_launcher`, `cached_network_image`, `package_info_plus`

### Theme

Global constants in `main.dart` — **warm parchment + oxblood + gold** (light) /
**true black + candlelight gold** (dark):
- `kBackgroundColor`: `#FAF6EE` (warm cream parchment) · `kBackgroundColorDark`: `#000000` (OLED black)
- `kPrimaryColor`: `#8C1F1F` (deep oxblood) · `kSecondaryColor`: `#4A2828` (deep plum)
- `kAccentGold`: `#C9A227` (ornament only) · `kAccentGoldDeep`: `#8C5A14` (text-safe) · `kAccentCandlelight`: `#D4A24A` (dark-mode accent)
- `kCardColor`: `#FFFCF4` · `kCardColorDark`: `#14100F`
- Helpers `primaryAccentFor({isDark})` / `goldTextAccentFor({isDark})` — gold is too low-contrast as text on parchment, so accent *text* routes through these.

Typography: a unified scale in `lib/theme/app_text.dart`. **Inter** for body/UI,
**Cormorant Garamond** for display (app title, headings, parish names). Prefer the
`AppText` scale over inline `GoogleFonts.x(fontSize: …)`.

Theme choice is tri-state — `ThemeNotifier.choice` is `system` / `light` / `dark`,
persisted under `theme_choice`, and `system` resolves against the platform
brightness (with a `didChangePlatformBrightness` observer, so the app follows the
phone live). Everything that paints still reads `themeNotifier.isDarkMode`; the
legacy `dark_mode` bool is only read for migration and written for explicit
choices.

### Text scaling

Flutter scales *text* with the accessibility font setting, but a `width: 128`
column or a `height: 176` card does not — so at 2× the text grows into a box that
didn't, and you get a name rendered one letter per line or a debug overflow
stripe. `lib/utils/layout_scale.dart` is the convention:

- `context.scaled(size, max:)` — grow a fixed dimension with the text, capped.
- `context.prefersStackedLayout` — true at ≥1.5×, meaning "these two things can
  no longer share a row". Used to stack a trailing badge under its content
  (list cards, the next-Mass banner, the address card's action) and to drop
  decoration that costs the text its width (the map card's glass chip, the Home
  greeting card's icon).
- Trailing widgets in a `Row` take their natural width and leave the rest to the
  `Expanded` beside them — cap them, or the content starves.
- `MediaQuery.withClampedTextScaling` for text that is a credit or an
  identifier rather than content (the OSM attribution, the version string).

`test/page_scaling_smoke_test.dart` pumps every screen at 1× and 2× and scrolls
it — an overflow is an exception in a test, so it fails loudly. Precise
per-widget cases live in `test/text_scaling_test.dart`.

**Any test that measures rendered text must call `loadAppFonts()` from
`test/support/test_fonts.dart` in `setUpAll`.** google_fonts registers Inter
asynchronously, so without it a measurement gets fallback metrics or Inter
metrics depending on what ran earlier in the file — the assertion becomes
order-dependent, not wrong-looking, just flaky.

Schedule day chips (Mass card and the Confession/Adoration timeline card) share
their sizing via `lib/widgets/day_chip_text.dart` so the same "Sat" is set the
same in all three cards on a parish page.

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
- To test real GPS in debug: **`--dart-define=REAL_GPS=1`** (no code edit)

That flag exists for the **iOS Simulator**, which only ever runs debug builds
(`IOSSimulator.supportsRuntimeMode` accepts `BuildMode.debug` alone) — without
it, every simulator run ignores Xcode's simulated location and thinks it is in
Lakewood.

This mock is the **only** behavioural difference between debug and release, so
`debugShowCheckedModeBanner` is deliberately left at its default — the DEBUG
ribbon is what distinguishes a location-mocked build on screen. Don't set it to
`false`. `tool/ios_build.sh` refuses to bless a debug IPA for the same reason.

### OSM Tile Configuration

The map uses OpenStreetMap tiles without subdomains (per OSM guidelines):
```dart
urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
```

Tiles are recoloured to match the theme by a `ColorFilter.matrix` on the
`TileLayer` only (never the markers): `_parchmentFilter` in light mode, and in
dark mode `_nightFilter` — invert ∘ hue-rotate 180° ∘ warm desaturation, which
is what keeps the dark map labels legible instead of dimming them into the
land. The rotation is what stops inverted Lake Erie from turning orange, and
warming it further past the current tuning is what turns the lake olive and
indistinguishable from land — the map's blue is worth more than the warmth
here. The map is also locked north-up (`InteractiveFlag.rotate` removed).

### Parish Data

Data is fetched at runtime from the remote `export.json` (184 parishes, Cleveland/Akron
area) — see Data Flow above. The **structured** shape (sample, abbreviated):
```json
{
  "name": "St. Sebastian Parish",
  "parish_id": "0689",
  "address": "476 Mull Ave",
  "city": "Akron",
  "zip_code": "44320",
  "phone": "330-836-2233",
  "website": "www.stsebastian.org",
  "latitude": 41.0915,
  "longitude": -81.5621,
  "bulletin_url": "https://…",
  "timestamp": "2026-05-20",
  "schedules": {
    "mass": [
      {"day": "sunday", "start": "09:00", "mass_date": null, "language": "en", "notes": null},
      {"day": "saturday", "start": "16:30", "mass_date": null, "language": "en", "notes": "Vigil"}
    ],
    "confession": [
      {"day": "tuesday", "start": "19:00", "end": "19:30", "notes": null}
    ],
    "adoration": {"is_perpetual": false, "times": [
      {"day": "tuesday", "start": "08:30", "end": "19:40", "notes": null}
    ]}
  }
}
```

**Note:** Coordinates are now present in the data (`latitude`/`longitude` as plain floats),
so the map and distance-based sorting work. The full structured shape and migration notes
live in `EXPORT_SHAPE_CHANGES.md` **in the scraper repo** (`../bulletin-v2`) — that copy is
authoritative; `export.demo.json` is a local copy of the data for inspection.

## Two machines (Linux + macOS)

Work is split across a Linux dev box and a Mac. **If a tool other than Xcode can
do it, it happens on Linux** — Dart, tests, Android builds, `tool/release.sh`,
the worker, the site, and text-level iOS config (`Info.plist`, bundle IDs, the
build-number script) are all plain files.

**macOS is for iOS only**: Xcode UI changes (signing team, capabilities),
Simulator/device testing, and archiving/uploading. **Never run
`tool/release.sh` on the Mac** — versions are bumped and tagged in one place, on
Linux, or the two checkouts race the tag.

**There is no CocoaPods here.** Flutter 3.47.0 moved plugin registration to
Swift Package Manager, so `ios/Podfile`/`Podfile.lock` do not exist and never
will; the plugins link via a regenerated, gitignored local package at
`ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage`. See
[`docs/ios-testflight.md`](docs/ios-testflight.md) ("No Podfile, by design").

Protocol: `main` only, one machine at a time, `git pull --rebase` before
starting, commit and push before switching. Xcode rewrites `project.pbxproj`
just by opening the project — commit that churn on its own, never mixed into
Dart work. Keep Flutter versions in step across machines — both are pinned at **3.47.0**
(Linux runs a git clone at that tag in `~/development/flutter`, not the snap,
whose stable channel stalled at 3.38.5).

iOS builds go through **`tool/ios_build.sh`**, which strips the pubspec's
prerelease suffix because `CFBundleShortVersionString` must be purely numeric —
Apple rejects `1.0.0-beta.7`. The beta identity rides on the build number
instead, which is all TestFlight requires to increase. Bundle ID is
`app.parishfinder` (permanent once the App Store Connect record exists).
Full runbook: [`docs/ios-testflight.md`](docs/ios-testflight.md).

## Change History

Dated session-by-session change logs have been moved out of this file to keep it lean (it loads into context every session). See [`docs/session-history.md`](docs/session-history.md) for the full chronological record, including the `Future Enhancements` notes.

A few non-obvious facts from that history worth keeping in view here:

- **Schedule data is fully structured** (no regex string parsing). `Parish.massTimes`/`confTimes`/`adoration` are `List<ScheduleEntry>` built from `schedules.*` in the remote `export.json`. See `lib/utils/schedule_parser.dart`.
- **Liturgy tile** uses an offline Computus baseline (`LiturgicalService.localToday`) plus best-effort enrichment from calapi.inadiutorium.cz, which is reachable only over **plain HTTP** (its IPv4 refuses 443); Android cleartext is scoped to that domain in `res/xml/network_security_config.xml`.
- **Feedback Worker** (`worker/`) is **deployed** to Cloudflare at `https://api.parishfinder.app` (D1-backed; account per `wrangler whoami`) — on our own zone, so zone-scoped WAF/rate-limiting rules can reach it. The old `introibo-feedback.mfgarvin.workers.dev` route was **retired 2026-08-02** (`workers_dev = false`); pre-beta.1 APKs pointing there can no longer submit. `/admin*` is behind **Cloudflare Access** (one-time PIN), with the Worker's Basic Auth kept as defence in depth. The Worker/D1 keep the old `introibo-feedback` name on purpose. `lib/config/feedback_endpoint.dart` defaults to `https://api.parishfinder.app/feedback`, so submissions are live; override per-build with `--dart-define=FEEDBACK_ENDPOINT=…`. Redeploy/inspect via `worker/README.md` (`wrangler deploy`, `wrangler d1 execute …`).
- **Feedback monitoring**: the Worker now serves a Basic-Auth admin dashboard at `/admin` (secret `ADMIN_PASSWORD`) and posts a **daily Discord digest** via `scheduled()` on a `[triggers] crons = ["0 12 * * *"]` Cron Trigger (~8am ET) to the `DISCORD_WEBHOOK_URL` secret (optional `DASHBOARD_URL` link). Trigger manually with `POST /admin/digest`. `worker/logs.sh` remains a CLI viewer but needs local `wrangler login`. Secrets are **not** in git — set via `wrangler secret put` before the digest/dashboard work.
- **Coverage / "you're outside the diocese"**: decided by a point-in-polygon test
  against `assets/data/diocese_boundary.json` (`lib/services/diocese_boundary.dart`,
  preloaded in `main()`), not by distance. The asset is **generated** by
  `tool/gen_diocese_boundary.py` from US Census county boundaries — never
  hand-edit it. The diocese is eight counties: Ashland, Cuyahoga, Geauga, Lake,
  Lorain, Medina, Summit, Wayne (Ashtabula and Portage are **Youngstown**). The
  old "nearest parish > 60 miles" rule survives only as a fallback if the asset
  fails to load, and no radius can do this job: Kent is five miles from our Stow
  parishes and belongs to Youngstown, while rural Ashland County is 25 miles from
  anything we list — the same distance as Sandusky, which is Toledo.
  `test/diocese_boundary_test.dart` pins one town per county plus the neighbours.

- **Favorites/"Home Parishes"**: the user-facing label is "home parishes" but the SharedPreferences key (`favorite_parishes`) and class names (`FavoritesManager`/`FavoritesPage`) were deliberately left unchanged to preserve existing saves.
- **Versioning**: semver lives in `pubspec.yaml` and is bumped by **`tool/release.sh`** (`beta` / `release` / `patch` / `minor` / `major` / `show`), which rewrites the version, commits, and tags `vX.Y.Z`. Never hand-edit the version line.
- **Build number** is git-derived (`git rev-list --count HEAD`) on both platforms: Android via `gitBuildNumber` in `android/app/build.gradle`; iOS via a "Set Build Number From Git" Xcode Run Script phase that rewrites `CFBundleVersion` (in `ios/Runner.xcodeproj/project.pbxproj`, **untested on a Mac** as of 2026-07-16). The pubspec `+N` is a committed *floor* (kept in step with the commit count by `tool/release.sh`) — builds take `max(commit count, floor)`, so a rewritten history can't lower the number. **Release** builds with no usable git hard-fail rather than fall back; debug builds still fall back to the floor.
- **iOS cleartext**: the liturgy API's plain-HTTP exception is scoped in `ios/Runner/Info.plist` via `NSAppTransportSecurity → NSExceptionDomains` (`calapi.inadiutorium.cz`), mirroring the Android `network_security_config.xml`. Location usage strings are also present; bundle id + signing + app icons still need a Mac.
