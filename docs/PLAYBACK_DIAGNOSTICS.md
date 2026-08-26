# Playback diagnostics

Diagnostics are structured around a `requestId` and redact signed URLs, query
strings, cookies, authorization values, and proxy signatures.

## Enable the API logs

In the `anikoto-API-Teramoto` Vercel project, set:

```text
PLAYBACK_DIAGNOSTICS=true
PLAYBACK_DIAGNOSTICS_PROXY_SEGMENTS=false
```

Redeploy, reproduce once, then open Vercel Logs and filter for
`PlaybackDiag`. Leave segment logging disabled initially; enabling it can
produce one log entry for every HLS segment.

## Enable the website logs

In the `luffy-tv-website` Vercel project, set:

```text
PLAYBACK_DIAGNOSTICS=true
NEXT_PUBLIC_PLAYBACK_DIAGNOSTICS=true
```

Redeploy. Open browser developer tools, filter the Console for
`PlaybackDiag`, and also collect the website project's Vercel logs with the
same filter.

## Enable and collect Flutter logs

Debug builds enable playback diagnostics automatically. For an explicit
diagnostic build:

```powershell
flutter run --flavor sideload --dart-define=PLAYBACK_DIAGNOSTICS=true
```

Or build an installable diagnostic APK:

```powershell
flutter build apk --release --flavor sideload --dart-define=PLAYBACK_DIAGNOSTICS=true
```

With Android platform tools on `PATH`, clear old logs immediately before the
test:

```powershell
adb logcat -c
adb logcat -v time | Select-String "PlaybackDiag|LuffyTV.Playback|media_kit|ExoPlayer"
```

Open the affected episode, wait for the failure, press Retry once, then stop
the command with Ctrl+C and save the output.

## What to send

Send the Flutter `PlaybackDiag` entries plus the API and website entries that
share the same `requestId`. Do not send `.env` files, signing keys, complete
proxy URLs, cookies, authorization headers, or Vercel secrets.

After diagnosis, set all diagnostic environment variables back to `false` and
publish the normal release APK without the diagnostics Dart define.
