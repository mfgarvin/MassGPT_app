# iOS / Mac Setup — Pick-up Guide

> **2026-08-19: partly superseded.** The Mac and the Apple Developer
> account now exist, so the "Getting a Mac" section below is history.
> For the machine split and the TestFlight path, read
> [`ios-testflight.md`](ios-testflight.md) first; the rest of this file
> — what's configured, and what was written blind on Linux — still
> applies.

> Notes for shipping **ParishFinder** on iOS, written to be read cold when you return
> to this. Everything below assumes you're picking up on a Mac. Nothing here can
> be finished on the Linux dev box — iOS builds, the Simulator, and code signing
> are macOS + Xcode only.

> **CocoaPods references below are obsolete.** Flutter 3.47.0 moved plugin
> registration to Swift Package Manager; there is no `ios/Podfile`. See
> [`ios-testflight.md`](ios-testflight.md), "No Podfile, by design".

---

## The one hard blocker

You need **macOS + Xcode**. You cannot build, run, or ship iOS from Linux.
Beyond the machine, you need the **Apple Developer Program ($99/yr)** to run on a
physical device, use TestFlight, or submit to the App Store.

## Getting a Mac (options)

For the first pass you want an **interactive** Mac (hands-on Xcode), not headless CI.

**Interactive rented Macs:**
- **MacinCloud** — pay-as-you-go hourly/monthly; lowest friction for a one-afternoon session.
- **AWS EC2 Mac** (`mac1`/`mac2`) — real cloud Mac minis, but **24-hour minimum** allocation per instance → pricey for short one-offs. Good if already in AWS.
- **MacStadium** — dedicated/monthly hosting, team-oriented; overkill for a one-time verify.
- **Scaleway Apple silicon** (EU) — hourly, often cheaper.

**CI / build automation (later, once signing works):**
- **Codemagic** — Flutter-native, free macOS build minutes; easiest "push from Linux → IPA/TestFlight." Likely the long-term answer.
- **GitHub Actions** `macos-latest` — free minutes on public repos, metered on private.
- **Xcode Cloud** — Apple's own, integrates with App Store Connect.

**Reality check:** rental adds up. If iOS becomes more than occasional, a **base Mac
mini** pays for itself vs. a few months of cloud rental and gives a zero-latency local
Simulator. For a true one-time "verify + set up signing," MacinCloud hourly (or borrow a
Mac for 30 min) is cheapest. Pricing figures change — **confirm current rates** before
committing. On an ephemeral/rented Mac you'll re-import your Apple certs/profiles each
session.

---

## What's already done in the repo (no Mac needed)

- Full `ios/Runner` Xcode project + workspace exist.
- **Location permission strings** present in `ios/Runner/Info.plist`
  (`NSLocationWhenInUseUsageDescription` + `...AlwaysAndWhenInUse`) — avoids the
  classic geolocator/permission_handler crash-on-launch.
- Deployment target **iOS 12.0**; portrait + landscape configured.
- Every plugin used is iOS-compatible (`flutter_map`, `geolocator`,
  `permission_handler`, `url_launcher`, `flutter_svg`, `cached_network_image`,
  `shared_preferences`, `package_info_plus`, `http`). No dependency blockers.

## Done on Linux 2026-07-16 — but UNVERIFIED on a Mac (verify these first)

1. **ATS cleartext exception** — `ios/Runner/Info.plist` now has
   `NSAppTransportSecurity → NSExceptionDomains` scoped to
   `calapi.inadiutorium.cz` (`NSExceptionAllowsInsecureHTTPLoads` +
   `NSIncludesSubdomains`). Mirrors the Android
   `android/app/src/main/res/xml/network_security_config.xml`.
   *Why:* that liturgy API refuses HTTPS on IPv4 (port 443 refused; HTTP returns
   200 — re-confirmed 2026-07-16), so without this exception the liturgy tile
   silently loses API enrichment on iOS (falls back to the offline Computus
   baseline; no crash). Validated as a well-formed plist via python; **not** yet
   validated by Xcode.

