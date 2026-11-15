# RhinePods metadata — prebuilt PinePods 0.9.2 frontend (opt-in)

## r4 metadata completeness + Waybar artwork (candidate, not deployed)

The already accepted r3 frontend resolves generic episode titles, but the
Bloomberg episode had an empty MPRIS artist and intermittent `mpris:artUrl`.

The r4 source fix is isolated on `fix/media-artwork-artist`:
- Artist = RSS author when present; otherwise the known podcast name.
- Artwork = current chapter image, episode art, then feed cover URL.
- No duplicate MediaSession metadata publication just because playback
  paused/resumed, reducing unnecessary Firefox image churn.
- The baked previous frontend JS/WASM assets are **removed within the new
  image layer** before copying the complete r4 assets, preventing mixing
  old and new filenames. No running files or Docker volumes are deleted.

GitHub Actions results:
- Current RhinePods frontend: successful compile
  <https://github.com/sguzman/RhinePods/actions/runs/43669310907>
- **Exact PinePods 0.9.2** frontend: successful compile
  <https://github.com/sguzman/RhinePods/actions/runs/43669406045>
- New compressed tarball: **5,968,686 bytes**
- Exact tarball SHA-256:
  `1d0031d6769c2f0bc5763871b9243d8b6c9bdcae6c6435d6887fc206b0698c82`
- New local image tag:
  `local/rhinepods:pinepods-0.9.2-metadata-43669406045-r4`

Builder now accepts the currently deployed r3 image as its starting
service state, but still builds **only** from the locally cached official
0.9.2 image. It does not pull Docker layers or recompile Rust, and it
uses an isolated Nginx smoke test before any optional Compose cutover.

After reviewing local work, the user may opt into a test from
`~/Code/Apps/RhinePods`:

```fish
git status --short
git fetch origin fix/media-artwork-artist
git switch --track -c fix/media-artwork-artist origin/fix/media-artwork-artist
fish scripts/build-092-prebuilt.fish
```

Check for `PASS: Nginx serves RhinePods HTML and CSS over HTTP`. Only
then use the existing one-service Compose overlay to switch PinePods.
Hard reload Firefox once after deployment, then check browser
`navigator.mediaSession.metadata` and
`playerctl --player=firefox metadata` for artist/artUrl.

Separately, `sguzman/config-store` branch `feature/waybar-media-art`
contains the native Waybar 26px cover image module and a track-specific
cache. It has its own passing no-network GitHub Actions shell tests, but
is **not deployed to eosbox**. That UI must be installed and visually
verified before either feature branch is merged.

See the previously documented r3 rollback procedure below if needed.
The backend, podcasts, database, volumes and media playback APIs are
unchanged.

---


## Live verification: r3 acceptance (2026-11-14)

The r3 overlay was deployed to eosbox and the PinePods web UI served HTTP 200.
Firefox initially showed an integrity mismatch and missing `inline0.js`
module export because of inconsistent cached JavaScript. With Firefox Network
cache temporarily disabled and a hard reload, automatic episode metadata
appeared in **Firefox MPRIS and Waybar**: the full episode title and
`Bloomberg Intelligence` album name. A later normal-cache check confirmed
both fields persisted. Artwork appeared once but not in a later reading;
`xesam:artist` remained empty for this episode. The original generic-title
problem is **resolved**; these minor fields remain observations to revisit.

No further container changes are necessary for this acceptance. This page
also preserves the rollback instructions for future experiments.

---


## Current metadata bridge fix — new r3 build (2026-11-14)

**Firefox/Web Console diagnosis:** While a real episode was playing,
`navigator.mediaSession.metadata` was `null` even though the upgraded
frontend served HTTP 200. Directly assigning
`new MediaMetadata({title: "RHINEPODS DIRECT TEST", ...})` in Firefox worked:
`playerctl` and Waybar both immediately displayed the test title. Therefore
Firefox → MPRIS → Waybar works, and the bug is inside the frontend.

**Source-cause hypothesis:** The first patch put metadata setting and cleanup
inside the page-specific `AudioPlayer`, which PinePods unmounts on route
changes even if playback continues. Its unmount cleanup could clear the
metadata. To avoid that fragile lifecycle entirely, we introduced **one
app-wide `MediaSessionBridge`** at the `LanguageManager`/router level. It
subscribes to `UIState` and updates title, creator, podcast, artwork when
those values or the playback state change; it only clears metadata when
there is no current episode. It also picks chapter artwork from playback
position without rerendering for every elapsed second.

