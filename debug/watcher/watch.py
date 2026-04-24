#!/usr/bin/env python3
"""Godotログ監視 - Godot起動を検知してから自動でログ監視開始"""

import time
import sys
import os
import tempfile
from pathlib import Path

# Godotのuser://パス (Windows固定)
LOG_PATH = Path.home() / "AppData/Roaming/Godot/app_userdata/DungeonBoardGame/debug/logs/latest.log"
PID_FILE = Path(tempfile.gettempdir()) / "dungeon_watcher.pid"
POLL_INTERVAL = 2.0   # Godot起動待ちポーリング間隔(秒)
TAIL_INTERVAL = 1.0   # ログ監視間隔(秒)
HANG_TIMEOUT = 30.0   # ログ停止でGodot終了とみなす秒数


def write_pid() -> None:
    PID_FILE.write_text(str(os.getpid()))


def wait_for_godot() -> None:
    print(f"Godot起動を待機中... ({LOG_PATH})", flush=True)
    while True:
        if LOG_PATH.exists():
            mtime = LOG_PATH.stat().st_mtime
            if time.time() - mtime < 10:
                print("Godot起動を検知 → ログ監視開始", flush=True)
                return
        time.sleep(POLL_INTERVAL)


def tail_follow(path: Path) -> bool:
    """ログを監視。Godotが終了したらFalseを返す。"""
    buffer = []
    last_update = time.time()

    with open(path, "r", encoding="utf-8") as f:
        f.seek(0, 2)
        while True:
            line = f.readline()
            if line:
                line = line.rstrip()
                buffer.append(line)
                last_update = time.time()
                if len(buffer) > 200:
                    buffer = buffer[-200:]
                _check(buffer)
            else:
                if time.time() - last_update > HANG_TIMEOUT:
                    print("\nGodot終了を検知 → 待機モードに戻ります", flush=True)
                    return False
                time.sleep(TAIL_INTERVAL)


def _check(buffer: list) -> None:
    try:
        import sys
        sys.path.insert(0, str(Path(__file__).parent))
        from rules import detect
        from prompt import build_prompt
    except ImportError:
        return

    anomaly = detect(buffer)
    if anomaly:
        print(f"\n{'='*60}", flush=True)
        print(f"[ANOMALY] {anomaly['rule']}: {anomaly['message']}", flush=True)
        print(f"{'='*60}", flush=True)
        print(build_prompt(anomaly, buffer[-50:]), flush=True)
        print(f"{'='*60}\n", flush=True)
        buffer.clear()


if __name__ == "__main__":
    log_path = Path(sys.argv[1]) if len(sys.argv) > 1 else LOG_PATH
    write_pid()
    print(f"[Dungeon Watcher] 起動 PID={os.getpid()}", flush=True)

    try:
        while True:
            wait_for_godot()
            tail_follow(log_path)
    except KeyboardInterrupt:
        print("\n監視終了", flush=True)
    finally:
        if PID_FILE.exists():
            PID_FILE.unlink()
