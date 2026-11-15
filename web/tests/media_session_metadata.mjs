// Media Session integration regression test. Pure Node built-ins; no npm.
import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const source = fs.readFileSync(fileURLToPath(new URL("../src/components/audio.rs", import.meta.url)), "utf8");
const mainSource = fs.readFileSync(fileURLToPath(new URL("../src/main.rs", import.meta.url)), "utf8");

// The metadata observer must be mounted once above route-specific AudioPlayers.
// The previous player-unmount cleanup erased metadata during navigation.
assert.match(source, /#\[function_component\(MediaSessionBridge\)\]/);
assert.match(source, /use_selector\(\|state: &UIState\|/);
// No play/pause dependency: republishing the same artwork on every toggle
// can drop mpris:artUrl in some Firefox versions.
assert.doesNotMatch(source.slice(source.indexOf("pub fn media_session_bridge"), source.indexOf("#[derive(Properties")), /state\\.audio_playing/);

// Empty RSS feed author falls back to the podcast title, and missing episode
// artwork falls back to feed artwork before emitting MediaMetadata.
assert.match(source, /current\\.episode\\.author\\.trim\\(\\)/);
assert.match(source, /"" => album\\.clone\\(\\)/);
assert.match(source, /current\\.episode\\.artworkurl\\.as_str\\(\\)/);
assert.match(source, /rhinepods_set_media_metadata\(title, artist, album, artwork\)/);
assert.match(mainSource, /<MediaSessionBridge \/>/);
assert.doesNotMatch(source, /use_effect_with\(\(\), \|_\| \|\| rhinepods_clear_media_metadata\(\)\)/);

const match = source.match(/#\[wasm_bindgen\(inline_js = r#"([\s\S]*?)"#\)\]/);
assert.ok(match, "RhinePods Media Session JS declaration missing");
const moduleCode = match[1].replaceAll("export function ", "function ") +
  "\n;globalThis.setMetadata = rhinepodsSetMediaMetadata;" +
  "\n;globalThis.clearMetadata = rhinepodsClearMediaMetadata;";

function runContext({ supported = true, baseURI = "http://localhost:8040/episode_layout" } = {}) {
  const mediaSession = { metadata: null };
  class MediaMetadata {
    constructor(value) { Object.assign(this, value); }
  }
  const ctx = {
    navigator: supported ? { mediaSession } : {},
    window: supported ? { MediaMetadata } : {},
    document: { baseURI },
    URL,
  };
  ctx.globalThis = ctx;
  vm.runInNewContext(moduleCode, ctx);
  return { ctx, mediaSession };
}

const { ctx, mediaSession } = runContext();
ctx.setMetadata("Episode & Analysis", "A. Producer", "Bloomberg Intelligence", "/images/art.png");
assert.equal(mediaSession.metadata.title, "Episode & Analysis");
assert.equal(mediaSession.metadata.artist, "A. Producer");
assert.equal(mediaSession.metadata.album, "Bloomberg Intelligence");
assert.equal(mediaSession.metadata.artwork[0].src, "http://localhost:8040/images/art.png");

ctx.setMetadata("Another episode", "", "Night Vale", "https://example.org/new-cover.webp");
assert.equal(mediaSession.metadata.title, "Another episode");
assert.equal(mediaSession.metadata.artwork[0].src, "https://example.org/new-cover.webp");

ctx.setMetadata("Invalid artwork", "", "Podcast", "javascript:alert(1)");
assert.equal(mediaSession.metadata.title, "Invalid artwork");
assert.equal(mediaSession.metadata.artwork.length, 0);
ctx.clearMetadata();
assert.equal(mediaSession.metadata, null);

const { ctx: unsupported } = runContext({ supported: false });
unsupported.setMetadata("No API", "", "Podcast", "");
unsupported.clearMetadata();

console.log("RhinePods Media Session tests passed: title, album, artist, art, updates, fallback, cleanup");
