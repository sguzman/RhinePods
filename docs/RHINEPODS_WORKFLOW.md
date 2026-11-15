# RhinePods development, branching and upstream workflow

## November 15, 2026 — Library investigation closeout and feature readiness

- Bloomberg Businessweek ID 115 was subscribed and present in the live API
  (5,587 episodes). Omny artwork says "Bloomberg Businessweek Daily" while
  the canonical subscription name is "Bloomberg Businessweek".
  Grid CSS hid the canonical title until hover; the subscription was not lost.
- A separate controlled Yew browser regression reproduced stale 120-second
  podcast-list caching after a successful custom subscription. Fixing the
  stale cache is useful but **not proven** to have caused the original complaint.
- Library fixes are integrated separately from r4 MPRIS artist/artwork
  follow-ups and local r5 Docker overlay packaging. No server, database or
  container change follows from source integration.
- The original MPRIS title/podcast-name milestone was accepted live on
  November 14. Missing artwork for some episodes remains unresolved,
  but **does not block unrelated feature development**.
- Production r5 uses a different compatibility patch lineage. Do not assume
  that rebuilding main reproduces the exact r5 frontend; review differences
  before any future deployment.

---

## Final Firefox/MPRIS acceptance — 2026-11-14

- The metadata feature **works live** with the 0.9.2-compatible r3 image.
  After Firefox fetched a consistent set of JS/WASM files, `playerctl`
  reported `xesam:title = Marvell to Acquire Lumentum in Historic $115 Billion Tech Deal`
  and `xesam:album = Bloomberg Intelligence`. The custom Waybar widget
  displayed the actual episode title.
- Firefox initially displayed a `Subresource Integrity` mismatch and
  `inline0.js` missing export `rhinepodsSetMediaMetadata`, indicating
  inconsistent/cached web assets. Disabling the network cache and hard
  refreshing resolved the failures. A subsequent normal-cache check still
  showed the correct episode title and podcast name, without manual metadata
  injection.
- Directly setting `navigator.mediaSession.metadata` in Firefox was an
  earlier diagnostic: that separate test also reached MPRIS and Waybar.
  The acceptance above is **automatic from the deployed RhinePods frontend**.
- `xesam:artist` was empty for the tested Bloomberg episode; may reflect
  missing author data. `mpris:artUrl` appeared in one verified read and
  was absent in a later read. Neither should be described as consistently
  proven. These are follow-up quality checks, **not blockers** for the original
  title/podcast metadata objective.
- App-side metadata now lives in a persistent `MediaSessionBridge` rather
  than a page-specific player's lifecycle. The exact 0.9.2 compatibility
  backport, GitHub Actions tests, offline overlay packaging and known-good
  rollback procedure are preserved in this feature's commits.
- **Accepted for merge to RhinePods `main`** at the user's request.
  Repository changes do not automatically redeploy eosbox; its custom
  container is managed separately through the existing Compose overlay.

---

## Current MPRIS browser diagnosis and r3 fix (2026-11-14)

- Original 0.9.2-compatible r1 image: 403 due to root-owned index.html mode
  0600. Repaired r2 overlay passed isolated HTTP test, and the real server
  rendered its UI at HTTP 200. It is the user's last known live custom image;
  do not assume it was replaced unless explicitly shown in terminal output.
- While an episode played, Firefox `navigator.mediaSession.metadata` was
  `null`; playerctl and Waybar still showed generic `Pinepods`. Directly
  assigning `new MediaMetadata` in browser console immediately appeared in
  `playerctl` and Waybar. So browser APIs, Firefox/MPRIS and Waybar are
  proven functional; remaining issue is the automatic web integration.
- The first patch owned Media Session metadata inside per-route `AudioPlayer`
  components and cleared metadata on their unmount, which can occur during
  navigation while actual media continues playing. The new source patch
  mounts one global `MediaSessionBridge` above `Switch<Route>`, subscribed
  to playback state. It republishes when episode/artist/podcast/cover or
  playing state changes, tracks chapter artwork, and clears only when
  playback has no current episode. The root hook and absence of player-unmount
  cleanup have static test assertions.
