#!/bin/bash
# 実際にGodotでゲームを起動してエラー検知

GODOT="/c/Users/kazum/OneDrive/デスクトップ/プライベート/Godot/Godot_v4.6.2-stable_win64.exe"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/tmp/godot_gameplay.log"

echo "=== Godotゲームプレイエラーチェック ==="

# Godotを起動してエラーログをキャプチャ（10秒間実行）
timeout 10 "$GODOT" --path "$PROJECT_DIR" > "$LOG_FILE" 2>&1 &
GODOT_PID=$!

# 少し待機してからログを確認
sleep 8

# プロセスを終了
kill $GODOT_PID 2>/dev/null

# エラーログを確認
echo "--- エラー検出 ---"
if grep -qE "Parser Error|Cannot cast|Trying to assign|Type mismatch|SCRIPT ERROR" "$LOG_FILE"; then
    echo "❌ エラー検出:"
    grep -E "Parser Error|Cannot cast|Trying to assign|Type mismatch|SCRIPT ERROR" "$LOG_FILE" | head -20
    rm -f "$LOG_FILE"
    exit 1
else
    echo "✅ エラーなし"
    rm -f "$LOG_FILE"
    exit 0
fi
