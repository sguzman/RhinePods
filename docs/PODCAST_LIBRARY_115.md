# Investigation: subscribed podcast missing from RhinePods library

## Observed on 2026-11-15 (eosbox)

- User clicked Subscribe from Podcast Index for Bloomberg Businessweek/The Tape.
  Index URLs under `feeds.bloomberg.fm` did not resolve; server returned a
  useful DNS failure in JSON, but frontend toast displayed only "Bad Request".
- A custom Omny RSS subscription request returned success with
  `podcastid: 115` ("Bloomberg Businessweek").
- An authenticated CLI GET of `/api/data/return_pods/3` returned that podcast.
  An authenticated read from Firefox also returned HTTP 200, 110 podcasts,
  and the name associated with ID 115.
- The library's search UI did not show the exact show, but did show a
  different show, "Bloomberg Businessweek Daily".
- No evidence of backend database loss. Do not add it again, delete it,
  migrate the DB, or change DNS based on this separate UI symptom.

## Source inspection

The **exact upstream PinePods 0.9.2** `web/src/pages/podcasts.rs` and the
matching file in RhinePods were verified to have identical Git blob SHA
`9a6d2bb2cac93434e20368d39d75616d10a6451c`.

- The library renders the entire `PodcastFeedState.podcast_feed_return_extra`
  array; there is no per-page count limit.
- The title search is case-insensitive substring matching.
- `call_get_podcasts_extra` stores `GET /api/data/return_pods/{id}`
  responses in an in-memory 120-second cache.
- The Podcasts page's custom feed success handler inserts a returned
  `PodcastExtra` into the shared state immediately; **this is different
  from** the separate settings-page custom feed handler, which only toasts.
- After navigation, Podcasts/Feed/Queue can load an older cached response
  and replace that shared state. The successful custom-feed request itself
  did not previously invalidate that cached GET response.
- The service worker caches image URLs only, not the subscriptions API.

## Reproduction and narrow fix

Browser test `web/src/tests/pages.rs`:
1. Mock 110 server podcasts including ID 115; actual Yew Podcasts page
   renders and searches it correctly (green baseline test).
2. Mount library with an old cached list, mock a successful
   `POST /api/data/add_custom_podcast` for 115, and update the mock server
   GET list. The page immediately shows the new podcast.
3. Unmount/remount the page WITHOUT clearing in-memory request cache,
   simulating navigation. The original code re-reads the old cached list
   and removes ID 115 from the screen (confirmed red browser regression).
4. The fix in `web/src/requests/setting_reqs.rs` invalidates cached
   `/api/data/return_pods` GET responses **only after** a successful,
   correctly parsed custom-feed POST. This affects neither playback nor
   database mutations. The ordinary subscription state insert remains.

The compatibility patch `compat/podcast-library-0.9.2.patch` applies
the same fix to the exact upstream release tag, after the independent
`compat/metadata-0.9.2.patch` on the current deployed frontend lineage.

**Important limitation:** a controlled navigation/cache regression is not
proof that precisely the same sequence caused every aspect of the live UI
discrepancy (including the reported behavior after reload). Do not claim
that user's specific missing show is fixed until a deployed frontend build
is tested against ID 115 and real user navigation.

## Deployment status

This branch is investigation-only. Neither the Docker server nor the
frontend running on eosbox has been changed. Browser tests and exact-0.9.2
frontend build are GitHub Actions only. Do not merge or deploy merely
because the patch compiles; wait for green tests and real acceptance QA.
