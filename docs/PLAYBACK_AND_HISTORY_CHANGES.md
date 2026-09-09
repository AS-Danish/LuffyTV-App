# Playback, downloads, and history — 9 September 2026

## Implemented

- Details use stored progress and published episode numbers. Unfinished episodes resume; completed episodes advance to the next available episode. Finales replay instead of requesting a nonexistent episode. The button reacts to history changes.
- Details warm only the selected episode's source metadata, using the repository's existing short-lived cache and in-flight deduplication. Playback warms the next episode within the last 45 seconds. Video segments for other episodes are not downloaded speculatively.
- The player offers **Play next episode** after completion. Local playback looks for the next completed download. Completed episodes restart at zero.
- Streaming opens directly at the saved position, uses a bounded 64 MiB forward buffer and 8 MiB backward buffer, and defaults to a balanced HLS bitrate. A sustained 12-second buffering stall triggers at most two recovery attempts per episode, preserving position and audio language/type while lowering HLS bitrate. The highest-quality preference remains available.
- Downloads run through a serial queue to avoid competing transfers. They reconnect after transient HTTP/network errors and can refresh the source once while retaining selected audio and quality. Cancellation invalidates the job so late progress/completion cannot restore it.
- If the initial duration probe is unavailable, finite HLS VOD playlists can establish expected duration. Final video duration and file size are still validated; incomplete files never become completed downloads. Artificial progress has been removed.
- Profile → Watch history supports clearing all history and removing a single anime or episode through its menu. Search supports clearing the current query, individual recent searches, and all recent searches.
- Navigation uses a flat dark bar, readable labels, and subtle selection motion. Surfaces, corners, typography, and accent treatment are quieter. Press and navigation animations respect reduced-motion settings.

## API companion change

`C:\anikoto-API-Teramoto\src\lib\providers\waterfall.ts` hedges the canonical Anikoto request with Shineii after 1.2 seconds, or immediately after primary failure. A fast primary avoids starting the fallback. Only successfully normalized and media-probed responses can win. Other catalogue fallbacks run only after both canonical providers fail, within the existing overall deadline. Existing cache and request coalescing remain in use.

Already-started losing requests retain their provider/network timeouts; they are not cancelled end-to-end. No later provider is launched after a winner. This change needs deployment to affect production; the app remains configured for its existing production API.

## Verification and limits

- 13 Flutter unit/storage tests passed for resume, episode gaps/finales, history deletion, HLS duration, offline progress, download integrity, and metadata.
- A separate 360px widget test passed for reactive resume labels, layout errors, and targeted preloading.
- Scoped Flutter analysis passed with no issues; Android sideload debug APK compilation passed.
- API TypeScript check and 21 tests passed for hedging, media validation, watch routes, cache behavior, and source recovery.
- No Android device or emulator was connected. Real-device playback, background lifecycle behavior, long downloads, and before/after CDN throughput still require device testing. No production deployment or app installation was performed. External provider outages and insufficient bandwidth can still cause buffering.

Native cache and HLS bitrate settings follow the [mpv reference manual](https://mpv.io/manual/stable/).
