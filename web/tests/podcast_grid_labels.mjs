// Guards the grid against hiding the API podcast title behind mismatched
// publisher-provided artwork. Uses Node built-ins; no package install needed.
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const css = readFileSync(new URL('../static/styles.css', import.meta.url), 'utf8');
const page = readFileSync(new URL('../src/pages/podcasts.rs', import.meta.url), 'utf8');
const rule = css.match(/\.podcast-info\s*\{([^}]*)\}/s)?.[1];
assert.ok(rule, 'missing podcast info overlay style');
assert.match(rule, /opacity\s*:\s*1\s*;/, 'canonical podcast name must be visible without hover');
assert.match(page, /class="podcast-title-grid"\s*>\s*\{&podcast\.podcastname\}/,
  'grid labels must use the canonical subscription name returned by the API');
console.log('PASS: grid displays the canonical podcast name without hovering');