- Two successful GitHub Actions compilations: current RhinePods branch
  `43662925651`, and exact PinePods 0.9.2 backport `43662901995`. The
  latter generated frontend tarball 5,968,823 bytes, SHA-256
  `39d86bc9c529ae662367b66529c15c1c91a7e72e44ff93c569002720b430b0b3`.
- Revised `scripts/build-092-prebuilt.fish` fetches only this ~6 MB bundle,
  offline-builds `local/rhinepods:pinepods-0.9.2-metadata-43662901995-r3`
  with readable Nginx frontend assets, and tests actual HTTP serving in an
  isolated container without touching the running service. The Compose overlay
  now targets r3. See `docs/RHINEPODS_092_TEST.md` for exact steps and rollback.
- **Verified:** Automatic episode title and podcast album appeared in Firefox/MPRIS and Waybar on the deployed r3 image after resolving stale cached JavaScript. Author/artwork completeness remains to check separately.

---


## Incident and repair — November 14, 2026

- PinePods 0.9.2 compatible frontend compiled and packaged, but first
  deployment of `local/rhinepods:pinepods-0.9.2-metadata-43643575697` served
  **HTTP 403**. Container was running and healthy because the backend-only
  health check did not detect failure to serve frontend files.
- User rolled back via **original Compose only** and confirmed original
  PinePods web UI restored, database/downloads intact.
- Image diagnostic proved `/var/www/html/index.html` mode **0600**,
  `root:root`; `nginx:nginx` lacked read permission. This is the confirmed
  cause of the index page's 403. Earlier build script did not normalize
  artifact permissions.
- Current repair: `scripts/Dockerfile.092-permissions` derives **offline**
  from the cached failed-image tag and runs `chmod -R a+rX /var/www/html`.
  `scripts/repair-092-permissions.fish` creates a new `-perms-r2` tag and
  smoke-tests actual Nginx HTTP HTML/CSS serving in an isolated container.
  `scripts/overlay-092-prebuilt.yaml` now selects the repaired r2 tag.
- **Do not deploy r1 again.** Wait for successful isolated HTTP test,
  then the user's explicit approval / supervision for an app-only switch.
  No further GitHub artifacts, Rust recompilation, database changes or large
  downloads are required.
- Specific procedure: `docs/RHINEPODS_092_TEST.md`.


This document is shared operating context for the owner and all coding agents.
**Read `AGENTS.md` and this file at the start of work in this repository.**

## Source of truth and repository boundaries

| Repository | Role |
| --- | --- |
| `sguzman/RhinePods` | Personal podcast application and code changes; own `main` |
| `madeofpendletonwool/PinePods` | Read-only upstream source, security improvements, fixes, and releases |
| `sguzman/my-srv` | Actual eosbox Docker/Compose deployment and guarded runtime services |
| `sguzman/config-store` | Waybar integration and desktop settings |

RhinePods is **a fork**, not a copy divorced from upstream. GitHub retains
the fork relationship, and a local clone can fetch `upstream/main` at any
time. RhinePods `main` is the owner's personal product branch with local
changes. It is *not* reserved as an upstream mirror.

## Day-to-day branches

- `main` — primary long-lived branch. Once a feature has been tested and
  accepted, merge it here. The owner generally builds/uses `main`.
- `feature/<concise-topic>` — short-lived branches for one change at a time.
  Current task: `feature/media-session-metadata`. Keep it isolated until
  completed and checked; no unrelated feature development.
- `integrate/upstream-<date-or-version>` — optional short-lived branch for
  evaluating upstream changes before merging into `main`; not a permanent
  separate upstream branch. Never push an integration experiment to `main`
  without review.
- `upstream/main` — **remote-tracking reference** to official PinePods
  when the `upstream` remote is configured. Read-only; *not* a RhinePods
  branch. Never push here.

