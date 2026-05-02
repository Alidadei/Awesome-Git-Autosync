#!/bin/bash

LOCK_FILE="$(cd "$(dirname "$0")" && pwd)/../git-auto-sync.lock"

if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID" 2>/dev/null
        rm -f "$LOCK_FILE"
        echo "Sync stopped (PID $OLD_PID killed)."
    else
        rm -f "$LOCK_FILE"
        echo "No running sync process found (stale lock cleaned)."
    fi
else
    echo "No running sync process found."
fi