**Verified:** Both the current Rhino/RhinePods frontend and a distinct build
against upstream PinePods **0.9.2** compiled successfully in GitHub Actions.
Compatibility run: https://github.com/sguzman/RhinePods/actions/runs/43662901995

- Latest compatible artifact: `rhinepods-web-pinepods-0.9.2-metadata`
- Compressed frontend tarball size: **5,968,823 bytes** (~5.69 MiB)
- SHA-256: `39d86bc9c529ae662367b66529c15c1c91a7e72e44ff93c569002720b430b0b3`
- Artifact expires approximately **November 21, 2026, 19:27 Mexico City time**.
- The build helper has been updated to use this new run, normalize web file
  permissions with `chmod -R a+rX /var/www/html`, and smoke-test *real Nginx
  HTTP HTML + CSS* in isolation before allowing deployment.
- New local image tag: `local/rhinepods:pinepods-0.9.2-metadata-43662901995-r3`.
- Opt-in Compose overlay `scripts/overlay-092-prebuilt.yaml` now selects r3.

Run separately from the actual existing local clone (check `git status --short`
if there are uncommitted edits):

```fish
cd ~/Code/Apps/RhinePods
```

```fish
git pull --ff-only origin feature/media-session-metadata
```

```fish
fish scripts/build-092-prebuilt.fish
```

The builder permits either the official 0.9.2 image or the previous tested
r2 image to be running. It only downloads the **small** frontend ZIP; it
uses the original already-cached image as a local build base. **No service
replacement happens during image building.** The safe-test output must
include `PASS: Nginx serves RhinePods HTML and CSS over HTTP` before cutover.

After that, with explicit user permission, the targeted switch remains:

```fish
docker-compose --env-file /services/pinepods/pinepods.env -f ~/Projects/my-srv/services/pinepods/docker-compose.yaml -f ~/Code/Apps/RhinePods/scripts/overlay-092-prebuilt.yaml up -d --no-deps pinepods
```

Then actually verify `curl -fsS -o /dev/null -w 'HTTP %{http_code}\\n' http://127.0.0.1:8040/`, load the frontend in Firefox (hard reload
with Ctrl+Shift+R), start an episode, verify
`navigator.mediaSession.metadata` and `playerctl --player=firefox metadata`.
**Compilation success alone does not prove the live metadata fix.** If
necessary, use the **original Compose file alone** to revert only PinePods.

---


## Critical update — 403 root cause confirmed (2026-11-14)

The first r1 test image started and reported API health, **but Nginx returned 403**.
An actual image inspection proved that `/var/www/html/index.html` was
`-rw------- root:root` (0600) and that `nginx:nginx` **could not read it**.
The user restored the original official 0.9.2 container and confirmed the UI
works again. This is a packaging/permissions failure, not a Rust compile error.

**Do NOT deploy the old r1 image again.** Do not rebuild Rust or redownload the
frontend. The new `scripts/Dockerfile.092-permissions` uses the **existing r1
image as its base** and fixes web access with `chmod -R a+rX /var/www/html`.
`scripts/repair-092-permissions.fish` creates
`local/rhinepods:pinepods-0.9.2-metadata-43643575697-perms-r2` entirely
offline, then tests *Nginx serving HTML and CSS via HTTP in a disposable
container*, not just the API health endpoint. If that test fails, **do not
switch** the real server. The Compose image-only overlay now points at r2.

On eosbox in fish, separately:

```fish
cd ~/Code/Apps/RhinePods
```

```fish
git pull --ff-only origin feature/media-session-metadata
```

```fish
fish scripts/repair-092-permissions.fish
```

After it prints `PASS: Nginx serves the real RhinePods HTML and CSS over HTTP`
and the new r2 tag, review Docker/Compose and explicitly approved cutover.
The isolated test requires no credentials, exposes no host ports and starts
neither the PostgreSQL nor PinePods backend. No host reboot or other services
need changing. Rollback is the original Compose file without the overlay.

---


**Current state:** metadata tests and Rust/Yew release build succeeded on GitHub Actions.
**Still untested:** browser/runtime MPRIS integration and deploying on eosbox.
**Do not deploy without explicit approval.** This is *not* a full RhinePods
upstream upgrade and does not yet change RhinePods `main`.

