# Luffy TV Android version management

## Release a build

1. Change `version:` in `pubspec.yaml`. Use `MAJOR.MINOR.PATCH+BUILD`, for example `1.1.0+2`. Increase the build number for every uploaded APK.
2. Build and test the release APK: `flutter build apk --release`.
3. Upload the APK and set the website's `NEXT_PUBLIC_ANDROID_APK_URL` to its HTTPS URL.
4. Configure the API deployment:

   - `ANDROID_LATEST_VERSION=1.1.0`
   - `ANDROID_MINIMUM_VERSION=1.0.0` for an optional update
   - `ANDROID_UPDATE_URL=https://your-official-site.example/app`
   - `ANDROID_UPDATE_MESSAGE=Your release message`

5. Deploy the website and API, then verify `/api/app-version` before raising the minimum.

## Make an update compulsory

Set `ANDROID_MINIMUM_VERSION` to the oldest version that may still stream. For example, setting it to `1.1.0` locks streaming in every installed build below `1.1.0`.

The app caches the last valid policy, so going offline does not bypass a compulsory update. A locked build exposes only **Update now** and, when completed downloads exist, **Watch my downloads**. Downloads that are incomplete or missing their local file are not shown as playable exceptions.

## Safe rollout order

Keep the minimum at the previous release while the new APK propagates. Confirm that the new download works and reports the expected version. Only then raise the minimum. If a release has a serious problem, lower `ANDROID_MINIMUM_VERSION` in the API environment and redeploy the API.
