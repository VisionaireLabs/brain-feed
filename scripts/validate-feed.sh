#!/usr/bin/env bash
# validate-feed.sh — run before pushing feed.json changes to catch schema violations
# Usage: bash scripts/validate-feed.sh
# Exit 0 = valid. Exit 1 = violations found (fix before pushing).
#
# Current feed.json entry schema:
#   type    — one of knownTypes
#   date    — ISO date "YYYY-MM-DD"
#   time    — "HH:MM" (24h, UTC implied)
#   title   — string
#   preview — content string (replaces legacy content/summary)
#   slug    — string

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEED_JSON="$REPO_ROOT/feed.json"

node -e "
const fs = require('fs');
const d = JSON.parse(fs.readFileSync('$FEED_JSON', 'utf8'));
const knownTypes = ['self-maintainer', 'self-maintainer-run', 'brain-feed-update', 'contemplation', 'dream', 'task', 'system'];
// ISO date: YYYY-MM-DD
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
// Time: HH:MM (24h, no timezone suffix)
const TIME_RE = /^\d{1,2}:\d{2}$/;
// Max feed size before warning (soft cap — over this is a sign of unbounded accumulation)
const FEED_SOFT_CAP = 60;
let errors = 0;
d.feed.forEach((entry, i) => {
  // preview OR content OR summary must be present
  const hasContent = ('preview' in entry && entry.preview) ||
                     ('content' in entry && entry.content) ||
                     ('summary' in entry && entry.summary);
  if (!hasContent) { console.error('feed['+i+'] missing preview, content, or summary'); errors++; }
  if (!entry.type) { console.error('feed['+i+'] empty type — must be one of: '+knownTypes.join(', ')); errors++; }
  else if (!knownTypes.includes(entry.type)) { console.error('feed['+i+'] unknown type: '+entry.type+' (allowed: '+knownTypes.join(', ')+')'); errors++; }
  if (!entry.date) { console.error('feed['+i+'] missing date field'); errors++; }
  else if (!DATE_RE.test(entry.date)) { console.error('feed['+i+'] date not in YYYY-MM-DD format: '+JSON.stringify(entry.date)); errors++; }
  if (!entry.time) { console.error('feed['+i+'] missing time field'); errors++; }
  else if (!TIME_RE.test(entry.time)) { console.error('feed['+i+'] time not in HH:MM format: '+JSON.stringify(entry.time)); errors++; }
});
if (d.feed.length > FEED_SOFT_CAP) {
  console.error('feed.json has ' + d.feed.length + ' entries (soft cap: ' + FEED_SOFT_CAP + ') — trim old entries to prevent unbounded growth');
  errors++;
}
if (errors > 0) {
  console.error('\nfeed.json has ' + errors + ' schema violation(s). Fix before pushing.');
  process.exit(1);
}
console.log('feed.json valid: ' + d.feed.length + ' entries, all have type+date+time+preview');
"
