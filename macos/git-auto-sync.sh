#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_LIST="$ROOT_DIR/repos.txt"
LOG_FILE="$ROOT_DIR/git-auto-sync.log"
RECENT_LOG="$ROOT_DIR/git-auto-sync-recent.log"
CONFIG_FILE="$ROOT_DIR/config.txt"
LOCK_FILE="$ROOT_DIR/git-auto-sync.lock"
TMP_LOG="$ROOT_DIR/git-auto-sync.tmp"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$TMP_LOG"
}

# Prevent duplicate instances
if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$OLD_PID" 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# Auto-create repos.txt if missing
if [ ! -f "$REPO_LIST" ]; then
    cat > "$REPO_LIST" << 'EOF'
# 每行填写一个git仓库的绝对路径 / Put one git repo absolute path per line
# 以 # 开头的行为注释，该仓库将暂停同步 / Lines starting with # are paused
# 示例 / Example:
# /Users/username/my-project
# ===========================================================================================================

EOF
    open -t "$REPO_LIST"
    osascript -e 'display notification "Please fill in repo paths in repos.txt" with title "Git Auto Sync"'
    exit 0
fi

# Main loop
while true; do
    INTERVAL=$(grep "^INTERVAL=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    INTERVAL=${INTERVAL:-10}
    KEEP_RECENT=$(grep "^KEEP_RECENT=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    KEEP_RECENT=${KEEP_RECENT:-5}

    > "$TMP_LOG"

    log "=== Sync started ==="

    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$line" ] && continue
        [[ "$line" == \#* ]] && continue

        if [ ! -d "$line/.git" ]; then
            log "SKIP: $line is not a git repo"
            continue
        fi

        log "Syncing: $line"
        cd "$line" || continue

        git add -A 2>> "$TMP_LOG"

        if ! git diff --cached --quiet 2>/dev/null; then
            git commit -m "auto sync $(date '+%Y-%m-%d %H:%M')" >> "$TMP_LOG" 2>&1
            log "  Committed"
        else
            log "  Nothing to commit"
        fi

        git pull --rebase --autostash >> "$TMP_LOG" 2>&1

        if git push >> "$TMP_LOG" 2>&1; then
            log "  Pushed"
        else
            log "  ERROR: Push failed"
        fi

    done < "$REPO_LIST"

    log "=== Sync finished ==="
    log "Next sync in $INTERVAL minutes"

    # Prepend to main log (full history)
    if [ -f "$LOG_FILE" ]; then
        cat "$LOG_FILE" >> "$TMP_LOG"
    fi
    mv "$TMP_LOG" "$LOG_FILE"

    # Prepend to recent log, then truncate
    if [ -f "$RECENT_LOG" ]; then
        cat "$RECENT_LOG" >> "$TMP_LOG"
    fi
    mv "$TMP_LOG" "$RECENT_LOG" 2>/dev/null
    # Truncate recent log to KEEP_RECENT cycles
    SYNC_COUNT=$(grep -c "=== Sync started ===" "$RECENT_LOG" 2>/dev/null)
    if [ "$SYNC_COUNT" -gt "$KEEP_RECENT" ]; then
        CUT_LINE=$(grep -n "=== Sync started ===" "$RECENT_LOG" | sed -n "$((KEEP_RECENT+1))p" | cut -d: -f1)
        if [ -n "$CUT_LINE" ]; then
            head -n $((CUT_LINE-1)) "$RECENT_LOG" > "$RECENT_LOG.tmp" && mv "$RECENT_LOG.tmp" "$RECENT_LOG"
        fi
    fi

    sleep $((INTERVAL * 60))
done
