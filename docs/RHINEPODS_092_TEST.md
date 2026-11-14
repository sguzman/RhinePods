# RhinePods metadata — prebuilt PinePods 0.9.2 frontend (opt-in)

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
