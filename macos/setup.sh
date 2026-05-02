#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_LIST="$ROOT_DIR/repos.txt"
SILENT_SCRIPT="$SCRIPT_DIR/git-auto-sync-silent.sh"

echo "============================================"
echo "  Git Auto Sync - Setup"
echo "============================================"
echo ""

# Create repos.txt if missing
if [ ! -f "$REPO_LIST" ]; then
    cat > "$REPO_LIST" << 'EOF'
# Put one git repo absolute path per line
# Lines starting with # are comments
# Example:
# /Users/username/my-project

EOF
    echo "Created repos.txt - please edit it to add your repo paths."
    echo ""
fi

# Register crontab @reboot (script loops internally)
EXISTING=$(crontab -l 2>/dev/null | grep -v "git-auto-sync-silent.sh")
echo "${EXISTING}"$'\n'"@reboot \"$SILENT_SCRIPT\"" | crontab -

echo "[OK] Auto-start on boot registered!"
echo "     The sync script will start automatically on login."
echo ""
echo "     To change interval: just edit config.txt, it takes effect on the next cycle."
