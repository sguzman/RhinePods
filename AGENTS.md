# RhinePods — agent instructions

This is **sguzman/RhinePods**, a personal fork of
[upstream PinePods](https://github.com/madeofpendletonwool/PinePods).
Before changing code, read [docs/RHINEPODS_WORKFLOW.md](docs/RHINEPODS_WORKFLOW.md).

## Non-negotiable project rules

- **RhinePods `main` is the owner's ongoing personal integration branch**, not an
  unmodified mirror of PinePods. Tags/releases are optional; `main` is the
  usual development/deployment source once changes pass validation.
- Preserve the GitHub fork relationship and access to upstream's `main`.
  The upstream repository is `madeofpendletonwool/PinePods`; never push to it
  without an explicit upstream contribution request.
- Keep features in isolated `feature/*` branches; merge into RhinePods
  `main` only after appropriate review and tests. Do not force-push `main`,
  silently overwrite upstream code, or blindly synchronize upstream changes.
- Upstream releases/security patches are valuable. Fetch upstream, inspect
  the diff and migration requirements, integrate safely, and verify the
  changes alongside RhinePods modifications. See the workflow document.
- **Current scope: finish browser Media Session/MPRIS episode metadata
  (title, podcast name, creator, artwork) before starting any other feature.**
  Do not implement unrelated podcast, UI, download, queue, or sync features.
- Production deployment is a different repository:
  `sguzman/my-srv` under `services/pinepods/`. Waybar integration is
  `sguzman/config-store` under `waybar/`. Do not change either as a side
  effect of editing RhinePods, and do not deploy/restart services without
  explicit informed approval.
- Never commit credentials, tokens, secrets, private .env files, or user data.
  Keep upstream GPL notices/license and appropriate attribution.
- Prefer inspecting actual Rust/Yew source and running relevant checks over
  assumptions; distinguish source, simulated tests, a successful build, and
  verified live playback. Preserve the existing player/controls unless the
  requested feature specifically requires changing them.
- No automatic production deployment. No need for a Docker Hub account or
  registry publishing: local Docker builds are sufficient.
- Report only work actually performed. Stop for a clear error rather than
  papering over failed builds, migrations, or mismatched branches.