For a new local clone (using fish shell), set up remotes and inspect them:

```fish
git remote -v
git remote add upstream https://github.com/madeofpendletonwool/PinePods.git
git fetch upstream
git log --oneline --decorate --max-count=5 main
git log --oneline --decorate --max-count=5 upstream/main
```

Only run `git remote add upstream` if that remote is not already configured.
Use `origin` for RhinePods and `upstream` for PinePods.

## Integrating upstream updates (including security fixes)

1. Fetch upstream. Record upstream SHA/version, understand the changes and
   published migration/security notes. Don't assume a newer commit is safe
   simply because it is newer.
2. Create an `integrate/upstream-*` branch off the current RhinePods
   `main`, or use an equivalent reviewed pull request.
3. Merge the selected upstream commit or tagged release into that branch.
   **Prefer a merge, preserving history.** Avoid rebasing or force-pushing the
   published `main` branch. If the histories require conflict resolution,
   read the actual conflicting code and preserve PinePods fixes *and* intended
   RhinePods features; do not automatically favor `ours`.
4. Run focused tests, a Rust/Yew frontend build, and any applicable backend
   and integration checks. Check compatibility, DB schema/migrations,
   configuration, external clients and plugins before deployment.
5. Merge the reviewed integration branch into RhinePods `main`. Document
   upstream SHA and any caveats. Security fixes should be prioritized and
   can be merged independently of planned feature work.
6. Deployment is **separate**: only after explicit approval, update
   `my-srv`'s target image/Compose setup with an unchanged rollback path.
   Do not update the running server merely because RhinePods `main` moved.

Forks **do not automatically inherit future upstream commits or patches**.
Keeping RhinePods current is an explicit maintenance responsibility.

## Releases / Docker images

The owner expects to work **primarily from `main`**. A formal GitHub
release is *not required* for each change. Optional immutable tags/releases
can be added later when they help provide reproducible snapshots.

For personal builds, a locally built image may use a tag containing a
commit SHA, e.g. `local/rhinepods:git-<shortsha>`; a tag is a build artifact
identifier, **not** necessarily a GitHub release. Always know which exact
commit built the image and preserve the previous working image for rollback.

The fork inherits PinePods GitHub Actions workflows, including DockerHub
publication scripts naming **the original project's Docker repository**.
Do not enable, manually dispatch, or modify those publication workflows
to push a Rhino/RhinePods image without separate review and permission.
Local Docker image builds need **no Docker Hub login**.

## Historical milestone: rich web browser media metadata

**Original scope (title/podcast-name portion accepted live; artwork follow-up is separate):**
- Publish the *real* episode title, podcast name, creator and episode/chapter
  artwork to browser Media Session metadata in the Rust/Yew web player.
- Ensure Firefox/Linux MPRIS reports meaningful `xesam:title`,
  `xesam:album`, `xesam:artist` and, when supported, `mpris:artUrl`.
- Do not interfere with playback, controls, player switching, completed-state
  synchronization or the existing media element.
- Verify Rust/Trunk build, test Firefox `playerctl metadata` with a real
  episode, then review the visual result in Waybar.
- The initial freeze on unrelated feature work has ended following
  accepted live title/podcast metadata. New work still requires isolated
  branches, review and tests.
- Source-only changes do **not** modify the running self-hosted instance.
  Its PinePods container and database must remain untouched without
  separate informed approval.

### Metadata feature status (2026-11-14)

- Fork initialized; `main` initially matches the upstream SHA
  `4013c71f0386a343d30e7abada5c5d8643272246`.
- The existing eosbox instance runs official PinePods 0.9.2.
- A **separate, experimental** 0.9.2 patch/build overlay has previously been
  staged in `my-srv/services/pinepods/media-session/`; it has **not** been
  built or deployed. RhinePods' feature branch should become the maintained
  source of truth for the fix, not a second independent implementation.
