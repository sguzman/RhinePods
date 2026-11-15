# Podcast library investigation — accepted integration (2026-11-15)

## Verified observations

- Bloomberg Businessweek, ID 115, was subscribed and returned by the live
  authenticated API with 5,587 episodes.
- The official Omny cover reads "Businessweek Daily" even though the API
  title is "Bloomberg Businessweek". The grid hid the canonical title until
  hover; the apparent missing podcast was a display misunderstanding.
- A distinct stale 120-second subscription list cache bug was reproduced
  in a real Yew browser test after a successful custom-feed add. The narrow
  fix invalidates the list after POST and refreshes it upon library entry.
  This was **not proven** to cause the original reported symptom.

## Included in main-branch integration

- Cached subscriptions list safeguards, canonical title visibility
- Yew browser regression tests, no-npm label check
- An independent patch and CI check against exact upstream PinePods 0.9.2
- Updated agent workflow lifting the historical feature freeze

## Deliberately excluded

- r4 MPRIS artist/artwork work and generic now-playing backend additions
- Local r5 Docker overlay packaging and Compose changes
- Database changes, service restarts, or new deployments

Production r5 is built from the investigation branch's compatibility
patch lineage, which is **not identical** to this clean main-branch set.
A new deployment from main must be reviewed independently. The missing
artwork on some episodes remains a separate open follow-up, not a blocker
to unrelated new features.
