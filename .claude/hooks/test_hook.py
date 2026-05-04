#!/usr/bin/env python3
"""
Hook動作テスト。dispatch_codex.py に模擬イベントを渡して動作確認する。
"""
import json
import subprocess
import sys

PROJECT_ROOT = "C:/Users/kazum/dungeon-board-game"

def test_request_detected():
    """codex_request_*.md 作成イベントをシミュレート"""
    event = {
        "hook_event_name": "PostToolUse",
        "tool_name": "Write",
        "tool_input": {
            "file_path": f"{PROJECT_ROOT}/docs/tasks/codex_request_20260502_001.md",
            "content": "# テスト"
        },
        "tool_response": {}
    }
    result = subprocess.run(
        [sys.executable, f"{PROJECT_ROOT}/.claude/hooks/dispatch_codex.py"],
        input=json.dumps(event),
        capture_output=True,
        text=True
    )
    print("=== request検知テスト ===")
    print("stdout:", result.stdout)
    print("stderr:", result.stderr)

def test_result_detected():
    """codex_result_*.md 作成イベントをシミュレート"""
    event = {
        "hook_event_name": "PostToolUse",
        "tool_name": "Write",
        "tool_input": {
            "file_path": f"{PROJECT_ROOT}/docs/tasks/codex_result_20260502_001.md",
            "content": "# テスト結果"
        },
        "tool_response": {}
    }
    result = subprocess.run(
        [sys.executable, f"{PROJECT_ROOT}/.claude/hooks/dispatch_codex.py"],
        input=json.dumps(event),
        capture_output=True,
        text=True
    )
    print("=== result通知テスト ===")
    print("stdout:", result.stdout)
    print("stderr:", result.stderr)

if __name__ == "__main__":
    test_request_detected()
    test_result_detected()
