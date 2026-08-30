# Google Play release runbook

How to sign, build, and ship ParishFinder to the Play Store.

Companion documents:
- [`play-data-safety.md`](play-data-safety.md) — answers for the Data Safety form
- [`play-listing.md`](play-listing.md) — store listing copy and asset specs
- [`../PRIVACY.md`](../PRIVACY.md) — the privacy policy that must be hosted publicly

---

## One-time setup

### 1. Create the upload keystore

This key signs every upload for the life of the app. **If you lose it you cannot
update the app** (Play App Signing lets you request an upload-key reset, but
that is a support round-trip — don't rely on it).

`keytool` ships with the JDK. It is not on this machine's `PATH`; Android
Studio's bundled JDK or any installed JDK provides it.

```bash
keytool -genkeypair -v \
  -keystore ~/parishfinder-upload.jks \
  -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Answer the prompts and choose a strong password. Store the keystore **and** its
password somewhere durable and backed up — a password manager, not just this
machine's disk.

### 2. Point the build at it

Create `android/key.properties` (already gitignored — never commit it):

```properties
storeFile=/home/michael/keys/parishfinder-upload.jks
storePassword=<your store password>
keyAlias=mykey
keyPassword=<your key password>
```

`android/app/build.gradle` reads this file. If it is missing, **release builds
fail loudly** rather than falling back to debug signing — a debug-signed AAB is
rejected by Play, and a debug key that reached production could never be
rotated.

### Sideload test builds vs. the real upload key

There is a throwaway keystore at `~/parishfinder-TEST-ONLY.jks` (alias
`testonly`, password `parishfindertest`) used to sign APKs for device testing.
It is **not** an upload key and must never sign anything that reaches Play — the
first key you upload with becomes your enrolled upload key.

`android/key.properties` is deliberately left absent between builds so a release
build fails loudly rather than quietly signing with the test key. To produce a
sideload APK:

```bash
cat > android/key.properties <<'EOF'
storeFile=/home/michael/parishfinder-TEST-ONLY.jks
storePassword=parishfindertest
keyAlias=testonly
keyPassword=parishfindertest
EOF

flutter build apk --release --split-per-abi
rm android/key.properties        # put the guard back
```

Because the test key differs from the Play signing key, a device holding a
sideloaded build must **uninstall it** before installing from Play — Android
refuses an update whose signature changed.

### 3. Enrol in Play App Signing

Keep Play App Signing enabled (it is the default for new apps). Google holds the
real app signing key; your upload key only authenticates uploads to them.

---

## Cutting a release

```bash
# 1. Choose the version. Never hand-edit the version line in pubspec.yaml.
tool/release.sh show          # what is the current version?
tool/release.sh beta          # or: release / patch / minor / major

# 2. Verify.
flutter analyze
flutter test

# 3. Build the App Bundle. Play requires .aab, not .apk.
flutter build appbundle --release
```

The artifact lands at `build/app/outputs/bundle/release/app-release.aab`.

The **versionCode** is derived from `git rev-list --count HEAD`, floored at the
`+N` in `pubspec.yaml`. Play permanently rejects any upload at or below a
versionCode it has already seen, so this only ever moves up. Release builds
hard-fail if git is unavailable (e.g. a shallow CI checkout) rather than
silently emitting a lower number.

### About the artifact size

The AAB is ~44 MB, but that is not the download size. Roughly 47 MB of that is
native debug symbols and the ProGuard mapping in `BUNDLE-METADATA/`, which Play
strips and never delivers. A device downloads one architecture — about 12 MB.

Upload the debug symbols anyway: they are what turn native crash reports in the
Play Console into readable stack traces.

---

## First submission checklist

Work top to bottom. The items above the line block the upload itself.

- [x] **Launcher icons and both store graphics are generated and shipped** —
      `tool/gen_icons.py` renders them from the design handoff's vector source.
      The 512×512 Play icon and the 1024×500 feature graphic are at
      `docs/store/`. Never hand-edit the PNGs; `gen_icons.py --check` catches drift.
- [ ] **Phone screenshots — 2 to 8 images, still missing.** The one remaining
      listing asset. See the screenshot plan in [`play-listing.md`](play-listing.md).
- [ ] Upload keystore generated and backed up (steps 1–2 above). `keytool` is not
      on `PATH`; it lives at `/usr/lib/Stirling-PDF/runtime/jre/bin/keytool`.
- [ ] `applicationId` is `app.parishfinder`. **This is permanent after the first
      upload** — change it now or never.
- [x] Privacy policy hosted — `https://parishfinder.app/privacy.html` is live
      (Git-deployed via Cloudflare Pages). Use the `.html` URL in the Play
      Console: bare `/privacy` only works on hosts that strip extensions.
- [ ] Data Safety form completed — see [`play-data-safety.md`](play-data-safety.md).
- [ ] Store listing copy and graphics — see [`play-listing.md`](play-listing.md).
- [ ] Content rating questionnaire completed (expect "Everyone").
- [ ] Target audience set. Declaring an audience that includes children triggers
      the Families policy and extra review — this app targets a general/adult
      audience.
- [ ] Ads declaration: **no ads**.
- [ ] Test on a physical device against `targetSdk 36` (Android 16). Edge-to-edge
      is mandatory at this API level — check that content is not hidden behind
      the status bar, the navigation bar, or a display cutout.
- [ ] Verify location permission flows: grant, deny, and "only this time".
      Denying must leave the rest of the app fully usable.
- [ ] Verify first launch with **no network** shows "Internet connection
      required to download parish data" rather than an empty or broken state,
      and that a subsequent launch with a warm cache shows the "Offline mode -
      data may be out of date" banner.
- [ ] Confirm the feedback form reaches the Worker from a release build.
- [ ] Internal testing track first, then closed, then production.

### Known gaps to decide on before shipping

- **`flutter_map` is a major version behind** (7.0.2 vs 8.x). Deferred
  deliberately: v8 is a breaking API change and the map works today. Revisit
  after launch, not before.

### Fonts are bundled, not fetched

Inter and Cormorant Garamond live in `assets/google_fonts/` and
`GoogleFonts.config.allowRuntimeFetching` is `false`, so the app never contacts
`fonts.gstatic.com`. This keeps the user's IP away from Google and means a first
launch with no network still renders in the real typefaces.

google_fonts locates these purely by filename — it looks for an asset ending in
`<Family>-<Variant>`, where the family has no spaces (`CormorantGaramond`) and
the variant follows its own weight map (w600 → `SemiBold`, w700 → `Bold`). **A
misnamed file fails silently**, falling back to the system font rather than
throwing. `test/bundled_fonts_test.dart` guards the exact names; run it if you
add a weight or change a typeface.

---

## Post-launch

- The versionCode advances automatically with commits; just re-run the release
  steps for each update.
- Watch the feedback Worker's daily Discord digest and the `/admin` dashboard for
  incoming data corrections.
- Play's target-API requirement moves annually — expect to need API 37 around
  August 2027.
