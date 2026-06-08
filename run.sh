#!/bin/bash
set -e
cd "$(dirname "$0")"

pkill -x icopy 2>/dev/null || true
pkill -x iCopy 2>/dev/null || true
sleep 0.3

swift build
nohup ./.build/debug/icopy >/tmp/icopy-run.log 2>&1 &
echo "Started iCopy, PID=$!"
