#!/bin/bash
# Godot実行時エラーチェック

GODOT_PATH="/c/Users/kazum/OneDrive/デスクトップ/プライベート/Godot/Godot_v4.6.2-stable_win64.exe"
PROJECT_PATH="C:/Users/kazum/dungeon-board-game"
LOG_FILE="/tmp/godot_error.log"

echo "=== Godot実行時エラーチェック ==="

# Godotをヘッドレスモードで起動してエラーをキャプチャ（stdout/stderrを両方取得）
"$GODOT_PATH" --headless --path "$PROJECT_PATH" --quit > "$LOG_FILE" 2>&1

# エラーログを表示
echo "--- 全ログ ---"
cat "$LOG_FILE"

echo ""
echo "--- エラー抽出 ---"
if grep -qE "ERROR|SCRIPT ERROR|Parser Error|Cannot cast" "$LOG_FILE"; then
    echo "❌ エラー検出:"
    grep -E "ERROR|SCRIPT ERROR|Parser Error|Cannot cast" "$LOG_FILE"
else
    echo "✅ パースエラーなし"
fi

rm -f "$LOG_FILE"