## Provenance and size

- GitHub run: https://github.com/sguzman/RhinePods/actions/runs/43643575697
- Exact upstream PinePods tag: `0.9.2`, SHA `caed39613b6218161c9d11966aa63a1a94f63750`.
- Scoped source patch: `compat/metadata-0.9.2.patch` in the metadata feature branch.
- Successful run passed the regression test and compiled the 0.9.2 frontend.
- Frontend tar.gz: **5,965,685 bytes** (5.69 MiB); Docker context after
  unpacking is about 14 MB. GitHub's artifact ZIP around it is roughly 6 MB.
- Verified tarball SHA-256:
  `0c47286c155b86148e94fff0bacc3595d6042cab8c2907d6b3d22cec50ba905e`
- Artifact: `rhinepods-web-pinepods-0.9.2-metadata`, available for 7 days
  after November 14, 2026 (expires November 21). Do not rely on it afterward.

## 1. Create local Docker image — **no deployment**

In fish, run each command separately. This is the user's actual clone path:

```fish
cd ~/Code/Apps/RhinePods
```

```fish
git status --short
```

If there are local modifications, inspect them before any pull. Otherwise:

```fish
git pull --ff-only origin feature/media-session-metadata
```

With GitHub CLI `gh` already installed and authenticated:

```fish
fish scripts/build-092-prebuilt.fish
```

**No need to install `gh`** if it isn't present: open the GitHub run link,
click the `rhinepods-web-pinepods-0.9.2-metadata` artifact at the bottom of
its page, and download the ZIP (approximately 6 MB). Then use:

```fish
fish scripts/build-092-prebuilt.fish ~/Downloads/rhinepods-web-pinepods-0.9.2-metadata.zip
```

The script deliberately fails *before downloading* if the original local
`madeofpendletonwool/pinepods:0.9.2` image is missing or the running
`pinepods` container doesn't use it. The SHA-256 checksum is checked before
unpacking. Its Dockerfile contains only `FROM`, `LABEL` and `COPY`, so the
build does no Rust compilation or network access. Docker uses
`--pull=false --network=none` and the already cached original image.

The resulting local tag is:

`local/rhinepods:pinepods-0.9.2-metadata-43643575697`

The script does **not** change production Compose, restart the application,
create a second backend, run migrations, touch volumes or alter the database.
It leaves the previous 0.9.2 image in place as the rollback target.

## 2. Read-only preflight

Run one command at a time, and share the output for review. No secrets needed.

```fish
docker inspect --format '{{.Config.Image}} {{.State.Status}}' pinepods
```

```fish
docker image inspect local/rhinepods:pinepods-0.9.2-metadata-43643575697 --format '{{.Id}}'
```

```fish
docker inspect --format '{{range .Mounts}}{{println .Destination .Source}}{{end}}' pinepods
```

```fish
curl --fail --silent --show-error http://127.0.0.1:8040/api/health
```

Also verify Docker Compose can resolve the original private env file, but do
not print a full expanded Compose config: that would expose credentials.

## 3. Cutover — ONLY after explicit user approval

This uses the **existing** `my-srv/services/pinepods/docker-compose.yaml`
plus `scripts/overlay-092-prebuilt.yaml`. The latter changes only the
`pinepods.image` field. Preserve the original service limits, binds, ports,
networks and environment. Verify the paths and use the correct local
`my-srv` checkout; its location should not be guessed.

After review and explicit consent, a targeted Compose `up -d --no-deps
pinepods` would recreate **only** the PinePods application, interrupting any
playing episode and reconnecting clients. It must NOT restart PostgreSQL,
Valkey, the entire service stack or the host. At that point verify the health
endpoint, login, playback, Fire tablet and Firefox MPRIS:

```fish
playerctl --player=firefox metadata
```

Expected: real `xesam:title`, `xesam:album`, `xesam:artist`, and possibly
`mpris:artUrl`. If Firefox still reports the page title, inspect Service
Worker/cache and Media Session state; do not add another feature to mask the
issue.

## 4. Rollback — only if a cutover occurred

Recreate **only** `pinepods` from the original Compose file *without* the
optional overlay. The original official image remains cached, so rollback
doesn't require downloading it. Keep the same env file and volume mounts.
The rollback may interrupt active playback. Never `docker compose down`,
remove volumes, or rerun database setup just to roll back a frontend change.

No image has been deployed by creating these files.
