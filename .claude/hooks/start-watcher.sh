#!/bin/bash
# Claude Code Stop hook: Godotウォッチャーをバックグラウンドで自動起動
# 既に起動中なら何もしない（PIDファイルで管理）

PID_FILE="$(python3 -c 'import tempfile; print(tempfile.gettempdir())')/dungeon_watcher.pid"
WATCHER_DIR="$(cd "$(dirname "$0")/../.." && pwd)/debug/watcher"

is_running() {
    if [ ! -f "$PID_FILE" ]; then
        return 1
    fi
    local pid
    pid=$(cat "$PID_FILE")
    # WindowsのPID確認
    if tasklist.exe /FI "PID eq $pid" 2>/dev/null | grep -q "python"; then
        return 0
    fi
    return 1
}

if is_running; then
    exit 0
fi

# 新しいcmdウィンドウでwatcherを起動
WATCHER_WIN_PATH=$(cygpath -w "$WATCHER_DIR" 2>/dev/null || echo "$WATCHER_DIR")
cmd.exe /c start "Dungeon Watcher" cmd /k "cd /d \"$WATCHER_WIN_PATH\" && python watch.py"

exit 0
