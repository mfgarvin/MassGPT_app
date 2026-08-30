# iOS: two machines, and the road to TestFlight

Written 2026-08-19, when the Mac came online with an Apple Developer account.
Supersedes the "getting a Mac" section of [`ios-mac-setup.md`](ios-mac-setup.md);
the rest of that file (what's already configured, what was never Mac-verified)
still applies.

---

## Who does what

The split follows one rule: **if a tool other than Xcode can do it, it happens on
Linux.** The Mac exists for the things only macOS can do, and every minute of
divergence between the two checkouts is a merge waiting to happen.

**Linux (primary — all revision work)**
- Dart: features, fixes, refactors, `flutter test`, `flutter analyze`.
- Android builds and releases; `tool/release.sh`; version bumps and tags.
- The Cloudflare worker, the site, the docs, the parish-data tooling.
- **Text-level iOS config**: `Info.plist`, bundle identifiers, entitlements
  values, the build-number script. These are plain files — editing them here
  costs nothing and keeps the Mac session short.

**macOS (iOS-only)**
- Anything Xcode changes through its UI: signing team, capabilities, schemes.
- Nothing for CocoaPods to do — see "No Podfile, by design" below. There is no
  `ios/Podfile` to generate or commit.
- Simulator and device testing, archiving, uploading to App Store Connect.
- Verifying things that were written blind on Linux — chiefly the ATS exception
  and the "Set Build Number From Git" run-script phase, neither of which has
  ever executed on a Mac.

**Never on the Mac:** `tool/release.sh`. Versions are bumped and tagged in one
place, here, or the two machines will race the tag.

## The git protocol

`main` only, one machine at a time — there's one developer, so branches buy
nothing but merge overhead.

1. **Before starting anywhere:** `git pull --rebase`.
2. **Before switching machines:** commit and push. An uncommitted change on the
   idle machine is the failure mode to design against.
3. **Xcode rewrites `project.pbxproj` just by opening the project.** Commit that
   churn on its own (`Xcode: <what changed>`), never mixed into Dart work — a
   pbxproj conflict inside a feature commit is miserable to resolve.
4. **Keep Flutter versions in step.** Both machines are on **3.47.0**. Linux
   runs a git clone pinned at that tag in `~/development/flutter` — *not* the
   snap, whose stable channel stalled at 3.38.5 and could never reach 3.47. A
   mismatch churns `pubspec.lock` on every switch, and a large enough gap
   replays an entire iOS project migration (that is what the SPM move was).
5. First thing on the Mac, before anything else: `git status`. Whatever iOS
   files the Xcode session already generated need to be committed and pushed
   before Linux touches `ios/` again.

---

## No Podfile, by design

**This project does not use CocoaPods.** Don't go looking for `ios/Podfile` or
`ios/Podfile.lock` — they will never appear, and their absence is not a sign
that the build is incomplete or that a step was skipped.

The Flutter 3.47.0 upgrade migrated plugin registration to **Swift Package
Manager**. `ios/Runner.xcodeproj/project.pbxproj` holds an
`XCLocalSwiftPackageReference` to
`Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage`, and that local
package is what links geolocator, permission_handler, url_launcher and the rest
into the app. Flutter **regenerates it on every build**, and `ios/.gitignore`
ignores `Flutter/ephemeral/` — so there is nothing to commit, on either machine.

This is also the migration that caused the 2026-08-19 conflict, when the Mac was
on 3.47.0 and Linux was still on 3.38.5. Hence rule 4 above.

---

## Blockers found 2026-08-19 (two now fixed here)

**1. Bundle ID was still `com.example.parishfinder`** — Apple will not let you
register a `com.example.*` identifier. Changed to **`app.parishfinder`**,
matching the Android application ID and the parishfinder.app domain. It is
**permanent from the moment the App Store Connect record is created**, exactly
like the Play app ID, so confirm you want that string before registering it.

**2. Export compliance** — added `ITSAppUsesNonExemptEncryption = false` to
`Info.plist`. The app uses only HTTPS through the OS, which is exempt, and
stating it in the plist skips the question on every single upload.

**3. Marketing version — NOT yet fixed, and it will reject the upload.**
`CFBundleShortVersionString` comes from `$(FLUTTER_BUILD_NAME)`, which Flutter
takes from the pubspec version: today `1.0.0-beta.7`. **Apple requires a numeric
marketing version** — one to three dot-separated integers. `1.0.0-beta.7` is
refused by App Store Connect.

The prerelease suffix is only meaningful to us, so **`tool/ios_build.sh`**
strips it and lets the build number carry the beta identity:

```sh
tool/ios_build.sh            # builds the IPA
tool/ios_build.sh --dry-run  # prints the version it would use (works on Linux)
```

It derives the marketing version from `pubspec.yaml` (`1.0.0-beta.7` → `1.0.0`)
and the build number the same way Android does — the git commit count, floored
by the `+N` in the pubspec. TestFlight only requires the **build number** to
increase within a marketing version, which the commit count does by
construction.

**4. Signing team is unset** (`DEVELOPMENT_TEAM` absent, `CODE_SIGN_STYLE =
Automatic`). Set it once in Xcode → Runner → Signing & Capabilities → Team, and
commit the resulting pbxproj change.

**5. Deployment target — raised to iOS 15.0** (2026-08-19), matching Flutter
3.47's own template, in `project.pbxproj` (three configurations) and
`ios/Flutter/AppFrameworkInfo.plist`. It was 12.0, which modern pods refuse.
The floor costs only iPhone 5s/6/6 Plus, which never went past iOS 12; iOS 15
still reaches iPhone 6s and later.

Already fine: the 1024×1024 marketing icon is **RGB with no alpha channel**
(Apple rejects alpha), location usage strings are present, and every plugin in
use supports iOS.

---

## Why the non-obvious Info.plist keys are there

**Xcode strips XML comments from `Info.plist`** every time it rewrites the file
— it did exactly that during the SPM migration on 2026-08-19 — so the reasoning
cannot live next to the keys. It lives here instead.

| key | why |
|---|---|
| `ITSAppUsesNonExemptEncryption` = `false` | The app uses only HTTPS through the OS, which is exempt. Declaring it skips the export-compliance question on every TestFlight upload. |
| `NSAppTransportSecurity` → `NSExceptionDomains` → `calapi.inadiutorium.cz` | That liturgy API refuses HTTPS on IPv4 (port 443 refused, port 80 returns 200), so without a scoped cleartext exception the liturgy tile silently loses its enrichment and falls back to the offline Computus baseline. Mirrors `android/app/src/main/res/xml/network_security_config.xml`. Every other domain keeps the secure default. |
| `NSLocationWhenInUseUsageDescription` and `…AlwaysAndWhenInUse` | Required strings; without them geolocator/permission_handler crash on launch. |

If any of these vanish after an Xcode migration, that is a regression — check
this table against the file.

## Testing location on the Simulator

The Simulator only runs **debug** builds, and debug builds normally pin the
location to Lakewood via `kDevLocation`. To use Xcode's simulated locations
instead:

```sh
flutter run --dart-define=REAL_GPS=1
```

Then Features → Location → Custom Location. `41.4489, -82.7079` is Sandusky and
must raise the out-of-diocese notice; `41.1595, -81.4404` is Stow and must not.

## Making it a beta app with Apple

TestFlight is the whole answer — there is no separate "beta app" product. The
path, in order:

**1. Register the App ID.** developer.apple.com → Certificates, Identifiers &
Profiles → Identifiers → **+** → App IDs → App → explicit ID `app.parishfinder`.
No special capabilities are needed; the app uses location, which is a plist
permission, not an entitlement.

**2. Create the app record.** App Store Connect → Apps → **+** → New App:
platform iOS, the name (check availability — "ParishFinder" may be taken as a
*store* name even though the bundle ID is free), primary language, the bundle ID
from step 1, and an SKU (any internal string; `parishfinder` is fine).

**3. Sign in Xcode.** Xcode → Settings → Accounts → add the Apple ID, then
Runner → Signing & Capabilities → Team. Leave automatic signing on; it will
create the development and distribution certificates and provisioning profiles
for you.

**4. Build and upload.**
```sh
git pull --rebase
tool/ios_build.sh
```
Use the script, not a bare `flutter build ipa` — it derives the numeric
marketing version and the git build number for you, and refuses to bless a
debug build (a debug IPA still carries the Lakewood location mock, see
`kDevLocation`). `tool/ios_build.sh --dry-run` prints what it would use without
building, and works on Linux.

Then upload `build/ios/ipa/*.ipa` with **Transporter.app** (simplest), or open
the archive in Xcode → Organizer → Distribute App → App Store Connect.

**5. Wait for processing** — usually 5–30 minutes. The build then appears under
the app's **TestFlight** tab.

**6. Internal testing — this is where you start.** Add yourself under Users and
Access, then TestFlight → Internal Testing → a group → add testers → enable the
build. Up to 100 internal testers, **no review**, available as soon as
processing finishes. Testers install the TestFlight app and get the build within
minutes. For putting it on your own phone and iterating, stop here.

**7. External testing — only when you want parishioners on it.** Up to 10,000
testers by email or a public link, but the first build needs **Beta App Review**
(typically a day or two) and requires test information: what to test, a contact
email, and a privacy policy URL — parishfinder.app/privacy is already live.

**Worth knowing:** every TestFlight build **expires 90 days** after upload, so a
beta group needs a fresh build roughly quarterly. And App Store Connect's App
Privacy questionnaire is a separate thing from Play's Data Safety form, but the
answers are the same — see [`play-data-safety.md`](play-data-safety.md);
feedback is the only thing collected, and location never leaves the device.
