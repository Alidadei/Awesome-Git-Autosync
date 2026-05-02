# Git Auto Sync

**English** | **[中文](README.md)**

Struggling to keep your repos in sync across multiple computers? Give this tool a try!

An ultra-lightweight Git repository auto-sync tool — system script + txt is all you need! No additional installation or dependencies required.

Runs silently, automatically commits, pushes, and pulls on schedule. Once started, zero manual effort required — your repos are always up to date across all your machines!

## Features

- **One-click start, ready to use** — Double-click the setup script and you're done.

- **Ultra-lightweight** — Core scripts are only ~4KB, zero dependencies, pure native system scripts, near-zero CPU/memory usage.

- **Easy to maintain**

  After starting sync the maintenance method is freaking easy:

  — Edit `INTERVAL` in `config.txt` to adjust sync interval (minutes), takes effect on the next cycle.

  — Edit `KEEP_RECENT` in `config.txt` to adjust how many cycles the recent log retains, takes effect on the next cycle.

  — Edit repo paths in `repos.txt` to manage which repos to sync. Add `#` before a path to pause syncing while keeping the address for easy reactivation!

- **Cross-platform** — Provides Windows / macOS / Linux scripts (currently only tested on Windows).

- **Log management** — Provides a lightweight log (keeps the last few cycles, configurable) and a full log (keeps all history, may become large and slow to open over time). The recent log defaults to 5 cycles, adjustable via `config.txt`.

## Directory Structure

```
awesome-git-autosync/
├── windows/
│   ├── git-auto-sync-silent.ps1   # Silent sync launcher
│   ├── git-auto-sync.bat          # Core sync script (no need to click directly)
│   ├── setup.bat                  # Click to register auto-start + begin syncing
│   └── stop.bat                   # Click to stop sync immediately
├── macos/
│   ├── git-auto-sync-silent.sh    # macOS silent launcher
│   ├── git-auto-sync.sh           # macOS core sync script
│   ├── setup.sh                   # Register auto-start + begin syncing
│   └── stop.sh                    # Stop sync process
├── linux/
│   ├── git-auto-sync-silent.sh    # Linux silent launcher
│   ├── git-auto-sync.sh           # Linux core sync script
│   ├── setup.sh                   # Register auto-start + begin syncing
│   └── stop.sh                    # Stop sync process
|
├── config.txt                     # Sync interval configuration
├── repos.txt                      # Repo path list (auto-generated on first run)
├── git-auto-sync.log              # Full log (all history)
└── git-auto-sync-recent.log       # Recent log (last few cycles, for quick debugging)
```

## Quick Start

### GUI

**1. Clone the repo**

```bash
git clone https://github.com/Alidadei/awesome-git-autosync.git
```

**2. One-click start**

Double-click `windows/setup.bat`. It will automatically register auto-start on login and begin syncing in the background.

**3. Configure repos**

On first sync, `repos.txt` will be auto-created and opened in your editor. Add one repo absolute path per line:

```
C:\Users\username\my-project
C:\Users\username\another-repo
```

**4. Change sync interval**

Edit `config.txt` in the root directory. Changes take effect on the next cycle:

```
INTERVAL=10
```

### Command Line

**Windows:**

```
git clone https://github.com/Alidadei/awesome-git-autosync.git && cd git-sync-script && windows\setup.bat
```

**macOS / Linux:**

```
git clone https://github.com/Alidadei/awesome-git-autosync.git && cd git-sync-script && chmod +x macos/*.sh && macos/setup.sh
```

**View logs:**

```
cat git-auto-sync-recent.log
```

> Two-level log management for easy debugging:
> - `git-auto-sync-recent.log` — Lightweight log, keeps only the last 5 sync cycles. Recommended for daily use.
> - `git-auto-sync.log` — Full log, keeps all history. For deep troubleshooting.
>
> Adjust the retained cycles via `KEEP_RECENT=5` in `config.txt`.

**Pause a repo:** Edit `repos.txt`, add `#` at the start of a line to pause, remove `#` to resume.

**Stop sync:** Double-click `windows\stop.bat` to immediately stop the sync process. Run `setup.bat` again to resume.

## Sync Logic

For each repo in `repos.txt`, the script executes in order:

1. `git add -A`
2. `git commit` (when there are changes)
3. `git pull --rebase --autostash`
4. `git push`

## Use Cases

- Auto-backup for personal notes and document repos
- Multi-device sync for single-branch repos
- Periodic auto-save of work progress

## Not Suitable For

- Multi-branch collaborative repos (may cause conflicts)
- Projects requiring fine-grained commit message control
- Multi-user simultaneous editing workflows

## Status

> **Currently only tested on Windows.** macOS / Linux scripts are written but not yet tested.

## Roadmap

- Multi-branch support: auto-detect branch info and let users choose which branch to sync

- Error handling: file too large, upload timeout, failure alerts with max retry time and error notifications
