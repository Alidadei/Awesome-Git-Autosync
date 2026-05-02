#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"
nohup "$DIR/git-auto-sync.sh" > /dev/null 2>&1 &
disown
