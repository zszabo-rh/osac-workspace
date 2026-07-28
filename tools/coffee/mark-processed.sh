#!/usr/bin/env bash
# mark-processed.sh — prepend [PROCESSED YYYY-MM-DD] to all unprocessed transcript files
# Run after coffee-update transcript analysis is complete.
set -o pipefail

TRANSCRIPTS="$HOME/projects/osac-workspace/artifacts/meeting_transcripts"
TODAY=$(date +%Y-%m-%d)

find "$TRANSCRIPTS" \( -name "*.txt" -o -name "*.eml" \) 2>/dev/null | sort | while IFS= read -r f; do
  if ! head -1 "$f" 2>/dev/null | grep -q "^\[PROCESSED"; then
    tmpfile=$(mktemp)
    echo "[PROCESSED $TODAY]" > "$tmpfile"
    cat "$f" >> "$tmpfile"
    mv "$tmpfile" "$f"
    echo "marked: $(basename "$f")"
  fi
done
echo "done"
