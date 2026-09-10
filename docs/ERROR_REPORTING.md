# LuffyTV error reporting

Firebase project: `luffy-tv-90bd6`
Android app: `com.luffytv.luffytv`
Firebase app ID: `1:59600381999:android:55ecc4d2dbf94526a6beda`

## What is captured

- Uncaught Dart errors, Flutter framework errors and startup failures.
- Native Android crashes/ANRs, including Crashlytics NDK capture for the player
  and FFmpeg. Third-party native symbols are still needed for full function names.
- Handled API requests, source resolution/opening, native player error callbacks,
  failed downloads and subtitle transfers. User-cancelled jobs are excluded.
- Safe request IDs, source hosts/server names, status codes and playback context.
  Device/OS/app version context comes from the Crashlytics SDK.
- Error categories: authorization, signed URL, decryption, network, application.
  These classify errors the app receives; server-only failures still require
  backend logs, correlated using the request ID. No backend SDK was installed.

App-supplied reports redact full URLs, authorization values, tokens, encryption
keys, nonces, signatures, cookies and opaque values. Unknown context fields and
request/response bodies are not exported. Do not log raw credentials elsewhere:
native SDK crash data does not pass through the Dart sanitizer.

The queue holds up to 32 sanitized reports, deduplicates the same event/message
for five minutes and isolates SDK failures. Overload can drop reports. SDK calls
are asynchronous and never awaited by playback or downloads. Native Crashlytics
also applies its own retention/rate limits; this is not a lossless log archive.

## Performance

Firebase Performance custom traces:

- `player_first_frame`: first native frame on a newly created controller.
- `player_first_progress`: media-open to progress for each source attempt.
- `player_rebuffer`: buffering after initial startup.
- `api_response_received`: source API response latency.

Read the **duration_ms custom metric**, not the trace's default duration. Timing
is measured locally and exported asynchronously after completion. The additional
`over_two_seconds` metric is 0 or 1. Measurements before Firebase initializes can
be skipped. Automatic HTTP instrumentation is intentionally disabled to avoid
collecting signed media URLs. No session recording or Google Analytics SDK added.

## Alerts

Configured in the Firebase Console for the signed-in owner's account:

- New fatal issues: email enabled.
- New non-fatal issues: email enabled.
- New ANR issues: email enabled.
- Trending issues: existing email enabled.
- Regressions: existing email and console enabled.
- Velocity alerts: existing email and console enabled (25 users and 1%).

These notify about new/regressed/trending issues, not each repeated event.
Firebase documents non-fatal reports being sent with a fatal report or on restart.
No delivery-time guarantee is possible, especially while devices are offline.
Performance threshold alerts need configuring after traces first arrive.

Console: https://console.firebase.google.com/project/luffy-tv-90bd6/crashlytics
Alerts: https://console.firebase.google.com/project/luffy-tv-90bd6/settings/alerts

## Device verification (pending: no device connected during implementation)

Normal release builds enable reporting. Debug/profile builds keep it off unless
explicitly enabled. To send a deliberate non-fatal smoke report from a test device:

```powershell
flutter run --flavor sideload --dart-define=ERROR_REPORTING=true --dart-define=TELEMETRY_SMOKE_TEST=true
```

After launch, allow initialization to finish, close and reopen the app to trigger
non-fatal upload. Look for `telemetry.smoke_test` in Crashlytics and confirm email
delivery for the new issue. Remove the smoke flag before distributing a build.
This deliberate test does not crash the app. Then test playback/download errors,
an expired URL, and a working encrypted source. Check reports contain no secrets.

The SDK/device path and actual email receipt remain unverified until this test.
Changing Dart `ERROR_REPORTING=false` disables collection after initialization;
release native startup collection is also controlled by the Android manifest
placeholder, so disable that too if producing an entirely telemetry-free release.

## Symbols and platforms

The Crashlytics Gradle plugin handles Java/Kotlin mapping integration. Current
release builds do not obfuscate/split Dart symbols. If enabling `--obfuscate` or
`--split-debug-info`, retain that release's symbol files and upload with:

```powershell
firebase crashlytics:symbols:upload --app=1:59600381999:android:55ecc4d2dbf94526a6beda PATH_TO_SYMBOLS
```

For full native FFmpeg/libmpv symbolication, obtain matching unstripped libraries
or symbols from those builds and use the same Firebase symbols upload tooling.
Never upload keystores, auth tokens, or media decryption keys as symbol assets.

This configuration targets Android. Other platforms are guarded off and need
their own Firebase app registration/configuration before telemetry is enabled.

References:
- https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports
- https://firebase.google.com/docs/crashlytics/android/get-started-ndk
- https://firebase.google.com/docs/crashlytics/alerts
