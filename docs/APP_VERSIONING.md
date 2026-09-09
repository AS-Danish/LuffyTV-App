# Luffy TV compulsory APK updates

Luffy TV has no optional-update mode. If the manifest `versionCode` is greater than the installed build number, streaming is locked until the new APK is installed. The user must still manually tap **Download compulsory update**, grant Android's per-app installation permission, and confirm the system installer. Android does not permit silent sideloaded updates.

Completed anime downloads remain playable from the update screen. The normal catalog, search, details, and streaming UI remain unavailable.

## Distribution flavors

- `sideload`: includes `REQUEST_INSTALL_PACKAGES` and the APK updater.
- `play`: omits that permission and reports self-updating as unsupported. A future Play updater can replace the installer implementation without changing the UI state model.

Use the sideload flavor for private APK releases:

```powershell
flutter run --flavor sideload
.\tool\build_arm64_release.ps1
```

Production sideload APKs support `arm64-v8a` only. This covers modern 64-bit
Android phones while excluding ARMv7/32-bit phones and x86 Android emulators.
Normal debug builds are unchanged unless the ARM64 release script is used.

Debug builds do not contact the updater unless explicitly enabled:

```powershell
flutter run --flavor sideload --dart-define=ENABLE_SELF_UPDATER=true
```

An `.aab` or split APK set cannot be installed by this single-APK updater.
Publish the single signed ARM64 APK produced by `build_arm64_release.ps1`.

## Manifest JSON

`GET /api/app-version` returns:

```json
{
  "ok": true,
  "data": {
    "version": "1.4.0",
    "versionCode": 14,
    "minimumSupportedVersionCode": 14,
    "apkUrl": "https://releases.example.com/luffy-tv-1.4.0.apk",
    "sha256": "64_lowercase_hex_characters",
    "apkSize": 68432192,
    "mandatory": true,
    "title": "Luffy TV needs an update",
    "message": "Install the latest release to continue streaming.",
    "changelog": [
      "Improved video player",
      "Fixed episode downloads"
    ],
    "publishedAt": "2026-08-25T00:00:00Z"
  }
}
```

The client rejects optional manifests, insecure APK URLs, invalid hashes, impossible version codes, and malformed JSON. Build number/versionCode—not the semantic version string—is authoritative.

## Publish a compulsory update

1. Increase `version:` in `pubspec.yaml`. Every production APK needs a strictly increasing build number:

   ```yaml
   version: 1.4.0+14
   ```

2. Build with the same permanent release keystore used for every prior production version:

   ```powershell
   flutter test
   .\tool\build_arm64_release.ps1
   ```

3. Upload the versioned ARM64 APK printed by the build script, such as `build\app\outputs\flutter-apk\luffytv-1.4.0-build14-arm64.apk`, to the final HTTPS release URL. Upload the APK **before** changing the manifest. Do not use `app-release.apk` or an APK built without the ARM64 release script.

4. Verify the public URL downloads the APK, not an HTML error page.

5. Generate the exact environment values:

   ```powershell
   .\tool\prepare_update_release.ps1 `
     -ApkPath .\build\app\outputs\flutter-apk\luffytv-1.4.0-build14-arm64.apk `
     -Version 1.4.0 `
     -VersionCode 14 `
     -HttpsUrl https://releases.example.com/luffy-tv-1.4.0.apk
   ```

Then configure and deploy the API manually:

   ```text
   ANDROID_VERSION=1.4.0
   ANDROID_VERSION_CODE=14
   ANDROID_APK_URL=https://releases.example.com/luffy-tv-1.4.0.apk
   ANDROID_APK_SHA256=<output from prepare_update_release.ps1>
   ANDROID_APK_SIZE=<output from prepare_update_release.ps1>
   ANDROID_UPDATE_TITLE=Luffy TV needs an update
   ANDROID_UPDATE_MESSAGE=Install the latest release to continue streaming.
   ANDROID_CHANGELOG=Improved video player|Fixed episode downloads
   ANDROID_PUBLISHED_AT=2026-08-25T00:00:00Z
   ```

Verify `/api/app-version` and download/hash the public APK independently before telling users to relaunch the app.

The release-preparation script rejects APKs containing ARMv7 or x86 native
libraries, which prevents accidentally republishing a large universal APK.

Publishing the manifest is the manual control that activates the compulsory update. There is no optional flag to accidentally configure.

## Security and recovery

- Manifest and APK must use HTTPS in release builds.
- The APK is downloaded into private `cache/update` storage as `.apk.part`.
- HTTP Range is used only when the server confirms `206 Partial Content` for the exact saved release metadata.
- Size and streamed SHA-256 are verified before the file becomes `.apk`.
- Android parses the APK and verifies package name, exact versionCode, and signing identity against the installed app.
- Native installation accepts paths only from Luffy TV's private update directory.
- `PackageInstaller.Session` reports pending user action, cancellation, storage, conflict, blocked, incompatible, invalid, generic failure, and success states.
- A completed or partial download is recovered after process death and reverified before use.
- Obsolete and stale update files are cleaned automatically.
- A cached compulsory manifest keeps an already-known unsupported build locked during an API outage. If no valid policy has ever been received, an endpoint failure does not lock the app.

SHA-256 detects corruption and mismatch with the manifest. It does not protect against simultaneous compromise of both the API manifest and release storage. Android signing-key validation is the final identity boundary. Never lose or regenerate the production keystore.

## Test an update from build 13 to 14

1. Install a release-signed `1.3.x+13` sideload APK on a physical Android device.
2. Build `1.4.0+14` using the identical signing keystore.
3. Upload build 14 and verify its HTTPS URL.
4. Calculate its hash/size and publish the build-14 manifest.
5. Launch build 13. It should show the non-dismissible update screen.
6. Tap Download and verify progress, byte counts, speed, and verification state.
7. On Android 8+, grant **Allow from this source** when requested.
8. Confirm Android's installer. Cancelling must return to **Install update**, not report success.
9. After successful replacement, launch Luffy TV and confirm Profile shows build 14 and the gate is gone.

Also test airplane mode, API/APK 404, HTML at the APK URL, interrupted/resumed download, bad size/hash, wrong package, wrong signing key, insufficient storage, repeated button taps, process death, installer cancellation, and at least one Pixel/Samsung/Xiaomi-class device. OEMs can alter installer presentation, but cannot be bypassed safely; failures must be retried through the standard Android flow.

## Rollback

Android does not allow a normal update downgrade. If build 14 is broken, publish a corrected APK with build 15. Never replace an APK while reusing its versionCode.
