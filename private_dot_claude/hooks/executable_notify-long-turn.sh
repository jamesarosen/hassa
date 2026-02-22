#!/bin/bash
# Notify via macOS system notification if the last turn took > 30 seconds

THRESHOLD_SECONDS=30

# Read hook input from stdin
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')

if [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# Find the last user message (which starts the turn)
LAST_USER_LINE=$(grep -n '"type":"user"' "$TRANSCRIPT_PATH" | tail -1 | cut -d: -f1)

if [ -z "$LAST_USER_LINE" ]; then
  exit 0
fi

# Get timestamp of the last user message (turn start) and last line (turn end)
START_TS=$(sed -n "${LAST_USER_LINE}p" "$TRANSCRIPT_PATH" | jq -r '.timestamp // empty')
END_TS=$(tail -1 "$TRANSCRIPT_PATH" | jq -r '.timestamp // empty')

if [ -z "$START_TS" ] || [ -z "$END_TS" ]; then
  exit 0
fi

# Convert ISO timestamps to epoch seconds
START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${START_TS%%.*}" +%s 2>/dev/null)
END_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${END_TS%%.*}" +%s 2>/dev/null)

if [ -z "$START_EPOCH" ] || [ -z "$END_EPOCH" ]; then
  exit 0
fi

DURATION=$((END_EPOCH - START_EPOCH))

if [ "$DURATION" -ge "$THRESHOLD_SECONDS" ]; then
  osascript -e "display notification \"Turn completed after ${DURATION}s\" with title \"Claude Code\" sound name \"Glass\""
fi
