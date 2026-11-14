# RhinePods development, branching and upstream workflow

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

## Current feature: rich web browser media metadata

**Only active feature until finished:**
- Publish the *real* episode title, podcast name, creator and episode/chapter
  artwork to browser Media Session metadata in the Rust/Yew web player.
- Ensure Firefox/Linux MPRIS reports meaningful `xesam:title`,
  `xesam:album`, `xesam:artist` and, when supported, `mpris:artUrl`.
- Do not interfere with playback, controls, player switching, completed-state
  synchronization or the existing media element.
- Verify Rust/Trunk build, test Firefox `playerctl metadata` with a real
  episode, then review the visual result in Waybar.
- No cover thumbnail in Waybar, queue changes, downloads redesign, or
  other unrelated features until this is finished.
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
- **Still pending:** full Rust/Trunk compilation and real
  Firefox/MPRIS `playerctl metadata` verification on eosbox.
  Do not merge to RhinePods `main` or deploy on eosbox until verified.
- Keep the existing `my-srv` 0.9.2 experimental patch dormant; do not
  accidentally deploy it as a substitute for the reviewed RhinePods branch.

## Safety, review and scope

Avoid unrelated cleanup and feature creep. When working in a new conversation
or agent session, first read the root `AGENTS.md`, this file, the current
branch/diff and the actual relevant Rust code. Record verified outcomes here
so the next agent can continue without relying on chat memory. Changes
should be small, understandable and reversible. No reboot or service
restart without explicit user consent.