2. **Git-derived build number** — added a **"Set Build Number From Git"** Run
   Script build phase to `ios/Runner.xcodeproj/project.pbxproj`
   (UUID `D7A1F0011CF9000F00AAAA01`; runs after *Embed Frameworks*, before
   *Thin Binary*). It sets `CFBundleVersion` from `git rev-list --count HEAD` via
   `PlistBuddy`, and no-ops safely (keeping the pubspec build number) when git is
   unavailable. This is the iOS analog of `gitBuildNumber` in
   `android/app/build.gradle`.
   ⚠️ **The pbxproj was hand-edited on Linux and is untested.** Only brace/paren
   balance + UUID-reference count were checked. **Open `Runner.xcworkspace` in
   Xcode (or run `xcodebuild`) before trusting it.** Reverting is easy: remove the
   one line in the Runner target's `buildPhases` and the phase definition block —
   both tagged with UUID `D7A1F0011CF9000F00AAAA01`.

## Still needs a Mac (deferred)

- **Bundle identifier** — still the placeholder `$(PRODUCT_BUNDLE_IDENTIFIER)`.
  Pick a real reverse-DNS id (e.g. `com.mfgarvin.parishfinder`), register it in your
  Apple Developer account. (Note: Android `applicationId` is still
  `com.example.parishfinder` in `android/app/build.gradle` — worth fixing too.)
- **Signing** — set a team + provisioning profile; Xcode "Automatically manage
  signing" is fine to start.
- **App icon** — verify `ios/Runner/Assets.xcassets/AppIcon` has the full iOS
  icon set (separate from Android). Easiest via the `flutter_launcher_icons`
  package.

---

## First 30 minutes on the Mac (checklist)

Do these in order so you're not debugging on a metered clock:

```bash
# 0. Toolchain present
flutter doctor                      # expect Xcode green

# 1. Deps
flutter pub get                     # plugins link via SPM; there is no pod install step

# 2. Verify the hand-edited project opens cleanly
open ios/Runner.xcworkspace         # must open with NO "project is damaged" error
#    In Xcode: Runner target → Build Phases → confirm "Set Build Number From Git" exists
#    and sits after "Embed Frameworks", before "Thin Binary".

# 3. Signing + identity (Xcode → Runner → Signing & Capabilities)
#    - set Team, set Bundle Identifier (e.g. com.mfgarvin.parishfinder)

# 4. Run on the Simulator
open -a Simulator
flutter run                         # smoke-test the app end to end

# 5. Confirm the build-number phase fired
#    After a build, check the built app's CFBundleVersion == `git rev-list --count HEAD`:
git rev-list --count HEAD           # compare to the value baked into the build
```

Things to actually check while it's running:
- **Location prompt** appears and Nearby / Map work (real GPS or Simulator's
  Features → Location).
- **Liturgy tile** shows the precise feast/memorial (proves the ATS exception
  works) — not just the generic offline season title.
- No red runtime errors on the Home tab (the new "Your Home Parishes" row and the
  Nearby row share a screen; the home-parish card intentionally has no Hero to
  avoid a duplicate-Hero-tag crash).

## Release build (once signing works)

```bash
flutter build ipa --build-number=$(git rev-list --count HEAD)
```

Then: **TestFlight** for beta, **App Store Connect** for submission (screenshots,
privacy nutrition labels — you use location, so declare it). The `--build-number`
flag is belt-and-suspenders; the Xcode Run Script phase should already set it, but
passing it explicitly guarantees no TestFlight "build 1" collisions if that phase
misbehaves.

---

## Related files
- `ios/Runner/Info.plist` — permissions + ATS exception
- `ios/Runner.xcodeproj/project.pbxproj` — build-number Run Script phase
- `android/app/build.gradle` — the `gitBuildNumber` this mirrors
- `android/app/src/main/res/xml/network_security_config.xml` — the cleartext config this mirrors
- `lib/services/liturgical_service.dart` — why the cleartext exception is needed
- `CLAUDE.md` — the "Build number" + "iOS cleartext" bullets summarize this
</content>
</invoke>
