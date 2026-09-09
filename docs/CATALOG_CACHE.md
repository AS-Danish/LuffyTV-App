# Catalog caching in 1.0.9 (build 9)

Home data, anime details and episode lists persist in the Hive box
`catalog_cache_v1`. Cache keys include the API origin, path and query. Home
data is fresh for five minutes, details for thirty, and episode lists for ten.
Fresh data needs no HTTP request after restarting the application. Older data
up to seven days old displays immediately while one coalesced network request
refreshes it. A changed result invalidates catalog providers so visible views
update. Failed background requests preserve saved data. Malformed entries and
data older than seven days are misses.

The box is limited to 80 entries and approximately 8 MB of string data, with
a per-entry limit. Storage failure falls back to normal network loading.
The existing connection-check screen no longer delays a saved home screen;
the offline-download and mandatory-update gates remain in place once their
checks complete. Pull-to-refresh explicitly reloads home data from the API.

Watch URLs, signed media links, search results, and account data are excluded
from this persistent catalog cache. Playback keeps its existing 45-second
memory cache and explicit recovery, avoiding reuse of expired signatures.

Validation: 38 Flutter tests pass, including disk close/reopen with a new
repository and no second HTTP request, stale background refresh, request
coalescing, offline fallback, explicit home refresh, and playback cache
exclusion. Static analysis passes for changed app files. No physical-device
startup timing measurement was performed.
