#!/bin/bash

# Git Auto Sync Script (Linux / macOS)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_LIST="$SCRIPT_DIR/repos.txt"
LOG_FILE="$SCRIPT_DIR/git-auto-sync.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== Sync started ==="

if [ ! -f "$REPO_LIST" ]; then
    log "ERROR: repos.txt not found"
    exit 1
fi

while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue

    if [ ! -d "$line/.git" ]; then
        log "SKIP: $line is not a git repo"
        continue
    fi

    log "Syncing: $line"
    cd "$line" || continue

    # Add all changes
    git add -A

    # Commit if there are staged changes
    if ! git diff --cached --quiet 2>/dev/null; then
        git commit -m "auto sync $(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE" 2>&1
        log "  Committed"
    else
        log "  Nothing to commit"
    fi

    # Pull with rebase
    git pull --rebase --autostash >> "$LOG_FILE" 2>&1

    # Push
    if git push >> "$LOG_FILE" 2>&1; then
        log "  Pushed"
    else
        log "  ERROR: Push failed"
    fi

done < "$REPO_LIST"

log "=== Sync finished ==="
