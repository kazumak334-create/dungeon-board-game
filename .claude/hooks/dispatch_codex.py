#!/usr/bin/env python3
"""
ClaudeCode <-> Codex 自動連携スクリプト

PostToolUse Hook として動作。stdin から JSON を受け取り、
codex_request_*.md の作成を検知したら Codex を自動起動する。
codex_result_*.md の作成を検知したら ClaudeCode に通知する。
"""

import json
import sys
import os
import subprocess
import re
from pathlib import Path
from datetime import datetime

PROJECT_ROOT = Path("C:/Users/kazum/dungeon-board-game")
CONFIG_PATH = PROJECT_ROOT / ".claude/hooks/codex_config.json"
LOG_PATH = PROJECT_ROOT / ".claude/hooks/dispatch_log.txt"


def load_config():
    with open(CONFIG_PATH, encoding="utf-8") as f:
        return json.load(f)


def log(msg: str):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(f"[{timestamp}] {msg}\n")
    print(msg, file=sys.stderr)


def read_file_safe(path: str) -> str:
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except Exception as e:
        log(f"ERROR: ファイル読み込み失敗 {path}: {e}")
        return ""


def dispatch_to_codex(request_path: str, config: dict):
    """codex_request_*.md を Codex CLI に渡して実行する"""
    if not config.get("auto_dispatch", True):
        log(f"SKIP: auto_dispatch=false のためスキップ: {request_path}")
        return

    system_prompt_path = PROJECT_ROOT / config.get("system_prompt_path", "")
    system_prompt = read_file_safe(str(system_prompt_path))
    request_content = read_file_safe(request_path)

    if not request_content:
        log(f"ERROR: request ファイルが空: {request_path}")
        return

    prompt = f"{system_prompt}\n\n---\n\n以下の実装依頼を処理してください:\n\n{request_content}"

    # codex exec コマンドを構築
    codex_bin = config["codex_command"]
    model = config.get("codex_model", "o4-mini")

    # プロンプトを一時ファイルに書く
    prompt_file = PROJECT_ROOT / ".claude/hooks/_tmp_prompt.md"
    with open(prompt_file, "w", encoding="utf-8") as f:
        f.write(prompt)

    # codex exec < prompt_file でバックグラウンド実行（出力をログに保存）
    codex_out = PROJECT_ROOT / ".claude/hooks/codex_output.log"
    log(f"DISPATCH: Codex 起動 → {request_path}")
    try:
        with open(prompt_file, "r", encoding="utf-8") as stdin_f, \
             open(codex_out, "w", encoding="utf-8") as out_f:
            proc = subprocess.Popen(
                [codex_bin, "exec", "--model", model, "--dangerously-bypass-approvals-and-sandbox"],
                stdin=stdin_f,
                stdout=out_f,
                stderr=out_f,
                cwd=str(PROJECT_ROOT)
            )
        log(f"OK: Codex exec 起動完了 (model={model}, pid={proc.pid})")
        log(f"    出力ログ: .claude/hooks/codex_output.log")
    except FileNotFoundError:
        log(f"WARN: '{config['codex_command']}' コマンドが見つかりません。")
        log(f"      codex_config.json の codex_command を確認してください。")
        log(f"      Request ファイルは作成済み: {request_path}")
    except Exception as e:
        log(f"ERROR: Codex 起動失敗: {e}")


def notify_result_ready(result_path: str, config: dict):
    """codex_result_*.md が作成されたら ClaudeCode に通知する"""
    if not config.get("notify_on_result", True):
        return

    result_content = read_file_safe(result_path)

    # 対応する request ファイルを特定
    result_name = Path(result_path).name
    # codex_result_20260502_001.md → codex_request_20260502_001.md
    request_name = result_name.replace("codex_result_", "codex_request_")
    request_path = PROJECT_ROOT / config.get("request_dir", "docs/tasks") / request_name

    log(f"RESULT: Codex 結果ファイル検出: {result_path}")

    # stdout に通知（Claude Code がキャプチャして表示）
    print(f"\n[Codex Hook] 結果ファイルが作成されました: {result_path}")
    if request_path.exists():
        print(f"[Codex Hook] 対応依頼: {request_path}")
    print(f"[Codex Hook] ClaudeCode はこのファイルをレビューしてください。")


def main():
    if len(sys.argv) > 1:
        config = load_config()
        request_path = str((PROJECT_ROOT / sys.argv[1]).resolve()) if not Path(sys.argv[1]).is_absolute() else sys.argv[1]
        file_name = Path(request_path).name
        request_prefix = config.get("request_prefix", "codex_request_")
        if not file_name.startswith(request_prefix):
            log(f"ERROR: request ファイル名ではありません: {request_path}")
            return
        dispatch_to_codex(request_path, config)
        return

    # stdin から Hook イベントの JSON を読む
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return
        event = json.loads(raw)
    except json.JSONDecodeError:
        log("ERROR: stdin の JSON パース失敗")
        return

    tool_name = event.get("tool_name", "")
    tool_input = event.get("tool_input", {})
    file_path = tool_input.get("file_path", "")

    if not file_path:
        return

    # docs/tasks/ 配下のファイルのみ対象
    if "docs/tasks" not in file_path.replace("\\", "/"):
        return

    config = load_config()
    file_name = Path(file_path).name
    request_prefix = config.get("request_prefix", "codex_request_")
    result_prefix = config.get("result_prefix", "codex_result_")

    if file_name.startswith(request_prefix):
        dispatch_to_codex(file_path, config)

    elif file_name.startswith(result_prefix):
        notify_result_ready(file_path, config)


if __name__ == "__main__":
    main()
