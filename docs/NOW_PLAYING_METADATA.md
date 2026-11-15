# Now-playing metadata service

RhinePods already provides a general-purpose, authenticated, multi-device
now-playing service inherited from upstream PinePods 0.9.2.

## Access

`GET /api/data/now_playing_devices?user_id=<id>`

`Api-Key: <user-api-key>` header is required. Access is checked against the
requested user ID. The JSON response is `{"devices":[...]}`, with ephemeral
Valkey snapshots (45-second TTL). Changes are also broadcast to connected
clients over the existing authenticated `/ws/api/nowplaying/<user_id>` channel.

This is **not** a Waybar-specific API. Any authorized application can consume it.

Each device snapshot reports:
- `device_id`, `device_name`, `device_type`
- `episode_id`, `is_youtube`, `title`
- `artist`, `podcast_name` (NEW, optional, default empty)
- `artwork_url` (URL only, not image bytes)
- `position_sec`, `duration_sec`, `playing`, `speed`, `updated_at`
- `capabilities` for advisory remote controls

Clients still own playback; the server only mirrors reports. Metadata
changes do not install media-key handlers, claim MPRIS ownership, or
reassign player selection. The generic snapshot does not scrape Firefox.

## Compatibility and deployment

This branch extends the **server schema** and the **current web frontend**
report format. Other clients can continue sending their old reports:
`artist` and `podcast_name` are marked with Serde defaults. Older Valkey
snapshots lacking those fields also deserialize with empty strings.

**The existing production Docker service is upstream PinePods 0.9.2 with
an overlaid frontend. It has NOT been upgraded by this branch.** Its
existing endpoint already delivers `episode_id`, `title`, and
`artwork_url`. The new artist and podcast fields will require a
compatible backend version in a separately tested deployment; do not
assume they are live yet. The earlier r4 0.9.2 frontend artifact also
does not contain the new generic report fields.

## Example response

```json
{
  "devices": [
    {
      "device_id": "tab-instance",
      "device_name": "Web · Firefox",
      "device_type": "Web",
      "episode_id": 24656,
      "is_youtube": false,
      "title": "Example episode",
      "artist": "Example host",
      "podcast_name": "Example podcast",
      "artwork_url": "https://example.org/cover.png",
      "position_sec": 60,
      "duration_sec": 1800,
      "playing": true,
      "speed": 1,
      "updated_at": 1234567890,
      "capabilities": []
    }
  ]
}
```

Values above are illustrative, not a live API response. If the RSS author
is missing, the current frontend reports the podcast name as the artist
fallback. There are no public/anonymous metadata endpoints.

Waybar's optional image integration is in the private config-store
`feature/waybar-rhinepods-metadata` branch; it matches the selected
Firefox episode against this general API and leaves all non-RhinePods
MPRIS players unchanged.