- Source inspection confirms that `web/src/components/audio.rs` already
  knows the current episode title/artwork while `Episode` has podcast
  name/creator. The browser currently exposes only `Pinepods` via MPRIS
  rather than the actual episode title.
- Feature branch `feature/media-session-metadata` now contains the
  browser Media Session fix in `web/src/components/audio.rs` and its
  regression test in `web/tests/media_session_metadata.mjs`
  (commit `dafb52b15c0f945d80fb07a0581ee8d64a5ea025`).
- The inline JavaScript from the committed source passed local isolated
  Node.js checks (including an exact-code fingerprint comparison): episode
  title, podcast, creator, cover art, episode switching, unsafe image URL,
  teardown and unsupported browser. The checked-in regression test uses
  only Node.js built-ins; no npm installation is needed.
- Build-only check once a local clone exists:
  `node web/tests/media_session_metadata.mjs`
  followed by `docker build --target builder -f dockerfile -t local/rhinepods-web-metadata:check .`
  in the RhinePods repository root. The second command compiles the frontend
  into a **builder-only Docker image**; it does not start or replace a
  container and does not modify the server.
- **Build verification COMPLETE:** Rust/Trunk 1.99 compiled the feature
  branch frontend in GitHub Actions run `43642240155` (successful); Node
  Media Session regression tests also passed. A separate PinePods 0.9.2
  compatibility build succeeded in run `43643575697` with an approximately
  6 MB compressed frontend. No local Rust/Docker toolchain downloads needed.
- **Historical note, now resolved:** Firefox/MPRIS live verification was
  pending at this stage. The successful r3 title/podcast-name acceptance
  is documented at the top of this file.
- Keep the existing `my-srv` 0.9.2 experimental patch dormant; do not
  accidentally deploy it as a substitute for the reviewed RhinePods branch.
- **Compatibility guard discovered 2026-11-14:** upstream `main` is 44 commits
  ahead of the deployed 0.9.2 tag, with hundreds of changed files. The first
  metadata-feature Actions run (`43642240155`) successfully compiled the
  *newer* web frontend, but that alone does not establish compatibility with
  the deployed 0.9.2 API. Do **not** substitute that artifact in production.
- For testing the currently deployed server, `compat/metadata-0.9.2.patch`
  backports **only the same Media Session feature** to the exact upstream
  PinePods 0.9.2 tag (`caed39613b6218161c9d11966aa63a1a94f63750`).
  The backport's patch hunks were matched against the tagged source. The
  dedicated workflow `.github/workflows/media-session-092.yml` runs that
  build on GitHub, executes the metadata JS tests, and publishes only a
  compressed frontend artifact. This is not an official release, not a Docker
  image, and not deployed. The first workflow run is `43643575697`.
- Before any live deployment, inspect the compatibility build's results,
  package a local *web-only* overlay on the existing 0.9.2 image, verify
  current mounts and health, and request explicit approval for an app-only
  cutover. The original Compose configuration/image remain the rollback.


## Safety, review and scope

Avoid unrelated cleanup and feature creep. When working in a new conversation
or agent session, first read the root `AGENTS.md`, this file, the current
branch/diff and the actual relevant Rust code. Record verified outcomes here
so the next agent can continue without relying on chat memory. Changes
should be small, understandable and reversible. No reboot or service
restart without explicit user consent.


### Small-download deployment experiment

- `docs/RHINEPODS_092_TEST.md` documents the approval-gated offline image
  overlay, verified artifact SHA-256, and rollback.
- `scripts/build-092-prebuilt.fish` fetches only the GitHub Actions 0.9.2
  frontend (~6 MB), or accepts its manually downloaded ZIP, verifies SHA-256,
  then runs an offline Docker `COPY`-only build on the cached official image.
  It does not start or restart any service.
- `scripts/overlay-092-prebuilt.yaml` is an opt-in image-only override.
  Never apply without approval; existing Compose and PostgreSQL/Valkey are
  unchanged. GitHub artifact expires 2026-11-21.
