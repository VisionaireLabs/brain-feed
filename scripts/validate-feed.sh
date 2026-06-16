#!/usr/bin/env bash
# validate-feed.sh — run before pushing feed.json changes to catch schema violations
# Usage: bash scripts/validate-feed.sh
# Exit 0 = valid. Exit 1 = violations found (fix before pushing).

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEED_JSON="$REPO_ROOT/feed.json"

node -e "
const fs = require('fs');
const d = JSON.parse(fs.readFileSync('$FEED_JSON', 'utf8'));
const knownTypes = ['self-maintainer', 'self-maintainer-run', 'brain-feed-update', 'contemplation', 'dream', 'task', 'system'];
// Expected time format: 'MMM DD, HH:MM UTC' — must contain HH:MM
const TIME_HAS_CLOCK = /\d{1,2}:\d{2}/;
// Year-only pattern: 'Jun 13, 2026 UTC' (4-digit year right before UTC, no clock)
const TIME_YEAR_ONLY = /\b\d{4}\s+UTC$/;
// Midnight-UTC sentinel: '00:00 UTC' is almost always a broken placeholder, not a real midnight event
const TIME_MIDNIGHT_UTC = /\b00:00\s+UTC/;
// Max feed size before warning (soft cap — over this is a sign of unbounded accumulation)
const FEED_SOFT_CAP = 30;
let errors = 0;
d.feed.forEach((entry, i) => {
  const hasContent = entry.content || entry.summary || entry.preview;
  if (!hasContent) { console.error('feed['+i+'] missing content or summary'); errors++; }
  if (!entry.type) { console.error('feed['+i+'] empty type — must be one of: '+knownTypes.join(', ')); errors++; }
  else if (!knownTypes.includes(entry.type)) { console.error('feed['+i+'] unknown type: '+entry.type+' (allowed: '+knownTypes.join(', ')+')'); errors++; }
  if (!entry.time) { console.error('feed['+i+'] empty time — all entries must have a timestamp'); errors++; }
  else if (!TIME_HAS_CLOCK.test(entry.time)) {
    console.error('feed['+i+'] time missing HH:MM component: '+JSON.stringify(entry.time)+' — use format \"MMM DD, HH:MM UTC\"');
    errors++;
  } else if (TIME_YEAR_ONLY.test(entry.time)) {
    console.error('feed['+i+'] time has year-only format: '+JSON.stringify(entry.time)+' — use \"MMM DD, HH:MM UTC\" without year');
    errors++;
  } else if (TIME_MIDNIGHT_UTC.test(entry.time)) {
    console.error('feed['+i+'] suspicious 00:00 UTC timestamp: '+JSON.stringify(entry.time)+' — if this is a real midnight event, change to 00:01 UTC; otherwise fix the time source');
    errors++;
  }
});
if (d.feed.length > FEED_SOFT_CAP) {
  console.error('feed.json has ' + d.feed.length + ' entries (soft cap: ' + FEED_SOFT_CAP + ') — trim old entries to prevent unbounded growth');
  errors++;
}
if (errors > 0) {
  console.error('\nfeed.json has ' + errors + ' schema violation(s). Fix before pushing.');
  process.exit(1);
}
console.log('feed.json valid: ' + d.feed.length + ' entries, all have type+time with HH:MM clock');
"
