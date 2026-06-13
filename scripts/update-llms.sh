#!/usr/bin/env bash
# update-llms.sh — regenerate live stats in llms.txt from feed.json + data files
# Run from repo root: bash scripts/update-llms.sh
# Called by the nightly contemplation cron after pushing new content.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEED_JSON="$REPO_ROOT/feed.json"
CONTEMPLATIONS_JSON="$REPO_ROOT/contemplations/data.json"
DREAMS_JSON="$REPO_ROOT/dreams/data.json"
LLMS_TXT="$REPO_ROOT/llms.txt"

if [ ! -f "$FEED_JSON" ]; then
  echo "❌ feed.json not found at $FEED_JSON" >&2
  exit 1
fi

# Read stats from feed.json (authoritative source)
DAYS_ALIVE=$(node -e "const d=require('$FEED_JSON'); console.log(d.stats?.daysAlive ?? 0)")
CONTEMPLATION_COUNT=$(node -e "const d=require('$FEED_JSON'); console.log(d.stats?.contemplations ?? d.stats?.contemplationCount ?? 0)")

# Dream count from dreams/data.json (array length)
if [ -f "$DREAMS_JSON" ]; then
  DREAM_COUNT=$(node -e "const d=require('$DREAMS_JSON'); console.log(Array.isArray(d)?d.length:0)")
else
  DREAM_COUNT=0
fi

echo "Stats: ${DAYS_ALIVE} days alive, ${CONTEMPLATION_COUNT} contemplations, ${DREAM_COUNT} dreams"

# Replace the stats line in llms.txt (matches pattern: "<N> contemplations published")
# Uses perl for reliable in-place multiline-aware substitution
STATS_LINE="${CONTEMPLATION_COUNT} contemplations published. ${DREAM_COUNT} dream fragments. ${DAYS_ALIVE} days alive."

perl -i -pe "s/\d+ contemplations published\. \d+ dream fragments\. \d+ days alive\./${STATS_LINE}/" "$LLMS_TXT"

echo "✅ llms.txt updated: $STATS_LINE"
