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

## Verified remote results and optional r5 image candidate

The original browser regression **failed** with ID 115 missing after
navigate-away/return (run `43730615955`). The same real Yew browser test
**passed** after invalidating the successful-add cache (run `43730806101`).
The independent 110-podcast search regression also passed.

The exact upstream 0.9.2 patch chain **compiled successfully**:
<https://github.com/sguzman/RhinePods/actions/runs/43730927772>

- Compatibility artifact: `rhinepods-web-pinepods-092-library-test`
- Tar member: `rhinepods-web-pinepods-0.9.2-library.tar.gz`
- Tar SHA-256: `21ad07ddb954af1501bff58b9acc4bb484294831510ad4091726703a65395346`
- Compressed tar: 5,966,739 bytes (about 5.7 MiB)
- Artifact ZIP: approximately 5.9 MiB, expires 2026-11-22
- **Optional local image tag:** `local/rhinepods:pinepods-0.9.2-library-43730927772-r5`

`scripts/build-092-prebuilt.fish` on **this feature branch** now pins that
artifact, verifies its SHA-256, builds offline from the already-cached official
0.9.2 Docker image, and smoke-tests Nginx in a disposable no-network
container. It does **not** replace the running PinePods service.

`scripts/overlay-092-prebuilt.yaml` is an **opt-in image-only** Docker
Compose overlay pointing at r5. Do not invoke Compose until the user explicitly
approves deployment. The original r3 container, server API, PostgreSQL, Valkey,
volumes, player controls, and original base image are not modified by GitHub
development or image preparation.

### Real acceptance still required

Only after a separately approved frontend cutover:
- Verify real Firefox session load without stale mixed JS/WASM assets.
- Open Podcasts and search for exact **Bloomberg Businessweek** (ID 115).
- Navigate to another app section and back; confirm it remains visible.
- Verify episode import state separately (a successful add doesn't necessarily
  mean that every historical episode was imported).
- Verify Waybar, playback, and currently subscribed podcasts are unaffected.
- Roll back to the prior Compose image if regression occurs.

The test demonstrates and fixes a **reproducible** frontend cache-loss path;
it does not prove every missing-item symptom on the user's machine had this
single cause. No live deployment has been performed.

## Follow-up after r5 live deployment — 2026-11-15

- The owner confirmed `local/rhinepods:pinepods-0.9.2-library-43730927772-r5` is now running and HTTP health returned 200.
- Despite r5, the visible library search still omitted Bloomberg Businessweek ID 115.
- A read-only authenticated GET of `/api/data/return_pods/3` returned 110 podcasts, including ID 115 (`Bloomberg Businessweek`, 5,587 episodes, no favorite, empty categories). No database repair or resubscription is justified.
- The earlier screenshot reportedly showed `Bloomberg Businessweek Daily`, which is absent from the four `business`-matching titles in that server response. Verify that the screenshot/search is on **Podcasts**, not **Discover**, and that it uses the same account and current JS/WASM.
- The library's selected category chips legitimately exclude an uncategorized show, so `Clear All` is a non-destructive first UI check. Do not automatically assign a category to ID 115 without user intent.

### Additional regression and candidate source change

- The original r5 invalidation runs only after a successful **in-tab custom-feed POST**; a subscription added by another device, server sync, or another route can still be missed for the request cache's 120-second TTL.
- The new browser regression mounts the real Podcasts page with an old list, simulates an out-of-tab server-side subscription, and remounts without clearing the request cache. The library page now explicitly invalidates its own cached subscriptions GET before loading so the fresh server list can reach the UI. The exact 0.9.2 compatibility patch includes the same isolated change.
- This is a **candidate additional safeguard, not proof of the user's live UI root cause**. GitHub Actions and real QA must pass before any image changes. The deployed r5 remains untouched by repository commits.

### Distinguishing subscription title from publisher artwork

A follow-up screenshot with `business` entered in **Podcasts** shows four cards with episode counts **1085, 104, 826 and 5587**, matching the four records from the read-only API. The **5587** entry matches podcast **115**, whose API title is `Bloomberg Businessweek`. Its image itself says `Bloomberg Businessweek Daily`; those words are printed on the cover artwork and are *not* evidence of a second subscription. This corrects the earlier diagnosis that the Daily card was necessarily a separate show.

Source inspection confirms `web/src/pages/podcasts.rs` renders the true `podcast.podcastname` into `.podcast-title-grid`, but `web/static/styles.css` hides its `.podcast-info` container with `opacity: 0` unless the card is hovered. Therefore, the UI can falsely look like the actual subscribed title is absent. This is a distinct display/usability issue, not database loss.

New candidate CSS change: keep `.podcast-info` visible by default, so the API name appears consistently with the artwork. Keep the rightmost 5,587-episode entry and its data unchanged. This requires a new frontend artifact and separately authorized deployment; running r5 is untouched. Until then, **hover the card** or switch to **List** to see the canonical name. No further resubscription or mutation is justified.

